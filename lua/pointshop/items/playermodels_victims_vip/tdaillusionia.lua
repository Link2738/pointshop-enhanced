local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'tda_illusionia'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/mackie/tda_illusionia/tda_illusionia.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.SkinCount = 5

ITEM.Bodygroups = {
    ["body"] = { id = 1, values = { 0 } },
    ["body_butterfly"] = { id = 2, values = { 0, 1 } },
    ["head"] = { id = 3, values = { 0 } },
    ["dress"] = { id = 4, values = { 0 } },
    ["hair"] = { id = 5, values = { 0 } },
    ["hairbutterfly"] = { id = 6, values = { 0, 1 } },
    ["boots"] = { id = 7, values = { 0 } },
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
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
