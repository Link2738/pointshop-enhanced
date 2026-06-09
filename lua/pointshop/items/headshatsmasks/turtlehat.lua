local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'Turtle Hat'
ITEM.Price = 100
ITEM.Model = 'models/props/de_tides/Vending_turtle.mdl'
ITEM.Attachment = 'eyes'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false

ITEM.DefaultModifications = {
    scale = 1,
    offsetX = -3,
    offsetY = 0,
    offsetZ = 0,
    rotation = -90,
    axis = "Forward",
    axisDeg = 0,
    color = Color(255, 255, 255, 255)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
