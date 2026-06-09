local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'kanna_pm'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/dewobedil/kanna/kanna_pm.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body_Color_D/C"] = { id = 1, values = { 0, 1 } },
    ["Horn_Color_D/C"] = { id = 2, values = { 0, 1, 2 } },
    ["Tail_Hair_Color_D/C"] = { id = 3, values = { 0, 1, 2 } },
    ["Jacket_Color_D/C"] = { id = 4, values = { 0, 1, 2 } },
    ["Tail_Color_D/C"] = { id = 5, values = { 0, 1, 2, 3, 4 } },
    ["Shoes_Color_D/C"] = { id = 6, values = { 0, 1, 2 } },
    ["tears"] = { id = 7, values = { 0, 1 } },
    ["blush"] = { id = 8, values = { 0, 1 } },
    ["blush"] = { id = 9, values = { 0, 1 } },
    ["eyes"] = { id = 10, values = { 0, 1 } },
    ["eyes"] = { id = 11, values = { 0, 1 } },
    ["skirt"] = { id = 12, values = { 0, 1 } },
    ["socks"] = { id = 13, values = { 0, 1 } },
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
