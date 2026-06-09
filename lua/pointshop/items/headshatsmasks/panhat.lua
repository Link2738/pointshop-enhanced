local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'Pan Hat'
ITEM.Price = 100
ITEM.Model = 'models/props_interiors/pot02a.mdl'
ITEM.Attachment = 'eyes'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 1,
    offsetX = 3,
    offsetY = 5.5,
    offsetZ = -1.5,
    rotation = 0,
    axis = "Right",
    axisDeg = 169,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
