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

local DATA_PATH = "pointshop/loadouts.json"

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

function L.Save()
	WriteStored({ slots = L.Slots, active = L.Active })
end

function L.Load()
	local stored = ReadStored()

	L.Slots = {}
	if istable(stored.slots) then
		for i = 1, L.MAX do
			local slot = stored.slots[i] or stored.slots[tostring(i)]
			if istable(slot) and istable(slot.items) then L.Slots[i] = slot end
		end
	end

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
function L.Capture(name)
	local ply = LocalPlayer()
	local items = {}

	for id, data in pairs(ply.PS_Items or {}) do
		if data.Equipped and PS.Items[id] then
			items[#items + 1] = {
				id = id,

				-- Modifiers as stored, not as displayed. The customization panel may be open
				-- with unsaved changes on screen, and a loadout should record what the player
				-- has committed to, not what they are mid-experiment with.
				mods = data.Modifiers,
			}
		end
	end

	local pc = ply:GetPlayerColor()
	local rc = ply:GetColor()

	-- Which channel is carrying the colour decides which value means anything. The proxy path
	-- writes SetPlayerColor and neutralises SetColor; modulation does the reverse.
	local useColor2 = pc and (pc.x + pc.y + pc.z) < 2.99

	return {
		name  = name or ("Loadout " .. os.date("%H:%M")),
		items = items,
		useColor2 = useColor2,
		colour = useColor2
			and { math.Round(pc.x * 255), math.Round(pc.y * 255), math.Round(pc.z * 255) }
			or  { rc.r, rc.g, rc.b },
	}
end

-- ============================================================================
-- APPLY
-- ============================================================================

function L.Apply(index)
	local slot = L.Slots[index]
	if not slot then return end

	net.Start("PS_Loadout_Apply")
		net.WriteTable(slot.items)
		net.WriteColor(Color(slot.colour[1] or 255, slot.colour[2] or 255, slot.colour[3] or 255))
		net.WriteBool(slot.useColor2 and true or false)
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
