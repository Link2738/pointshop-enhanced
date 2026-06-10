--[[
    EXAMPLE powerup item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    Powerups have no shared base — they implement OnEquip/OnHolster directly to apply some
    effect to the player while equipped, and undo it on holster. This example shrinks the
    player's model and hull. ITEM.Model is only used for the shop entry; NoPreview hides the
    3D inspector since the effect isn't a wearable model.
]]

ITEM.Name = 'Example Powerup'
ITEM.Price = 1000
ITEM.Model = 'models/props_junk/garbage_glassbottle003a.mdl'  -- shop icon model only
ITEM.NoPreview = true

function ITEM:OnEquip(ply, modifications)
    ply:SetModelScale(0.8, 1)
    -- Keep the collision hull sane after scaling.
    ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72))
    ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 45))
end

function ITEM:OnHolster(ply)
    ply:SetModelScale(1, 1)
    ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72))
    ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 45))
end
