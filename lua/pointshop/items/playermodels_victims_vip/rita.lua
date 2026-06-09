local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'rita'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/honkai/rita/rita_edit.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/honkai/rita/c_arms/rita_arms_edit.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0 } },
    ["Head"] = { id = 2, values = { 0 } },
    ["Arms"] = { id = 3, values = { 0, 1 } },
    ["Belt"] = { id = 4, values = { 0, 1 } },
    ["Leg"] = { id = 5, values = { 0, 1 } },
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
