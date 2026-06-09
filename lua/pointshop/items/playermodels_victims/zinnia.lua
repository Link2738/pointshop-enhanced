local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'zinnia'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/pokemon/zinnia/zinnia.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/pokemon/zinnia/c_arms/zinnia.mdl'
ITEM.SkinCount = 7

ITEM.Bodygroups = {
    ["body"] = { id = 1, values = { 0 } },
    ["Cape"] = { id = 2, values = { 0, 1 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
