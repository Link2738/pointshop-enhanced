--[[
    EXAMPLE weapon (SWEP) item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    Gives a scripted weapon when equipped and strips it when holstered. The give / strip /
    respawn-regive logic lives in sh_swep_base.lua. The SWEP itself (weapon_<class>) must
    exist elsewhere (your gamemode/addon weapons).
]]

local BASE = include("pointshop/sh_swep_base.lua") or {}

ITEM.Name      = 'Example Weapon'
ITEM.Price     = 1000
ITEM.ClassName = 'weapon_example'               -- the SWEP class to give (must exist)
ITEM.Model     = 'models/weapons/w_pistol.mdl'  -- world model, for the shop preview
ITEM.TYPE      = 'swep'

-- Optional behaviour flags (defaults shown):
-- ITEM.GiveOnSpawn    = true   -- re-give on every spawn
-- ITEM.DropOnDeath    = false  -- leave the weapon on death instead of stripping
-- ITEM.AllowDuplicate = false  -- give even if the player already carries the class

for k, v in pairs(BASE) do
    ITEM[k] = v
end
