local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'russianhat1'
ITEM.Price = 1000
ITEM.Model = 'models/russianhat1.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'

ITEM.DefaultModifications = {
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    offsetZ = 0,
    rotation = 0,
    axis = "Right",
    axisDeg = -90,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
