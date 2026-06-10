--[[
    EXAMPLE hat / head / mask item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    Hats, heads and masks are accessories (same schema as items/accessories), so they use
    sh_accessory_base.lua. What makes this category special is set in __category.lua:
    CATEGORY.AllowedEquipped = 2  -- a player may wear at most 2 items from this category at once.
]]

local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'Example Hat'
ITEM.Price = 1000
ITEM.Model = 'models/props_junk/cardboard_box001a.mdl'  -- placeholder; point at your .mdl
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 0.7,
    offsetX = 0,
    offsetY = 0,
    offsetZ = 4,
    rotation = 0,
    axis = "Forward",
    axisDeg = -90,
    color = Color(255, 255, 255, 255),
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
