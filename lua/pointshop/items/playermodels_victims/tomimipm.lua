local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'tomimi_pm'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/arknights/tomimi/tomimi_pm.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/arknights/tomimi/c_arms/tomimi_arms.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["manager"] = { id = 1, values = { 0 } },
    ["a"] = { id = 2, values = { 0 } },
    ["b"] = { id = 3, values = { 0 } },
    ["c"] = { id = 4, values = { 0 } },
    ["d"] = { id = 5, values = { 0 } },
    ["e"] = { id = 6, values = { 0 } },
    ["f"] = { id = 7, values = { 0 } },
    ["ahoge"] = { id = 8, values = { 0, 1 } },
    ["earrings"] = { id = 9, values = { 0, 1 } },
    ["glasses"] = { id = 10, values = { 0, 1 } },
    ["ring"] = { id = 11, values = { 0, 1 } },
    ["short"] = { id = 12, values = { 0, 1 } },
    ["long"] = { id = 13, values = { 0, 1 } },
    ["hood"] = { id = 14, values = { 0, 1 } },
    ["snood"] = { id = 15, values = { 0, 1 } },
    ["sleeves"] = { id = 16, values = { 0, 1 } },
    ["mantle"] = { id = 17, values = { 0, 1 } },
    ["flower"] = { id = 18, values = { 0, 1 } },
    ["tail"] = { id = 19, values = { 0, 1 } },
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
        [14] = 0,
        [15] = 0,
        [16] = 0,
        [17] = 0,
        [18] = 0,
        [19] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
