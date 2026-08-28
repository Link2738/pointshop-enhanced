--[[
	pointshop/sv_loadout.lua

	Loadouts, server side: validate, show, relay. Never store.

	A loadout is a look a player saved on their own machine. Applying one puts it on their
	character so everyone can see it, and that is all it does -- nothing here writes to the
	item store or to the customization store, so a loadout cannot overwrite the appearance the
	player actually owns. Taking it off puts that appearance back.

	That claim used to be false. Show called ITEM:OnEquip, and both item bases persist: the
	playermodel base through applyAndPersist, the accessory base directly. So applying a
	loadout wrote its modifiers over the player's saved ones for every item in it. Worse,
	applyAndPersist reads the STORED modifiers in preference to the ones passed in, so the
	loadout's own skin, bodygroups and colour were dropped and the player's saved ones applied
	instead -- the loadout was overwriting your data and not even showing you its own.

	Wear() below is the visual half of an equip with the storing half left out.

	WHY NOT JUST EQUIP THE ITEMS

	Two reasons, both hard.

	PS_EquipItem persists. It ends in PS:SavePlayerItem, which is exactly the write a loadout
	must not do -- otherwise trying on an outfit silently replaces what you had.

	And the client cannot drive it. PS_COOLDOWNS puts equip at 0.3s and holster at 0.3s, and
	PS_RateLimit drops rather than queues, so a six-item outfit sent as six messages would take
	two seconds and lose most of itself. One message carries the set and is limited once.

	TRUST

	The message says what the player WANTS to wear. Every item is checked against this server's
	own records before it is shown to anybody -- ownership, the item's own rule, the gamemode's
	team gating, and the category limits counted over the loadout itself. A loadout is not a
	way to wear something you do not own.
]]--

-- The overlay currently showing on each player, or nil. Memory only, for the session only.
--
-- Declared first because the console commands below read it, and a Lua local is not in scope
-- above its own declaration -- it was further down, so ps_loadout_dump resolved `worn` to a
-- nil global and errored on its first use rather than at load.
local worn = {}

util.AddNetworkString("PS_Loadout_Apply")
util.AddNetworkString("PS_Loadout_Clear")
util.AddNetworkString("PS_Loadout_Result")

-- Server asking the client to send its active loadout, if it has one.
--
-- The loadout lives on the client and the readiness lives here: whether the player has spawned,
-- what team they are on, whether their inventory has loaded. The client used to guess at all
-- three with a three-second timer on join, which is why the console filled with refusals --
-- it was applying against an empty inventory from an unassigned team while dead.
--
-- So the client stops guessing and waits to be asked. There are exactly two moments worth
-- asking at, and this file already hooks both.
util.AddNetworkString("PS_Loadout_Prompt")

-- One player's accessory modifiers, for everybody, in one message.
--
-- Wear used to send a PS_AccessoryCustomization_Update broadcast PER ACCESSORY, so a six-piece
-- loadout was six broadcasts to every player and clearing it was six more. Each carried a
-- net.WriteTable, which is the untyped self-describing shape sh_item_delta exists to avoid.
--
-- This is one broadcast for the whole set, with the modifiers bit-packed by PS_WriteModifiers
-- -- the same encoder the item sync uses. It also arrives atomically, so a client applies an
-- outfit rather than watching it assemble.
--
-- Accessories only. A playermodel's model, skin and bodygroups are entity state and replicate
-- on their own; nothing has to be told about them.
util.AddNetworkString("PS_Loadout_Overlay")

util.AddNetworkString("PS_LoadoutSelfTest")

-- Overlay framing self-test, in the same shape as ps_delta_selftest.
--
-- That test covers PS_WriteModifiers and PS_ReadModifiers, which is the encoder this message
-- carries. It does not cover the framing wrapped around it: the 5-bit count, the string id
-- before each entry, and the fact that entries are positional -- read one field wrong and
-- every entry after it decodes from the wrong offset, which is silent and looks like a
-- customization bug three items later rather than a protocol bug here.
--
-- Uses PS_DeltaTestVectors as the entries so the modifier payloads are already known-good and
-- anything that fails is the framing.
--
--   ps_loadout_selftest          run against every player
--   ps_loadout_selftest <name>   run against one player
--
-- Results print in the client console of whoever is tested.
concommand.Add("ps_loadout_selftest", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end

	local targets = {}
	if args and args[1] then
		local found = string.lower(args[1])
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Nick()), found, 1, true) then table.insert(targets, p) end
		end
	else
		targets = player.GetAll()
	end

	if #targets == 0 then
		MsgN("[PS loadout] No matching players.")
		return
	end

	for _, p in ipairs(targets) do
		net.Start("PS_LoadoutSelfTest")
			net.WriteUInt(#PS_DeltaTestVectors, 5)

			for i, vec in ipairs(PS_DeltaTestVectors) do
				net.WriteString("selftest_" .. i)
				PS_WriteModifiers(vec.mods)
			end
		net.Send(p)

		MsgN(string.format("[PS loadout] Sent a %d-entry overlay to %s -- results are in their client console.",
			#PS_DeltaTestVectors, p:Nick()))
	end
end)

-- Prints what the server believes is overlaid on a player.
--
-- This is the half that needed a second player to check. It does not any more: the overlay
-- reaches other clients as broadcast -> StoreMods -> ModifyClientsideModel, the first hop is
-- proven byte for byte by ps_loadout_selftest, and the last is the same code that draws your
-- own accessories. So if this says the right set, what everyone else sees follows -- and if it
-- says the wrong set, no amount of looking at another player would have told you why.
--
--   ps_loadout_dump          every player wearing one
--   ps_loadout_dump <name>   one player
concommand.Add("ps_loadout_dump", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end

	local function Dump(p)
		local current = worn[p]

		if not current then
			MsgN(string.format("[PS loadout] %s: nothing overlaid", p:Nick()))
			return
		end

		MsgN(string.format("[PS loadout] %s: %d item(s) overlaid", p:Nick(), #current.items))

		for _, entry in ipairs(current.items) do
			local ITEM = PS.Items[entry.id]
			MsgN(string.format("    %-24s %s%s",
				entry.id,
				ITEM and (PS.IsPlayermodelItem(ITEM) and "[model] " or "[worn]  ") or "[GONE]  ",
				entry.mods and util.TableToJSON(entry.mods) or "no modifiers"))
		end

		-- What it will go back to. The overlay is only half the state: a restore that returns
		-- the wrong colour is a bug in here, not in the loadout.
		MsgN(string.format("    restores to playercolor=%s rendercolor=%s",
			tostring(current.priorPlayerColor), tostring(current.priorRenderColor)))
	end

	if args and args[1] then
		local found = string.lower(args[1])
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Nick()), found, 1, true) then Dump(p) end
		end
		return
	end

	for _, p in ipairs(player.GetAll()) do
		if worn[p] then Dump(p) end
	end
end)

-- Sends `set` as this player's accessory overlay. An empty set means "back to your own".
local function BroadcastOverlay(ply, set)
	net.Start("PS_Loadout_Overlay")
		net.WriteEntity(ply)
		net.WriteUInt(#set, 5)   -- MAX_ITEMS is 24, so five bits is the ceiling plus room

		for _, entry in ipairs(set) do
			net.WriteString(entry.id)
			PS_WriteModifiers(entry.mods)
		end
	net.Broadcast()
end

-- Generous for a set of ids and their customization tables, and the same ceiling the modify
-- handler uses for one item's worth of the same data. Checked before any net.Read, because
-- ReadTable walks attacker-controlled data and allocates as it goes.
local MAX_BITS = 32768   -- ~4 KB
local MAX_ITEMS = 24

-- ============================================================================
-- VALIDATION
-- ============================================================================

-- Filters a requested set down to what this player may actually wear.
--
-- Two passes, because the questions are different. Per item: may this player wear this at all
-- (PS_CanEquipItem). Over the set: do the category and slot limits still hold once everything
-- in it is counted -- which is a question about the loadout, not about what the player has on,
-- so it cannot be answered by the per-item check.
local function Filter(ply, requested)
	local accepted, refused = {}, {}

	local perCategory, perSlot = {}, {}

	for _, entry in ipairs(requested) do
		local id = entry.id
		local ITEM = PS.Items[id]

		local ok, reason = ply:PS_CanEquipItem(id)

		if ok and ITEM then
			local CATEGORY = PS:FindCategoryByName(ITEM.Category)

			-- Counted within the loadout. A one-hat category has to refuse the second hat in
			-- the set even though neither is being worn yet.
			if CATEGORY and CATEGORY.AllowedEquipped and CATEGORY.AllowedEquipped > -1 then
				local n = (perCategory[ITEM.Category] or 0) + 1
				if n > CATEGORY.AllowedEquipped then
					ok, reason = false, "Too many from " .. tostring(ITEM.Category) .. "."
				else
					perCategory[ITEM.Category] = n
				end
			end

			-- One item per slot, same reasoning. PS_EquipItem holsters the loser; a loadout
			-- has no loser to holster, so the later entry is simply refused.
			if ok and ITEM.Slot then
				if perSlot[ITEM.Slot] then
					ok, reason = false, "Two items in the same slot."
				else
					perSlot[ITEM.Slot] = true
				end
			end
		end

		if ok then
			-- Modifiers are sanitised, not taken as sent.
			--
			-- The loadout is a file in the player's own data folder, so its modifiers are
			-- theirs to write -- and they were being applied straight to the character. A
			-- hand-edited entry could set a bodygroup the model never offers or a skin outside
			-- the ones it has, which is wearing something the shop does not sell.
			--
			-- Same sanitiser the customization path uses, and it now narrows to the item's own
			-- declaration rather than a generic range.
			local mods = istable(entry.mods) and entry.mods or nil

			if mods and PS_SanitizeCustomizationData then
				mods = PS_SanitizeCustomizationData(mods, ITEM.TYPE or "accessory", ITEM)
				if not next(mods) then mods = nil end
			end

			accepted[#accepted + 1] = { id = id, mods = mods }
		else
			refused[#refused + 1] = { id = id, reason = reason or "Refused." }
		end
	end

	return accepted, refused
end

-- ============================================================================
-- SHOWING AND UNSHOWING
-- ============================================================================

-- Everything the player is genuinely wearing, from the item store.
local function EquippedSet(ply)
	local out = {}
	for id, data in pairs(ply.PS_Items or {}) do
		if data.Equipped and PS.Items[id] then
			out[id] = data.Modifiers
		end
	end
	return out
end

-- Forward declaration. Unshow calls Wear and is defined above it, and a local is not in scope
-- above its own declaration -- the call would resolve to a nil global and take the holster out
-- with it.
local Wear

-- Stops showing whatever the overlay put on, and returns the player to what they own.
--
-- Holsters the overlay's items rather than everything: an item that is in both the overlay and
-- the real inventory should not blink off and on, and OnHolster on something the player is
-- genuinely wearing would undo state the store still believes in.
local function Unshow(ply)
	local current = worn[ply]
	if not current then return end

	local real = EquippedSet(ply)

	for _, entry in ipairs(current.items) do
		local ITEM = PS.Items[entry.id]
		if ITEM and not real[entry.id] then
			ITEM:OnHolster(ply)
			ply:PS_RemoveClientsideModel(entry.id)
		end
	end

	-- The colour the player had before the overlay touched it, captured on the way in.
	--
	-- Read back rather than recomputed: the owned colour is applied from the customization
	-- store by whatever last wrote it, and there is no single field holding it. The
	-- customization panel solves the same problem the same way, with _originalPlayerColor.
	if current.priorPlayerColor then
		ply:SetPlayerColor(current.priorPlayerColor)
	end
	if current.priorRenderColor then
		ply:SetColor(current.priorRenderColor)
	end

	worn[ply] = nil

	-- Put the owned appearance back on, including anything the overlay had holstered.
	--
	-- Through Wear, not OnEquip, for the same reason: OnEquip would write the player's stored
	-- customization back over itself, and taking a loadout OFF is not a moment anything should
	-- be written. It also re-broadcasts the real modifiers, which is what puts other clients
	-- back to the wearer's own offsets and colours after the overlay borrowed them.
	local restored = {}
	for id, mods in pairs(real) do
		Wear(ply, id, mods)
		restored[#restored + 1] = { id = id, mods = mods }
	end

	-- And everyone is told the real set, once, so they stop drawing the overlay's modifiers.
	BroadcastOverlay(ply, restored)
end

-- Puts one item ON somebody without storing anything.
--
-- ITEM:OnEquip was being used for this and it is the wrong function, twice over.
--
-- It PERSISTS. The playermodel base wraps ApplyModelSettings in applyAndPersist, which calls
-- PS_SetCustomization; the accessory base calls it directly. So applying a loadout was
-- overwriting the saved customization of every item in it -- the one thing this file exists
-- to not do, and its header claimed it did not.
--
-- And it IGNORES what it is given. applyAndPersist reads
--
--     local mods = (PS_GetCustomization and PS_GetCustomization(ply, itemID)) or modifications
--
-- stored first, passed second -- so a loadout's own skin, bodygroups and colour were discarded
-- and the player's saved ones applied in their place. The loadout was never being shown.
--
-- So: the visual half only, called directly. ApplyModelSettings is that half for a playermodel;
-- for an accessory it is the clientside model plus telling other clients which modifiers to
-- draw it with, which is what the customization broadcast does -- minus the store write that
-- normally rides along with it.
function Wear(ply, id, mods)
	local ITEM = PS.Items[id]
	if not ITEM then return end

	if PS.IsPlayermodelItem(ITEM) and ITEM.ApplyModelSettings then
		ITEM:ApplyModelSettings(ply, mods)
		return
	end

	-- Telling other clients which modifiers to draw it with is NOT done here, one message per
	-- item. The caller sends the whole set once through BroadcastOverlay.
	ply:PS_AddClientsideModel(id)
end

local function Show(ply, accepted)
	-- Captured BEFORE Unshow, and only when nothing is currently overlaid -- otherwise
	-- applying a second loadout would record the first one's colour as the one to go back to,
	-- and clearing would return to an outfit rather than to what the player owns.
	local priorPlayerColor, priorRenderColor
	if not worn[ply] then
		priorPlayerColor = ply:GetPlayerColor()
		priorRenderColor = ply:GetColor()
	else
		priorPlayerColor = worn[ply].priorPlayerColor
		priorRenderColor = worn[ply].priorRenderColor
	end

	Unshow(ply)

	local real = EquippedSet(ply)

	-- Anything the player owns and is wearing that the loadout does not include has to come
	-- off, or the outfit is theirs plus whatever they already had on.
	local keep = {}
	for _, entry in ipairs(accepted) do keep[entry.id] = true end

	for id in pairs(real) do
		if not keep[id] then
			local ITEM = PS.Items[id]
			if ITEM then
				ITEM:OnHolster(ply)
				ply:PS_RemoveClientsideModel(id)
			end
		end
	end

	for _, entry in ipairs(accepted) do
		Wear(ply, entry.id, entry.mods)
	end

	-- Everyone gets the whole overlay in one message, after the models exist.
	BroadcastOverlay(ply, accepted)

	-- No colour step. There is no such thing as "the loadout's colour": a playermodel carries
	-- its own in mods.playercolor and each accessory carries its own in mods.color, each
	-- through its own item's channel. ApplyModelSettings and the clientside model apply them
	-- item by item, which is the only place that knows which item it is talking about.
	worn[ply] = {
		items = accepted,
		priorPlayerColor = priorPlayerColor,
		priorRenderColor = priorRenderColor,
	}
end

-- ============================================================================
-- NET
-- ============================================================================

net.Receive("PS_Loadout_Apply", function(length, ply)
	if length > MAX_BITS then return end
	if not PS.RateLimit(ply, "loadout") then return end
	if not ply.PS_DataLoaded then return end

	local requested = net.ReadTable()
	if not istable(requested) then return end

	-- Bounded before anything is looked up. A set larger than this is not an outfit.
	if #requested > MAX_ITEMS then return end

	local accepted, refused = Filter(ply, requested)

	-- Nothing survived. That is not "some of your hats were refused", it is the loadout not
	-- being wearable here at all -- wrong team, or nothing in it owned any more -- and putting
	-- an empty outfit on would strip what the player is actually wearing to show them nothing.
	--
	-- So it does not apply, and it says so as one message. A list of six per-item refusals
	-- describes the same fact six times and buries it.
	local blocked = #accepted == 0 and #requested > 0

	if not blocked then
		-- Items and their modifiers, and nothing else. Colour is not sent and not derived
		-- here: it is inside each item's own modifiers, and each item applies its own.
		Show(ply, accepted)
	end

	-- Told what was dropped, so the panel can say which entries this server will not wear
	-- rather than leaving the player to notice a missing hat.
	net.Start("PS_Loadout_Result")
		net.WriteBool(blocked)
		net.WriteTable(refused)
	net.Send(ply)
end)

net.Receive("PS_Loadout_Clear", function(_, ply)
	if not PS.RateLimit(ply, "loadout") then return end
	Unshow(ply)
end)

-- ============================================================================
-- LIFETIME
-- ============================================================================

hook.Add("PlayerDisconnected", "PS_LoadoutForget", function(ply)
	worn[ply] = nil
end)

-- Asks the client for its active loadout, once this player is actually in a state to wear one.
--
-- Waits on PS_DataLoaded rather than assuming it: the inventory load is asynchronous and a
-- spawn can beat it, and an apply that arrives first is refused item by item for items the
-- server has not read yet. Retries a few times and then stops -- a player whose data never
-- loads has a bigger problem than their outfit.
--
-- Nothing to ask about if an overlay is already on: the two hooks below re-show and re-filter
-- what is there rather than starting again.
local function Prompt(ply, tries)
	if not IsValid(ply) or worn[ply] then return end

	if not ply.PS_DataLoaded then
		tries = (tries or 0) + 1
		if tries > 10 then return end

		timer.Simple(1, function() Prompt(ply, tries) end)
		return
	end

	net.Start("PS_Loadout_Prompt")
	net.Send(ply)
end

-- A team change re-validates whatever is being worn.
--
-- On a gamemode that gates by team, the check that refused an item at apply time is a check
-- about the team the player was on THEN. Bear Hunt moves people between teams mid-round --
-- forceswap, and the infection round converting a victim -- so a loadout applied as a victim
-- would go on being worn as a bear, which is the gating being bypassed by outlasting it.
--
-- Re-filtered rather than cleared: most of an outfit is usually still legal, and taking the
-- whole thing off because one playermodel is now wrong is a worse answer than taking off the
-- playermodel.
--
-- Gamemodes with teamGating off never refuse anything here, so this costs them one filter pass
-- on a rare event and changes nothing.
hook.Add("OnPlayerChangedTeam", "PS_LoadoutRevalidate", function(ply, before, after)
	local current = worn[ply]

	-- Nothing on yet. A team the player could not wear their loadout on may have become one
	-- they can -- moving out of spectator is the ordinary case -- so ask.
	if not current then
		timer.Simple(0, function() Prompt(ply) end)
		return
	end

	-- After the gamemode has finished moving them: PS_CanEquipItem asks what team they are on,
	-- and on this tick that is still being decided.
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		if worn[ply] ~= current then return end

		local accepted, refused = Filter(ply, current.items)
		if #refused == 0 then return end

		Show(ply, accepted)

		net.Start("PS_Loadout_Result")
			net.WriteTable(refused)
		net.Send(ply)
	end)
end)

-- A respawn reapplies the owned appearance from the store, which would leave the overlay half
-- on: the loadout's models gone, the loadout's colour still set. Re-showing puts it back
-- whole, and the client re-sends on spawn anyway, so this is the belt to that braces.
hook.Add("PlayerSpawn", "PS_LoadoutReshow", function(ply)
	local current = worn[ply]

	-- No overlay: this is a join, or a respawn after clearing one. Either way it is the moment
	-- to ask, and the only other one is the team change above.
	if not current then
		timer.Simple(1, function() Prompt(ply) end)
		return
	end

	timer.Simple(1, function()
		if IsValid(ply) and worn[ply] == current then
			Show(ply, current.items)
		end
	end)
end)

-- Read by anything that needs to know an appearance is borrowed rather than owned.
function PS:GetWornLoadout(ply)
	return worn[ply]
end
