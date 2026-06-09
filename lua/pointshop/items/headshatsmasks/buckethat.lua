local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'Bucket Hat'
ITEM.Price = 100
ITEM.Model = 'models/props_junk/MetalBucket01a.mdl'
ITEM.Attachment = 'eyes'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 0.65,
    offsetX = 3,
    offsetY = 0,
    offsetZ = -6,
    rotation = 0,
    axis = "Right",
    axisDeg = -135,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
