local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'yella_pm'
ITEM.Price = 1000
ITEM.Model = 'models/dhampyr/yella_pm.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["reference"] = { id = 1, values = { 0 } },
    ["Body_Upper"] = { id = 2, values = { 0, 1 } },
    ["Body_Lower"] = { id = 3, values = { 0, 1 } },
    ["Hair"] = { id = 4, values = { 0, 1 } },
    ["Nails"] = { id = 5, values = { 0, 1 } },
    ["Hands"] = { id = 6, values = { 0, 1 } },
    ["Jewelry"] = { id = 7, values = { 0, 1 } },
    ["Belly_Jewelry"] = { id = 8, values = { 0, 1 } },
    ["Jacket"] = { id = 9, values = { 0, 1 } },
    ["Scarf"] = { id = 10, values = { 0 } },
    ["Ribbons"] = { id = 11, values = { 0 } },
    ["HB"] = { id = 12, values = { 0, 1 } },
    ["Gear"] = { id = 13, values = { 0 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
        [6] = 0,
        [7] = 0,
        [8] = 0,
        [9] = 0,
        [10] = 0,
        [11] = 0,
        [12] = 0,
        [13] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
