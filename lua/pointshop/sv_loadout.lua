--[[
	pointshop/sv_loadout.lua

	Loadouts, server side: validate and relay. It does not show anything itself.

	A loadout is a look a player saved on their own machine. Applying one hands a validated set
	to PS:SetAppearanceOverlay and stops; clearing one hands back nothing. What a player looks
	like is sv_appearance.lua's, and only its.

	This file used to apply the outfit as well, through its own Show / Unshow / Wear -- a second
	copy of the apply half, written because ITEM:OnEquip could not be used (it persists, and a
	loadout must not). Two systems mutating the same character, neither aware of the other, is
	what made equipping a hat half-replace a loadout and taking a loadout off leave the player
	with no colour and skin 0.

	The colour snapshot is gone with it. Unshow captured priorPlayerColor and priorRenderColor
	on the way in so it could put them back on the way out; clearing an overlay now re-derives
	the appearance from what the player owns, so there is nothing to undo.

	WHY NOT JUST EQUIP THE ITEMS

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

-- The message that carries a player's visible accessory modifiers is PS_Appearance_Sync, and
-- it is registered and sent by sv_appearance.lua -- it goes out on every appearance change now,
-- not only when a loadout is involved, which is why it stopped being called PS_Loadout_Overlay.

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
		local current = PS:GetAppearanceOverlay(p)

		if not current then
			MsgN(string.format("[PS loadout] %s: nothing overlaid", p:Nick()))
			return
		end

		MsgN(string.format("[PS loadout] %s: %d item(s) overlaid", p:Nick(), #current))

		for _, entry in ipairs(current) do
			local ITEM = PS.Items[entry.id]
			MsgN(string.format("    %-24s %s%s",
				entry.id,
				ITEM and (PS.IsPlayermodelItem(ITEM) and "[model] " or "[worn]  ") or "[GONE]  ",
				entry.mods and util.TableToJSON(entry.mods) or "no modifiers"))
		end

		-- No "restores to" line any more. There is nothing to restore: clearing the overlay
		-- re-derives the appearance from what the player owns rather than replaying a colour
		-- snapshot taken on the way in.
	end

	if args and args[1] then
		local found = string.lower(args[1])
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Nick()), found, 1, true) then Dump(p) end
		end
		return
	end

	for _, p in ipairs(player.GetAll()) do
		if PS:GetAppearanceOverlay(p) then Dump(p) end
	end
end)

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

		-- Refused before anything else is asked. A loadout is an appearance, and a weapon,
		-- powerup or trail in one is not a thing this server declined to give you -- it is a
		-- thing loadouts do not carry.
		if ok and ITEM and not PS.IsLoadoutItem(ITEM) then
			ok, reason = false, "Loadouts only carry models and accessories."
		end

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
-- HANDING IT OVER
-- ============================================================================

-- Everything Show, Unshow, Wear, EquippedSet and BroadcastOverlay used to do lives in
-- sv_appearance.lua now, and is shared with the equip path instead of being a second copy of
-- it. What is left is the handoff.
--
-- Note what is NOT here any more: choosing which of the player's own items to take off to make
-- room, putting them back afterwards, and the colour snapshot taken on the way in so the way
-- out could undo it. None of that is needed once the appearance is derived rather than
-- mutated -- the set is simply the overlay while there is one, and what the player owns when
-- there is not.

-- Re-checks a worn overlay against rules that may have changed under it, and re-applies.
--
-- Called from the one OnPlayerChangedTeam handler in sv_player_extension.lua. It used to be a
-- second handler on that event living here, racing the first on a different timer.
--
-- Re-filtered rather than cleared: most of an outfit is usually still legal, and taking the
-- whole thing off because one playermodel is now wrong is a worse answer than taking off the
-- playermodel.
function PS:RevalidateOverlay(ply)
	local current = PS:GetAppearanceOverlay(ply)
	if not current then return end

	-- Not while they are dead, and not while spectating.
	--
	-- Filter goes through PS_CanEquipItem, which ends in PS_CanPerformAction -- and that
	-- refuses a corpse. So revalidating a dead player refuses every item for a reason that has
	-- nothing to do with the item, and the outfit is thrown away because of when the check ran.
	--
	-- Selling something while dead is the way in: PS_SellItem has no alive gate. Nothing is
	-- lost by waiting -- a dead player draws no accessories, and the respawn re-applies.
	if not ply:Alive() then return end
	if ply.IsSpec and ply:IsSpec() then return end

	local accepted, refused = Filter(ply, current)
	if #refused == 0 then return end

	-- Nothing survived, so there is no outfit left to show.
	--
	-- CLEARED, not set to an empty list. An empty overlay is still an overlay -- `{}` is
	-- truthy, so PS:AppearanceSet would return it and the player would end up wearing nothing
	-- at all rather than falling back to their own gear. Selling the only item in the loadout
	-- you had on would have stripped you bare.
	if #accepted == 0 then
		PS:ClearAppearanceOverlay(ply)
	else
		PS:SetAppearanceOverlay(ply, accepted)
	end

	-- Not applied here. Every caller of this applies afterwards, the same way every caller of
	-- the overlay setters does -- applying here as well meant two applies and two broadcasts
	-- for one change.

	net.Start("PS_Loadout_Result")
		net.WriteBool(#accepted == 0)
		net.WriteTable(refused)
	net.Send(ply)
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
		PS:SetAppearanceOverlay(ply, accepted)
		PS:ApplyAppearance(ply)
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
	PS:ClearAppearanceOverlay(ply)
	PS:ApplyAppearance(ply)
end)

-- ============================================================================
-- LIFETIME
-- ============================================================================

-- The PlayerDisconnected handler that cleared `worn` moved with the table, into
-- sv_appearance.lua's PS_AppearanceForget.

-- Asks the client for its active loadout, once this player is actually in a state to wear one.
--
-- Waits on PS_DataLoaded rather than assuming it: the inventory load is asynchronous and a
-- spawn can beat it, and an apply that arrives first is refused item by item for items the
-- server has not read yet. Retries a few times and then stops -- a player whose data never
-- loads has a bigger problem than their outfit.
--
-- Nothing to ask about if an overlay is already on: the two hooks below re-show and re-filter
-- what is there rather than starting again.
local UNASSIGNED = TEAM_UNASSIGNED or 1001
local SPECTATOR  = TEAM_SPECTATOR  or 1002
local CONNECTING = TEAM_CONNECTING or 1003

local function Prompt(ply, tries)
	if not IsValid(ply) or PS:GetAppearanceOverlay(ply) then return end

	-- Not while they are nobody yet.
	--
	-- PlayerSpawn fires BEFORE the gamemode assigns a team -- the log reads
	--
	--     PlayerSpawn: team=1001 class=Spectator first=true
	--     PlayerJoinTeam: old=1001 new=1
	--
	-- so prompting on spawn asks for a loadout from a spectator, team gating refuses every
	-- item in it, and the player is told they cannot use their loadout on every single join.
	-- The team change a moment later prompts again and works, which makes the first message
	-- pure noise.
	--
	-- Silent rather than deferred: OnPlayerChangedTeam is the other prompt, so getting a team
	-- is exactly the event that asks again.
	local t = ply:Team()
	if t == UNASSIGNED or t == SPECTATOR or t == CONNECTING then return end

	-- And not while they are dead. PS_CanPerformAction refuses a corpse, so a team change
	-- between rounds -- assigned to a side before respawning, which is the normal shape of a
	-- round-based gamemode -- would ask, be refused for everything, and say so. The spawn that
	-- follows is the other prompt, so nothing is lost by staying quiet here.
	if not ply:Alive() then return end

	if not ply.PS_DataLoaded then
		tries = (tries or 0) + 1
		if tries > 10 then return end

		timer.Simple(1, function() Prompt(ply, tries) end)
		return
	end

	net.Start("PS_Loadout_Prompt")
	net.Send(ply)
end

-- A team change asks for a loadout when there is none on.
--
-- The re-validation half used to be here too, as a second OnPlayerChangedTeam handler racing
-- the model resolver's on a different timer. It is now PS:RevalidateOverlay, called from the
-- one handler in sv_player_extension.lua -- same rule, one ordering.
hook.Add("OnPlayerChangedTeam", "PS_LoadoutPromptOnTeam", function(ply)
	if PS:GetAppearanceOverlay(ply) then return end

	-- A team the player could not wear their loadout on may have become one they can --
	-- moving out of spectator is the ordinary case -- so ask.
	timer.Simple(0, function() Prompt(ply) end)
end)

-- A respawn re-applies the appearance from scratch, which for a player wearing an overlay
-- means re-applying the overlay: PS:AppearanceSet returns it while it is set, so PS_PlayerSpawn
-- already puts the whole thing back. Nothing to re-show here.
--
-- What is still needed is the ask, for a player who has no overlay yet.
hook.Add("PlayerSpawn", "PS_LoadoutPromptOnSpawn", function(ply)
	if PS:GetAppearanceOverlay(ply) then return end

	timer.Simple(1, function() Prompt(ply) end)
end)
