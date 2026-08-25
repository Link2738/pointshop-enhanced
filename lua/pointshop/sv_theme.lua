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

local DATA_PATH = "pointshop/theme_default.json"

-- Raw JSON string as stored. Kept as a string rather than a decoded table because it is
-- only ever written to disk or put on the wire — decoding it here would be work done for
-- nobody.
local defaultJSON = nil

local function Load()
	if not file.Exists(DATA_PATH, "DATA") then return end

	local raw = file.Read(DATA_PATH, "DATA")
	if not raw or raw == "" then return end

	-- Parsed once purely as a validity check, so a corrupt file is caught here rather than
	-- being broadcast to every client to fail on individually.
	local ok, tbl = pcall(util.JSONToTable, raw)
	if ok and istable(tbl) then
		defaultJSON = raw
		print("[PointShop] Loaded default UI palette from " .. DATA_PATH)
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

hook.Add("Initialize", "PS_LoadThemeDefault", Load)

hook.Add("PlayerInitialSpawn", "PS_SyncThemeDefaultOnJoin", function(ply)
	-- Same delay as the item-defaults sync: the client's Lua state is not ready to receive
	-- on the same tick as the spawn.
	timer.Simple(1, function()
		if IsValid(ply) then Send(ply) end
	end)
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

	-- Bound the write before touching disk. A palette is well under a kilobyte; anything
	-- larger is not a palette.
	if #raw > 8192 then return end

	local ok, tbl = pcall(util.JSONToTable, raw)
	if not (ok and istable(tbl)) then return end

	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end
	file.Write(DATA_PATH, raw)
	defaultJSON = raw

	print(string.format("[PointShop] %s set the default UI palette.", ply:Nick()))

	Send()
end)
