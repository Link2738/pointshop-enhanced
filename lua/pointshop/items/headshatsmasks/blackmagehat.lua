local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'blackmage_hat'
ITEM.Price = 1000
ITEM.Model = 'models/lordvipes/blackmage/blackmage_hat.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 0.35,
    offsetX = 0.5,
    offsetY = 0,
    offsetZ = -13,
    rotation = 0,
    axis = "Right",
    axisDeg = -90,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
