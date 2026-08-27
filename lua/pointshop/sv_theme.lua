--[[
	pointshop/sv_theme.lua
	Server-held default UI palette.

	The palette itself is a per-player choice — see pointshop/cl_theme.lua. This file only
	holds the fallback an owner can set for players who have not picked their own, so a
	server with a house style does not have to ship a modified addon to get it.

	Deliberately small: the server stores an opaque JSON blob and hands it back out. It has
	no opinion on what keys are in it, because the client already clamps and filters what it
	applies — validating the same thing twice, in two places that would drift apart, buys
	nothing here. Nothing in this file can affect gameplay.
]]

util.AddNetworkString("PS_Theme_SetDefault")
util.AddNetworkString("PS_Theme_Default")

-- The two halves of the hash handshake.
--
-- On join the server offers a hash rather than a payload. A client whose cached copy hashes
-- the same is already correct and says nothing; one that differs asks, and only then does the
-- real data cross the wire.
--
-- Almost every join is the first case, so almost every join costs 64 bytes instead of a few
-- kilobytes -- and the ones that are not are exactly the joins that needed the data: an owner
-- changed something, or the client's cache is truncated or corrupt.
util.AddNetworkString("PS_Theme_Hash")
util.AddNetworkString("PS_Theme_Request")

local DATA_PATH = "pointshop/theme_default.json"

-- Raw JSON as stored, and the hash of its canonical form.
--
-- The hash is kept alongside rather than computed per join: it changes only when the data
-- does, and hashing a few kilobytes for every player who connects is work with a known answer.
local defaultJSON = nil
local defaultHash = nil

local function Rehash()
	if not defaultJSON then defaultHash = nil return end

	local ok, tbl = pcall(util.JSONToTable, defaultJSON)
	defaultHash = (ok and istable(tbl)) and PS.ThemeSync.Hash(tbl) or nil
end

local function Load()
	if not file.Exists(DATA_PATH, "DATA") then return end

	local raw = file.Read(DATA_PATH, "DATA")
	if not raw or raw == "" then return end

	-- Parsed once purely as a validity check, so a corrupt file is caught here rather than
	-- being broadcast to every client to fail on individually.
	local ok, tbl = pcall(util.JSONToTable, raw)
	if ok and istable(tbl) then
		defaultJSON = raw
		Rehash()
		print("[PointShop] Loaded server theme from " .. DATA_PATH)
	else
		print("[PointShop] Could not parse " .. DATA_PATH .. ", ignoring it.")
	end
end

local function Send(target)
	if not defaultJSON then return end

	net.Start("PS_Theme_Default")
		net.WriteString(defaultJSON)
	if IsValid(target) then net.Send(target) else net.Broadcast() end
end

-- Offers the hash. An empty string means "there is nothing published", which a client needs
-- told as much as it needs told about a change -- otherwise a cache from a previous owner
-- setting would live forever after that setting was cleared.
local function Offer(target)
	net.Start("PS_Theme_Hash")
		net.WriteString(defaultHash or "")
	if IsValid(target) then net.Send(target) else net.Broadcast() end
end

hook.Add("Initialize", "PS_LoadThemeDefault", Load)

hook.Add("PlayerInitialSpawn", "PS_SyncThemeDefaultOnJoin", function(ply)
	-- Same delay as the item-defaults sync: the client's Lua state is not ready to receive
	-- on the same tick as the spawn.
	timer.Simple(1, function()
		if IsValid(ply) then Offer(ply) end
	end)
end)

-- A client whose hash did not match. Not gated: this only ever sends the theme, which every
-- client is entitled to and would otherwise have been handed unasked.
net.Receive("PS_Theme_Request", function(_, ply)
	if IsValid(ply) then Send(ply) end
end)

net.Receive("PS_Theme_SetDefault", function(_, ply)
	-- Same gate as the item defaults, reused rather than reinvented. That file documents
	-- why it is not ply:IsSuperAdmin(): other ULX ranks commonly inherit superadmin, which
	-- would widen this below owner without anyone noticing.
	--
	-- Tested for existence first. ps_item_defaults.lua loads from lua/autorun/server/, so
	-- after this file; if it ever fails to load at all, the correct behaviour is to refuse
	-- every request rather than to error out of the handler and leave the outcome unclear.
	if not PS_IsItemDefaultOwner then return end
	if not PS_IsItemDefaultOwner(ply) then return end

	local raw = net.ReadString()

	-- Bound the write before touching disk. A full palette blob measured 3182 bytes, and the
	-- per-look metrics sections add a little on top; 8K leaves room for both without letting
	-- anything arrive that is not a look.
	if #raw > 8192 then return end

	local ok, tbl = pcall(util.JSONToTable, raw)
	if not (ok and istable(tbl)) then return end

	-- MERGED into what is stored, not written over it.
	--
	-- A message carries the sections it is about and no others: the layout panel sends sizes
	-- only, the appearance side sends colours only. Writing the message straight to disk
	-- therefore deleted whatever it did not mention -- saving a window size silently threw
	-- away the house palette, and the file was found down at 161 bytes with no colours left
	-- in it.
	--
	-- The client already reads an absent section as "leave that alone". This is the half that
	-- persists, and it has to agree.
	local stored = {}
	if defaultJSON then
		local okStored, prev = pcall(util.JSONToTable, defaultJSON)
		if okStored and istable(prev) then stored = prev end
	end

	-- Sizes and colours live in one file and are written independently.
	--
	-- Each section is replaced whole when the message carries it and left alone when it does
	-- not, so moving a window never touches a palette and vice versa. Writing the message
	-- straight to disk is what deleted a palette when a size was saved.
	--
	--   colours   per look: { [""] = {...}, classic = {...} }
	--   metrics   per look, same shape
	local touched = {}
	for _, section in ipairs(PS.ThemeSync.SECTIONS) do
		if istable(tbl[section]) then
			stored = PS.ThemeSync.MergeSection(stored, section, tbl[section])
			touched[#touched + 1] = section
		end
	end

	-- A blob naming none of them says nothing, so there is nothing to store.
	if #touched == 0 then return end

	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end

	defaultJSON = util.TableToJSON(stored)
	file.Write(DATA_PATH, defaultJSON)
	Rehash()

	print(string.format("[PointShop] %s set the server theme: %s.",
		ply:Nick(), table.concat(touched, ", ")))

	-- Pushed, not offered. Everyone connected is holding something that is now wrong, and
	-- making each of them notice via a hash and ask for it is a round trip to reach the same
	-- place. The offer is for joins, where the usual answer is "nothing to do".
	Send()
end)

-- Clearing what an owner published is done from the appearance panel, by sending an empty
-- section for the look being cleared. There is no console command for it.
--
-- Worth knowing if the file is ever edited by hand: deleting it is not enough on a running
-- server. The JSON is held in memory for the life of the server and re-sent to every player
-- as they join, so the old data keeps arriving until a restart and the file reappears at the
-- next save.
