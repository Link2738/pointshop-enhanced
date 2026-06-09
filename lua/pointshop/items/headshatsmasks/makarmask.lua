local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'makarmask'
ITEM.Price = 1000
ITEM.Model = 'models/lordvipes/makarmask/makarmask.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 2,
    offsetX = 0.10,
    offsetY = 0,
    offsetZ = -7,
    rotation = 250,
    axis = "Forward",
    axisDeg = -90,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
