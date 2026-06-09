local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'drinkcap'
ITEM.Price = 1000
ITEM.Model = 'models/gmod_tower/drinkcap.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    offsetZ = 2.65,
    rotation = 270,
    axis = "Foward",
    axisDeg = -91.6,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
