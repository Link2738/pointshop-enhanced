local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'atago'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/john_clamcy/atago/atago.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/john_clamcy/atago/c_arms/atago_arms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["Hair"] = { id = 1, values = { 0, 1, 2 } },
    ["Metal"] = { id = 2, values = { 0, 1 } },
    ["Skirt"] = { id = 3, values = { 0, 1, 2 } },
    ["Highheel"] = { id = 4, values = { 0, 1, 2 } },
    ["Cat"] = { id = 5, values = { 0, 1 } },
    ["Outline(Kinda"] = { id = 6, values = { 0 } },
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
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
