local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'kurobe'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/seele_v1/kurobe/kurobe.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/seele/kurobe/c_arms/c_arms_kurobe.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["gun"] = { id = 1, values = { 0, 1 } },
    ["head"] = { id = 2, values = { 0 } },
    ["hair"] = { id = 3, values = { 0 } },
    ["hat"] = { id = 4, values = { 0, 1 } },
    ["body"] = { id = 5, values = { 0 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
