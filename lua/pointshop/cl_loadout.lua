--[[
	pointshop/cl_loadout.lua

	Loadouts, client side: the definitions and which one is on.

	They live here, in the player's own data folder, and never reach the server's storage. That
	is the whole design: an outfit is a preference, it belongs to the person who made it, and
	keeping eight of them per player in SQL would be paying for something purely cosmetic.

	It is also what makes them survive a rejoin or a map change without the server remembering
	anything -- the client still has the file, so it re-applies on spawn. If a player wipes
	their own files they lose their outfits, which is the trade.
]]--

if not CLIENT then return end

PS = PS or {}
PS.Loadouts = PS.Loadouts or {}

local L = PS.Loadouts

-- One file per slot, named after the slot number.
--
-- The folder is the list, and the names are the slots -- so trying someone else's loadout is
-- dropping their file in and renaming it to the slot you want it in. A single blob could not
-- do that: you would have to open it, find the right entry, and paste theirs over it.
--
-- Which is also why the active slot does NOT live in there. The folder holds exactly 1.json
-- through 8.json and nothing else, so there is never a question about what a file in it is.
local DIR       = "pointshop/loadouts"
local DATA_PATH = "pointshop/loadouts.json"   -- the active slot, and nothing else

local function SlotFile(i)
	return DIR .. "/" .. i .. ".json"
end

-- Eight is a decision, not a limit of the format: a fixed set of slots keeps the panel a
-- simple list and bounds what the server validates on each apply.
L.MAX = 8

-- { [1] = { name, model, colour = {r,g,b}, useColor2, items = { {id, mods}, ... } }, ... }
L.Slots  = {}
L.Active = nil

-- Whatever the server refused last time, by item id, so the panel can say why.
L.Refused = {}

-- ============================================================================
-- STORAGE
-- ============================================================================

local function ReadStored()
	if not file.Exists(DATA_PATH, "DATA") then return {} end

	local raw = file.Read(DATA_PATH, "DATA")
	if not raw or raw == "" then return {} end

	local ok, tbl = pcall(util.JSONToTable, raw)
	return (ok and istable(tbl)) and tbl or {}
end

-- Same read-modify-write shape as the theme's file, and for the same reason: a save names
-- only what it changes, so writing the active slot cannot destroy the definitions.
local function WriteStored(changes)
	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end

	local stored = ReadStored()
	for k, v in pairs(changes) do stored[k] = v end

	file.Write(DATA_PATH, util.TableToJSON(stored, true))
end

-- A slot per file: written when it holds something, deleted when it does not.
--
-- Deleting is what makes an empty slot actually empty on disk, so the folder always says the
-- truth about what you have -- an 8.json left behind by a slot you cleared would come back
-- the next time anything reloaded.
function L.Save()
	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end
	if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end

	for i = 1, L.MAX do
		local path = SlotFile(i)
		local slot = L.Slots[i]

		if istable(slot) then
			file.Write(path, util.TableToJSON(slot, true))
		elseif file.Exists(path, "DATA") then
			file.Delete(path)
		end
	end

	WriteStored({ active = L.Active })
end

-- Re-read from disk. Called on load and whenever the panel opens, so a file dropped into the
-- folder mid-session is picked up rather than needing a restart -- which is the whole point
-- of the folder being the list.
function L.Load()
	L.Slots = {}

	for i = 1, L.MAX do
		local raw = file.Read(SlotFile(i), "DATA")

		if raw and raw ~= "" then
			-- Guarded: these are files a player can hand-edit or be handed by someone else,
			-- so a malformed one is expected eventually and must cost only its own slot.
			local ok, slot = pcall(util.JSONToTable, raw)
			if ok and istable(slot) and istable(slot.items) then L.Slots[i] = slot end
		end
	end

	local stored = ReadStored()
	L.Active = isnumber(stored.active) and stored.active or nil
	if L.Active and not L.Slots[L.Active] then L.Active = nil end
end

-- ============================================================================
-- CAPTURE
-- ============================================================================

-- What the player is wearing right now, as a loadout.
--
-- Reads the client's own copy of the inventory rather than asking the server, because the
-- client already has it -- PS_Items is synced for its owner -- and because a capture is about
-- what this person can see on themselves.
-- A playermodel's current settings, read off the character.
--
-- Not from PS_Items[id].Modifiers, which is where everything else comes from. That cache is
-- filled when the client joins and never again for a playermodel: the customization handler
-- updates the server's copy and the customization store, and the client's copy sits at
-- whatever it was at join. Reading it captured the colour, skin and bodygroups the player had
-- when they connected rather than the ones they are wearing.
--
-- Accessories are not affected and keep using the cache -- their base writes the client's copy
-- in ApplyAccessorySettings, so it stays current.
--
-- The channel is the item's, not a guess. UseColor2Proxy true means the colour is in the
-- proxy, which reads back as a 0-1 vector; false means it is modulation, which reads back as
-- a Color. The other channel is neutral by then and reading it gives white.
local function WornModelMods(ply, ITEM)
	-- Only the ones the ITEM says are choices.
	--
	-- Walking 0 to GetNumBodyGroups() captured every group the model has, including the ones
	-- the item pins to a single value and group 0, which it does not declare at all. Those are
	-- not settings -- a bodygroup with one option cannot be chosen wrong or right, and storing
	-- it writes down a decision nobody made.
	--
	-- ITEM.Bodygroups is the item saying which are which: an entry with more than one value is
	-- offered to the player, and an entry with one is fixed. No declaration means nothing is
	-- adjustable, so nothing is captured.
	local bodygroups = {}

	for _, def in pairs(ITEM.Bodygroups or {}) do
		if istable(def) and def.id and istable(def.values) and #def.values > 1 then
			bodygroups[def.id] = ply:GetBodygroup(def.id)
		end
	end

	local colour

	if ITEM.UseColor2Proxy then
		local v = ply:GetPlayerColor()
		colour = { math.Round(v.x * 255), math.Round(v.y * 255), math.Round(v.z * 255) }
	else
		local c = ply:GetColor()
		colour = { c.r, c.g, c.b }
	end

	return {
		skin        = ply:GetSkin(),
		bodygroups  = bodygroups,
		playercolor = colour,
	}
end

function L.Capture(name)
	local ply = LocalPlayer()
	local items = {}

	for id, data in pairs(ply.PS_Items or {}) do
		local ITEM = PS.Items[id]

		if data.Equipped and ITEM then
			items[#items + 1] = {
				id   = id,
				mods = PS.IsPlayermodelItem(ITEM) and WornModelMods(ply, ITEM) or data.Modifiers,
			}
		end
	end

	-- Items only.
	--
	-- There were `colour` and `useColor2` fields alongside. The colour was a duplicate of the
	-- playermodel entry's own playercolor, and the flag was a copy of ITEM.UseColor2Proxy --
	-- a property of the item, so a saved loadout held a snapshot of it and went on asserting
	-- the old value after the item changed.
	return {
		name  = name or ("Loadout " .. os.date("%H:%M")),
		items = items,
	}
end

-- ============================================================================
-- APPLY
-- ============================================================================

function L.Apply(index)
	local slot = L.Slots[index]
	if not slot then return end

	-- Items only. The colour is in the playermodel entry's own modifiers, which are in this
	-- table already, and the channel is ITEM.UseColor2Proxy from the shared item table -- so
	-- the server can work both out and neither is ours to assert.
	net.Start("PS_Loadout_Apply")
		net.WriteTable(slot.items)
	net.SendToServer()

	L.Active = index
	L.Save()
end

function L.Clear()
	net.Start("PS_Loadout_Clear")
	net.SendToServer()

	L.Active = nil
	L.Refused = {}
	L.Save()
end

net.Receive("PS_Loadout_Result", function()
	local refused = net.ReadTable()

	L.Refused = {}
	if istable(refused) then
		for _, entry in ipairs(refused) do
			if entry.id then L.Refused[entry.id] = entry.reason or "Refused." end
		end
	end

	hook.Run("PS_LoadoutResult", L.Refused)
end)

-- ============================================================================
-- SPAWN
-- ============================================================================

L.Load()

-- Re-applies on spawn, which is what makes an outfit outlive a rejoin or a map change while
-- the server stores nothing.
--
-- Delayed for the same reason the theme and item-defaults syncs are: the inventory has not
-- arrived on the same tick as the spawn, and an apply against an empty PS_Items would be
-- refused item by item and clear the slot for no reason.
hook.Add("InitPostEntity", "PS_LoadoutReapply", function()
	timer.Simple(3, function()
		if L.Active and L.Slots[L.Active] then L.Apply(L.Active) end
	end)
end)
