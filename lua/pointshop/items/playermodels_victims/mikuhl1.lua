local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'mikuhl1'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/xinus22/miku/mikuhl1.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/xinus22/miku/c_arms/mikuhl1_arms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["eyes"] = { id = 1, values = { 0, 1, 2, 3, 4, 5, 6, 7, 8 } },
    ["mouths"] = { id = 2, values = { 0, 1, 2, 3, 4, 5, 6, 7, 8 } },
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
