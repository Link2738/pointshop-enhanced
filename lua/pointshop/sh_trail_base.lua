--[[
    pointshop/sh_trail_base.lua
    Base for PointShop trail items.

    Usage in an item file:
        local BASE = include("pointshop/sh_trail_base.lua") or {}
        ITEM.Name     = "My Trail"
        ITEM.Price    = 150
        ITEM.Material = "trails/laser.vmt"   -- sprite material for the ribbon
        ITEM.TYPE     = "trail"
        for k, v in pairs(BASE) do ITEM[k] = v end
--]]

if SERVER then
    AddCSLuaFile()
end

local BASE = {}

function BASE:OnEquip(ply, modifications)
    if not SERVER then return end
    if not IsValid(ply) then return end

    SafeRemoveEntity(ply.PS_Trail)

    local color = Color(255, 255, 255, 255)
    if modifications and modifications.color then
        color = modifications.color
    end

    ply.PS_Trail = util.SpriteTrail(
        ply, 0, color, false,
        15, 1, 4, 0.125,
        self.Material
    )
end

function BASE:OnHolster(ply)
    if not SERVER then return end
    SafeRemoveEntity(ply.PS_Trail)
end

function BASE:OnModify(ply, modifications)
    if not SERVER then return end
    SafeRemoveEntity(ply.PS_Trail)
    self:OnEquip(ply, modifications)
end

function BASE:Modify(ply, modifications)
    if CLIENT then
        local panel = PS.UI.Open("PSItemCustomizationPanel")
        panel:SetItem(self)
        if PS and PS.ToggleMenu then PS:ToggleMenu() end
    end
end

function BASE:OnSpawn(ply, modifications)
    self:OnEquip(ply, modifications)
end

function BASE:ModifyClientsideModel() end
function BASE:OnRemove(ply) end

return BASE
