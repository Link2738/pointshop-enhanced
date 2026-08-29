--[[
	pointshop/sv_appearance.lua

	What a player looks like, decided in one place.

	THE PROBLEM THIS REPLACES

	Nothing used to answer "what should this player look like right now?". Eight places each
	changed the character a bit, in their own way, in whatever order they happened to run:

	    PS_EquipItem        OnEquip  -- apply AND persist AND broadcast
	    PS_HolsterItem      OnHolster -- reset skin, bodygroups and colour to hardcoded defaults
	    PS_PlayerSpawn      OnEquip again, per item
	    PS_PlayerDeath      OnHolster, per item
	    PS_SellItem         OnHolster
	    sv_init take-item   OnHolster on someone else
	    loadout Show        Wear -- a second copy of the apply half
	    loadout Unshow      Wear again, plus a colour snapshot to undo the first copy

	Every one of them mutated. None of them derived. So two of them running in sequence gave
	whatever the order produced, and the bugs were all the same bug wearing different hats:
	equipping an item while a loadout was on half-replaced the loadout; taking a loadout off
	left the character with no colour and skin 0; the customization panel then read that
	wrongly-reset character and saved skin 0 over the real one.

	THE SHAPE

	One function says what should be visible. One function makes the character match it.
	Everything else just says "something changed" and calls the second one.

	    PS:AppearanceSet(ply)     -> the accessories and the playermodel that SHOULD be on
	    PS:ApplyAppearance(ply)   -> make it so, and tell everyone once

	ApplyAppearance is idempotent and safe to call as often as you like: it takes off what is
	no longer wanted and re-applies what is, and PS_AddClientsideModel already replaces rather
	than duplicates. So a caller never has to reason about what state the character was in --
	which is the entire point, because that reasoning is what nobody was doing correctly.

	WHERE THE MODIFIERS COME FROM

	The customization store, always -- the same source an equip reads. There are two places a
	modifier can live, the store and PS_Items[id].Modifiers, and the item row goes stale: for a
	playermodel it is written only by the modify path. Reading the row is what made taking a
	loadout off restore a character with no colour and skin 0.

	THE OVERLAY

	A loadout is a borrowed look. It is one INPUT to the set rather than a second system that
	applies things: while an overlay is set, the set is the overlay, and when it is cleared the
	set goes back to what the player owns. Nothing is snapshotted and nothing is undone --
	clearing re-derives, which is why the old priorPlayerColor / priorRenderColor pair is gone.
	It existed to undo a mutation that no longer happens.
]]--

-- The borrowed look currently shown on a player, or nil. Memory only, for the session only --
-- an overlay is never written to the item store or the customization store.
local overlay = {}

-- One message carrying the visible accessory modifiers for one player.
--
-- Was PS_Loadout_Overlay, and the name had stopped being true: it is sent whenever anybody's
-- appearance changes, not only when a loadout is involved.
util.AddNetworkString("PS_Appearance_Sync")

-- Reused rather than rebuilt. ClearModel can run on every player in a round change.
local NEUTRAL = Color(255, 255, 255, 255)

-- ============================================================================
-- SOURCES
-- ============================================================================

-- The modifiers to show one item with.
--
-- The store first, because that is what OnEquip reads through applyAndPersist -- if this
-- disagreed with it, then re-equipping an item would change how it looks, which is exactly
-- the bug that led here. The item row is the fallback for an item whose modifiers were only
-- ever written there.
function PS:GetItemModifiers(ply, item_id)
	local stored = PS_GetCustomization and PS_GetCustomization(ply, item_id)
	if istable(stored) and next(stored) ~= nil then return stored end

	local row = ply.PS_Items and ply.PS_Items[item_id]
	return row and row.Modifiers or nil
end

-- ============================================================================
-- THE SET
-- ============================================================================

-- What should be visible on this player right now.
--
-- Returns the accessories as a list, and the one playermodel separately -- they are different
-- kinds of thing and the caller does different work with them. A player can have several
-- playermodels equipped at once, so exactly one has to be chosen; accessories all show.
--
-- Sorted by id, so a player with two equally valid models gets the same one every time. Raw
-- pairs() order is stable within a session and not across them, which is how the same player
-- used to spawn as a different model after a map change.
function PS:AppearanceSet(ply)
	local accessories, model = {}, nil

	local current = overlay[ply]

	if current then
		-- An overlay has already been filtered and ordered by whoever set it.
		for _, entry in ipairs(current) do
			local ITEM = PS.Items[entry.id]
			if ITEM then
				if PS.IsPlayermodelItem(ITEM) then
					if not model then model = entry end
				else
					accessories[#accessories + 1] = entry
				end
			end
		end

		return accessories, model
	end

	local ids = {}
	for id, data in pairs(ply.PS_Items or {}) do
		local ITEM = PS.Items[id]

		-- Appearance items only. A weapon, powerup or trail is equipped through its own
		-- OnEquip and has no business in a set that is applied and re-applied.
		if data.Equipped and ITEM and PS.IsLoadoutItem(ITEM) then
			ids[#ids + 1] = id
		end
	end

	table.sort(ids)

	for _, id in ipairs(ids) do
		local ITEM = PS.Items[id]
		local entry = { id = id, mods = PS:GetItemModifiers(ply, id) }

		if PS.IsPlayermodelItem(ITEM) then
			-- Team gating decides which model, not whether the player owns it. A model
			-- equipped for the other side stays equipped and simply is not the one worn.
			if not model and PS:CanEquipForTeam(ply, ITEM) then model = entry end
		else
			accessories[#accessories + 1] = entry
		end
	end

	return accessories, model
end

-- ============================================================================
-- APPLYING
-- ============================================================================

-- Hands the model decision back to the gamemode and returns the character to a clean state.
--
-- This is the destructive half of the old BASE:OnHolster, which ran on every holster of every
-- playermodel whether or not another one was about to replace it. It runs here only when the
-- player genuinely ends up wearing no shop model at all.
local function ClearModel(ply)
	ply._PS_ActivePlayerModel = nil

	local before = ply:GetModel()
	hook.Run("PlayerSetModel", ply)

	-- Only if nothing answered the hook. A gamemode that does not implement it is no worse
	-- off than it was before the resolver existed.
	if ply:GetModel() == before and ply._OldModel then
		ply:SetModel(ply._OldModel)
	end
	ply._OldModel = nil

	-- Neutral through the modulation path clears BOTH colour channels: modulation goes white
	-- and the $color2 proxy is reset. See PS:ApplyColorToPlayer.
	PS:ApplyColorToPlayer(ply, NEUTRAL, false)

	for i = 0, ply:GetNumBodyGroups() - 1 do
		ply:SetBodygroup(i, 0)
	end
	ply:SetSkin(0)
end

-- Tells every client which modifiers to draw this player's accessories with.
--
-- One message for the whole set, bit-packed by PS_WriteModifiers -- the same encoder the item
-- sync uses. The accessory base used to send a PS_AccessoryCustomization_Update per item on
-- every equip, each carrying an untyped net.WriteTable.
-- The count is 8 bits, and the loop is bounded by the number actually written.
--
-- It was 5, carried over from the loadout message where MAX_ITEMS caps a set at 24. This one
-- also carries the OWNED set, which nothing caps at 24 -- a player with 32 equipped accessories
-- would have written a count that wrapped, and because the entries are positional, every entry
-- after the miscount decodes from the wrong offset. Silent, and it would look like a
-- customization bug on somebody else's hat.
local MAX_SYNC = 255

local function Sync(ply, accessories)
	local n = math.min(#accessories, MAX_SYNC)

	net.Start("PS_Appearance_Sync")
		net.WriteEntity(ply)
		net.WriteUInt(n, 8)

		for i = 1, n do
			local entry = accessories[i]
			net.WriteString(entry.id)
			PS_WriteModifiers(entry.mods)
		end
	net.Broadcast()
end

-- Makes the character match the set.
--
-- Safe to call at any time and as often as you like. The only state it reads back is what it
-- last put on, and that is used solely to decide what to take OFF -- everything wanted is
-- applied every time, because applying is idempotent and a respawn or a gamemode can have
-- reset the character underneath us without telling anybody.
function PS:ApplyAppearance(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local accessories, model = PS:AppearanceSet(ply)

	local want = {}
	for _, entry in ipairs(accessories) do want[entry.id] = true end

	-- Off first, so an item moving out of the set cannot be removed after its replacement
	-- has been put on.
	for id in pairs(ply._PS_Shown or {}) do
		if not want[id] then ply:PS_RemoveClientsideModel(id) end
	end

	local ITEM = model and PS.Items[model.id]

	-- Guarded rather than assumed. An item can answer yes to IsPlayermodelItem on the TYPE
	-- alone while carrying the accessory base, and this function is now the single point every
	-- player's appearance goes through -- an error here takes out everybody's, not one hat's.
	if ITEM and ITEM.ApplyModelSettings then
		ply._PS_ActivePlayerModel = ITEM.Model
		ply._PS_ShownModel = model.id

		-- The visual half only. Persisting is the equip path's job, and a loadout must not
		-- persist at all.
		ITEM:ApplyModelSettings(ply, model.mods)

	elseif ply._PS_ShownModel then
		ClearModel(ply)
		ply._PS_ShownModel = nil
	end

	for _, entry in ipairs(accessories) do
		ply:PS_AddClientsideModel(entry.id)
	end

	ply._PS_Shown = want

	Sync(ply, accessories)
end

-- ============================================================================
-- THE OVERLAY
-- ============================================================================

-- These two SET STATE. They do not apply.
--
-- Every caller finishes with PS:ApplyAppearance, which is the same thing every other caller in
-- the addon does after changing anything -- an equip, a holster, a sale, a spawn. Making these
-- apply as well would mean equipping an item while a loadout is on applied twice, and sending
-- two PS_Appearance_Sync broadcasts to everybody for one change.

-- Shows a borrowed look. `items` is a list of { id = ..., mods = ... }, already validated.
function PS:SetAppearanceOverlay(ply, items)
	overlay[ply] = items
end

-- Back to what the player owns. Nothing is restored from a snapshot -- the set is re-derived.
function PS:ClearAppearanceOverlay(ply)
	overlay[ply] = nil
end

-- The borrowed look on this player, or nil. Read by anything that needs to know an appearance
-- is borrowed rather than owned.
function PS:GetAppearanceOverlay(ply)
	return overlay[ply]
end

-- ============================================================================
-- LIFETIME
-- ============================================================================

hook.Add("PlayerDisconnected", "PS_AppearanceForget", function(ply)
	overlay[ply] = nil
end)

-- ============================================================================
-- DIAGNOSTICS
-- ============================================================================

-- What the SERVER believes about a player's appearance, next to what it has put on them.
--
-- The question this exists to answer is "was that their end or ours", which came up the first
-- time somebody else joined and could not customize a playermodel. That one turned out to be
-- gated on having the item EQUIPPED -- the Modify option only appears on an equipped item --
-- and there was no way to check what the server thought without reading their screen.
--
-- Ownership and Equipped come from the server's own records, so a disagreement between this
-- and what the player sees IS the answer: their client is out of sync, not the shop.
--
--   ps_appearance_dump          every player
--   ps_appearance_dump <name>   one player
concommand.Add("ps_appearance_dump", function(caller, cmd, args)
	if IsValid(caller) and not caller:IsSuperAdmin() then return end

	local function Dump(ply)
		MsgN(string.format("[PS appearance] %s  (team %d, %s)",
			ply:Nick(), ply:Team(), ply:Alive() and "alive" or "dead"))

		if not ply.PS_DataLoaded then
			MsgN("    inventory has NOT finished loading -- nothing below is meaningful yet")
		end

		local current = overlay[ply]
		MsgN(string.format("    overlay: %s",
			current and (#current .. " item(s) borrowed") or "none -- wearing their own"))

		-- Everything the shop would consider, and why each one is or is not in the set.
		MsgN("    owned appearance items:")
		local any = false
		for id, data in pairs(ply.PS_Items or {}) do
			local ITEM = PS.Items[id]
			if ITEM and PS.IsLoadoutItem(ITEM) then
				any = true
				MsgN(string.format("        %-28s %-11s equipped=%-5s team=%s",
					id,
					PS.IsPlayermodelItem(ITEM) and "[model]" or "[accessory]",
					tostring(data.Equipped and true or false),
					tostring(PS:CanEquipForTeam(ply, ITEM))))
			end
		end
		if not any then MsgN("        (none)") end

		local accessories, model = PS:AppearanceSet(ply)
		MsgN(string.format("    resolved set: model=%s, %d accessory(ies)",
			model and model.id or "none", #accessories))

		MsgN(string.format("    actually shown: model=%s, %d accessory(ies)",
			ply._PS_ShownModel or "none",
			table.Count(ply._PS_Shown or {})))
	end

	if args and args[1] then
		local found = string.lower(args[1])
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Nick()), found, 1, true) then Dump(p) end
		end
		return
	end

	for _, p in ipairs(player.GetAll()) do Dump(p) end
end)
