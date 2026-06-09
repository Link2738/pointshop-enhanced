local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'catears'
ITEM.Price = 1000
ITEM.Model = 'models/gmod_tower/catears.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 0.9,
    offsetX = 0,
    offsetY = 0,
    offsetZ = 3.5,
    rotation = 260,
    axis = "Forward",
    axisDeg = -90,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
