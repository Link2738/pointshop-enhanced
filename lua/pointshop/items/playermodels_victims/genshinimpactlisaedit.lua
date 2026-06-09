local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'genshin_impact_lisa_edit'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/genshin/lisa/genshin_impact_lisa_edit.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/genshin/lisa/c_arms/genshin_impact_lisa_arms_edit.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["hat"] = { id = 1, values = { 0, 1 } },
    ["earring"] = { id = 2, values = { 0, 1 } },
    ["hair"] = { id = 3, values = { 0 } },
    ["collar"] = { id = 4, values = { 0 } },
    ["dress"] = { id = 5, values = { 0 } },
    ["arms"] = { id = 6, values = { 0 } },
    ["jewel_neckless"] = { id = 7, values = { 0, 1 } },
    ["waistband"] = { id = 8, values = { 0, 1 } },
    ["legs"] = { id = 9, values = { 0 } },
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
