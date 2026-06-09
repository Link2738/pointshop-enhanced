local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'klee'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/genshin/klee/klee.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/genshin/klee/c_arms/klee_arms.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["reference"] = { id = 1, values = { 0 } },
    ["hat"] = { id = 2, values = { 0, 1, 2 } },
    ["hair"] = { id = 3, values = { 0 } },
    ["body"] = { id = 4, values = { 0 } },
    ["scarf_fluff"] = { id = 5, values = { 0, 1 } },
    ["hoodie_fluff"] = { id = 6, values = { 0 } },
    ["backpack"] = { id = 7, values = { 0, 1, 2 } },
    ["legs"] = { id = 8, values = { 0 } },
    ["legs_flower"] = { id = 9, values = { 0, 1 } },
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
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
