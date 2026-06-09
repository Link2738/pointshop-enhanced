local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'majorasmask'
ITEM.Price = 1000
ITEM.Model = 'models/gmod_tower/majorasmask.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Head1'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 0.7,
    offsetX = 1.5,
    offsetY = 0,
    offsetZ = 1,
    rotation = 270,
    axis = "Forward",
    axisDeg = -90,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
