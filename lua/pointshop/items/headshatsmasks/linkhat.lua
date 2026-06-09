local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'linkhat'
ITEM.Price = 1000
ITEM.Model = 'models/gmod_tower/linkhat.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 1,
    offsetX = 1,
    offsetY = 0.5,
    offsetZ = 1,
    rotation = 277,
    axis = "Up",
    axisDeg = -93.9,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
