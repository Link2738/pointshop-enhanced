local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'basiilleaf_cat'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/vertiex/basiilleaf/basiilleaf_cat.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/vertiex/basiilleaf/c_arms/basiilleaf_cat_arms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["Cosmetics"] = { id = 1, values = { 0, 1 } },
    ["Emotions"] = { id = 2, values = { 0, 1, 2 } },
    ["Eyebrows"] = { id = 3, values = { 0, 1, 2 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
