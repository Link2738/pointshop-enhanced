--[[
	pointshop/sv_loadout.lua

	Loadouts, server side: validate, show, relay. Never store.

	A loadout is a look a player saved on their own machine. Applying one puts it on their
	character so everyone can see it, and that is all it does -- nothing here writes to the
	item store, so a loadout cannot overwrite the appearance the player actually owns. Taking
	it off puts that appearance back.

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

util.AddNetworkString("PS_Loadout_Apply")
util.AddNetworkString("PS_Loadout_Clear")
util.AddNetworkString("PS_Loadout_Result")

-- Generous for a set of ids and their customization tables, and the same ceiling the modify
-- handler uses for one item's worth of the same data. Checked before any net.Read, because
-- ReadTable walks attacker-controlled data and allocates as it goes.
local MAX_BITS = 32768   -- ~4 KB
local MAX_ITEMS = 24

-- The overlay currently showing on each player, or nil. Memory only, for the session only.
local worn = {}

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
			accepted[#accepted + 1] = { id = id, mods = istable(entry.mods) and entry.mods or nil }
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
	for id, mods in pairs(real) do
		local ITEM = PS.Items[id]
		if ITEM then
			ITEM:OnEquip(ply, mods)
			ply:PS_AddClientsideModel(id)
		end
	end
end

local function Show(ply, accepted, colour, useColor2)
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
		local ITEM = PS.Items[entry.id]
		if ITEM then
			ITEM:OnEquip(ply, entry.mods)
			ply:PS_AddClientsideModel(entry.id)
		end
	end

	if colour then
		PS:ApplyColorToPlayer(ply, colour, useColor2)
	end

	worn[ply] = {
		items = accepted,
		colour = colour,
		useColor2 = useColor2,
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

	local colour, useColor2 = net.ReadColor(), net.ReadBool()

	local accepted, refused = Filter(ply, requested)
	Show(ply, accepted, colour, useColor2)

	-- Told what was dropped, so the panel can say which entries this server will not wear
	-- rather than leaving the player to notice a missing hat.
	net.Start("PS_Loadout_Result")
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
	if not current then return end

	-- After the gamemode has finished moving them: PS_CanEquipItem asks what team they are on,
	-- and on this tick that is still being decided.
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		if worn[ply] ~= current then return end

		local accepted, refused = Filter(ply, current.items)
		if #refused == 0 then return end

		Show(ply, accepted, current.colour, current.useColor2)

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
	if not current then return end

	timer.Simple(1, function()
		if IsValid(ply) and worn[ply] == current then
			Show(ply, current.items, current.colour, current.useColor2)
		end
	end)
end)

-- Read by anything that needs to know an appearance is borrowed rather than owned.
function PS:GetWornLoadout(ply)
	return worn[ply]
end
