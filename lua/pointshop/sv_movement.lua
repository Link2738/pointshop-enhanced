--[[
	sv_movement.lua — owner-tunable movement, live.

	Jump power, step size, air acceleration and gravity are the settings you cannot pick
	from reading a config file. They are felt, not reasoned about, and the only honest way
	to set them is to stand in the map and move around while changing them. Editing
	sh_config.lua and restarting the server between guesses is not that.

	So these four live here instead: an owner sets them in game, they apply to everybody
	immediately, and they persist across restarts. PSCFG stays the shipped fallback for a
	server that has never opened the panel.

	OWNERSHIP AND TRUST

	Gated on PS_IsItemDefaultOwner, the same ULX "owner" check PointShop uses for
	server-wide defaults, rather than a second gate that could drift from it. Deliberately
	not IsSuperAdmin: other ranks commonly inherit that in ULX and this changes the game for
	every player on the server.

	Unlike PointShop's palette defaults, which are cosmetic and can trust the client to
	clamp, everything here affects gameplay. So the numbers are clamped HERE, on arrival,
	before anything stores or applies them. The client panel clamps too, but only so the
	sliders feel right -- the server never relies on it having done so.
]]

if not SERVER then return end

util.AddNetworkString("PS_Movement_Get")
util.AddNetworkString("PS_Movement_Set")
util.AddNetworkString("PS_Movement_Sync")

-- Under pointshop/, not hideandseek/, because this is one setting for both gamemodes now.
-- Movement that feels the same in Bear Hunt and Hide and Seek is the point -- a path per
-- gamemode would have been two sets of numbers drifting apart.
local DATA_DIR  = "pointshop"
local DATA_PATH = "pointshop/movement.json"

PS.Movement = PS.Movement or {}

-- Bounds are gameplay limits, not UI convenience.
--
--   JumpPower   below ~150 most map geometry stops being reachable; above ~400 players
--               clear walls the map intends as boundaries.
--   StepSize    the engine default is 18. Past roughly half player height you stop
--               walking over ledges and start walking up them, which reads as flying.
--   AirAccel    10 is stock Source. High values give near-total air control; past ~1000
--               it stops being control and starts being flight.
--   Gravity     600 is stock. Low gravity plus this gamemode's air control is a very
--               different game, which is worth being able to try, but not by accident.
local FIELDS = {
	JumpPower      = { min = 100, max = 400,  default = 250 },
	StepSize       = { min = 18,  max = 64,   default = 48  },
	AirAccelerate  = { min = 10,  max = 1000, default = 500 },
	Gravity        = { min = 200, max = 800,  default = 600 },
}

-- Current values. Seeded from the field defaults above, then overwritten by anything on disk.
--
-- Was seeded from PSCFG, the Hide and Seek config table. This lives in the addon now and runs
-- under Bear Hunt too, where that table does not exist -- and reading it would have made the
-- two gamemodes start from different numbers, which is the opposite of the point.
local current = {}
for k, f in pairs(FIELDS) do
	current[k] = math.Clamp(f.default, f.min, f.max)
end

function PS.Movement.Get(key)
	return current[key]
end

function PS.Movement.GetAll()
	return table.Copy(current)
end

-- ============================================================================
-- APPLYING
-- ============================================================================

-- Jump and step are per-player and have to be pushed to everyone alive; the two convars
-- are global. Called on every change and on spawn, so a player who joins after a change
-- gets the current values rather than the shipped ones.
local function ApplyToPlayer(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	ply:SetStepSize(current.StepSize)

	-- Jump power is also written by the player class on spawn (meta:OnSpawn reads
	-- CLASS.JumpPower). This runs after that and wins, which is the intent: the panel is
	-- the live value and the class field is the shipped default it overrides.
	ply:SetJumpPower(current.JumpPower)
end

function PS.Movement.Apply()
	game.ConsoleCommand("sv_airaccelerate " .. current.AirAccelerate .. "\n")
	game.ConsoleCommand("sv_gravity " .. current.Gravity .. "\n")

	for _, ply in ipairs(player.GetAll()) do
		ApplyToPlayer(ply)
	end
end

-- After the class has had its say. PlayerSpawn fires the class OnSpawn, which sets jump
-- power from CLASS.JumpPower; a plain hook here could land either side of it depending on
-- registration order, and landing first would mean the class silently undid the panel.
hook.Add("PlayerSpawn", "PS_MovementApply", function(ply)
	timer.Simple(0, function() ApplyToPlayer(ply) end)
end)

-- ============================================================================
-- PERSISTENCE
-- ============================================================================

local function Save()
	if not file.IsDir(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end
	file.Write(DATA_PATH, util.TableToJSON(current, true))
end

local function Load()
	if not file.Exists(DATA_PATH, "DATA") then return end

	local raw = file.Read(DATA_PATH, "DATA")
	if not raw or raw == "" then return end

	local ok, tbl = pcall(util.JSONToTable, raw)
	if not (ok and istable(tbl)) then
		print("[PS] Could not parse " .. DATA_PATH .. ", using config values.")
		return
	end

	-- Re-clamped on load, not trusted. The file is editable by hand and by an older build
	-- of this script whose bounds may have been different.
	for k, f in pairs(FIELDS) do
		local v = tonumber(tbl[k])
		if v then current[k] = math.Clamp(v, f.min, f.max) end
	end
	print("[PS] Loaded movement tuning from " .. DATA_PATH)
end

-- ============================================================================
-- NET
-- ============================================================================

local function SendTo(ply)
	net.Start("PS_Movement_Sync")
		net.WriteUInt(table.Count(FIELDS), 8)
		for k, v in pairs(current) do
			net.WriteString(k)
			net.WriteFloat(v)
		end
	net.Send(ply)
end

-- Anyone may ask for the values; only an owner may change them. Reading is harmless and
-- the panel needs them to populate before it knows whether it can write.
net.Receive("PS_Movement_Get", function(_, ply)
	if IsValid(ply) then SendTo(ply) end
end)

net.Receive("PS_Movement_Set", function(_, ply)
	if not IsValid(ply) then return end
	if not PS_IsItemDefaultOwner or not PS_IsItemDefaultOwner(ply) then
		COREFW:Dbg("MOVE", "Rejected movement change from non-owner " .. ply:Nick())
		return
	end

	local key = net.ReadString()
	local val = net.ReadFloat()
	local f = FIELDS[key]
	if not f then return end

	val = tonumber(val)
	if not val then return end

	current[key] = math.Clamp(val, f.min, f.max)
	Save()
	PS.Movement.Apply()

	COREFW:Dbg("MOVE", ply:Nick() .. " set " .. key .. " = " .. current[key])

	-- Everyone gets the new values, not just the owner: a spectating admin with the panel
	-- open should see it move, and it costs one small message per change.
	for _, p in ipairs(player.GetAll()) do SendTo(p) end
end)

-- ============================================================================
-- STARTUP
-- ============================================================================

hook.Add("InitPostEntity", "PS_MovementInit", function()
	Load()
	PS.Movement.Apply()
	print(string.format("[PS] Movement: jump=%d step=%d airaccel=%d gravity=%d",
		current.JumpPower, current.StepSize, current.AirAccelerate, current.Gravity))
end)

concommand.Add("has_movement_print", function(ply)
	local out = "[PS] movement:"
	for k, v in pairs(current) do out = out .. " " .. k .. "=" .. v end
	if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, out) else print(out) end
end)
