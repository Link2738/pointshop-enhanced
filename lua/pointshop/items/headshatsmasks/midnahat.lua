local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'midnahat'
ITEM.Price = 1000
ITEM.Model = 'models/gmod_tower/midnahat.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 1.2,
    offsetX = -2.1,
    offsetY = 0,
    offsetZ = 0,
    rotation = 267,
    axis = "Forward",
    axisDeg = -90,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
