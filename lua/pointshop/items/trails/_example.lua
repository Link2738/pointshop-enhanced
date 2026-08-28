--[[
    EXAMPLE trail item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    A trail is a sprite ribbon attached to the player. There is no shared base; define the
    hooks inline. Note this uses ITEM.Material (a .vmt sprite), not ITEM.Model. The trail
    color comes from the customization panel via modifications.color.
]]

ITEM.Name = 'Example Trail'
ITEM.Price = 150
ITEM.Material = 'trails/laser.vmt'      -- sprite material for the ribbon
ITEM.TYPE = "trail"

function ITEM:OnEquip(ply, modifications)
    SafeRemoveEntity(ply.PS_ExampleTrail)
    ply.PS_ExampleTrail = util.SpriteTrail(
        ply, 0,                                          -- entity, attachment id
        modifications.color or Color(255, 255, 255, 255),
        false,                                           -- additive
        15, 1,                                           -- start width, end width
        4,                                               -- length
        0.125,                                           -- texture resolution
        self.Material
    )
end

function ITEM:OnHolster(ply)
    SafeRemoveEntity(ply.PS_ExampleTrail)
end

-- Opens the shared customization panel (lets players recolor the trail).
function ITEM:Modify(modifications)
    if CLIENT then
        local panel = PS.UI.Open("PSItemCustomizationPanel")
        panel:SetItem(self)
        if PS and PS.ToggleMenu then PS:ToggleMenu() end
    end
end

function ITEM:OnModify(ply, modifications)
    SafeRemoveEntity(ply.PS_ExampleTrail)
    self:OnEquip(ply, modifications)
end
