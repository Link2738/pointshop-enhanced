--[[
    pointshop/sh_swep_base.lua
    Base for PointShop SWEP (weapon) items.

    Usage in an item file:
        local BASE = include("pointshop/sh_swep_base.lua") or {}
        ITEM.Name      = "My Weapon"
        ITEM.Price     = 2000
        ITEM.ClassName = "weapon_myswep"   -- SWEP class name
        ITEM.Model     = "models/weapons/w_myswep.mdl"  -- world model (for PS preview)
        ITEM.TYPE      = "swep"
        for k, v in pairs(BASE) do ITEM[k] = v end

    Optional:
        ITEM.GiveOnSpawn  = true   -- give every spawn (default true)
        ITEM.DropOnDeath  = false  -- drop on death instead of strip (default false)
        ITEM.AllowDuplicate = false -- give even if player already carries the weapon (default false)
--]]

if SERVER then
    AddCSLuaFile()
end

local BASE = {}

-- Give the weapon when the player equips the item or spawns with it equipped.
function BASE:OnEquip(ply, modifications)
    if not SERVER then return end
    if not IsValid(ply) then return end
    if not self.ClassName or self.ClassName == "" then
        ErrorNoHalt("[PointShop SWEP] Item '" .. tostring(self.Name) .. "' has no ClassName set.\n")
        return
    end

    -- Optionally skip if the player already has it (avoids double-equip on respawn)
    if not self.AllowDuplicate and ply:HasWeapon(self.ClassName) then return end

    ply:Give(self.ClassName)
end

-- Strip the weapon when the item is holstered or the player dies.
function BASE:OnHolster(ply, modifications)
    if not SERVER then return end
    if not IsValid(ply) then return end
    if not self.ClassName or self.ClassName == "" then return end

    if self.DropOnDeath and ply:Alive() == false then
        -- Let the gamemode handle dropping naturally; just remove from loadout on next spawn.
        return
    end

    ply:StripWeapon(self.ClassName)
end

-- Re-give on spawn (called by PS_PlayerSpawn via OnEquip after a 1-second delay,
-- meaning it runs AFTER the gamemode has set up the player's default loadout).
-- Return false here to suppress re-giving on spawn if you want equip-only behaviour.
function BASE:OnSpawn(ply)
    if self.GiveOnSpawn == false then return end
    self:OnEquip(ply)
end

-- No clientside model needed for weapons.
function BASE:ModifyClientsideModel(ply, model, pos, ang, modifications) end
function BASE:OnRemove(ply) end

return BASE
