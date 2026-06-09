local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'witchhat'
ITEM.Price = 1000
ITEM.Model = 'models/gmod_tower/witchhat.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    offsetZ = 3,
    rotation = 0,
    axis = "Right",
    axisDeg = -90,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
