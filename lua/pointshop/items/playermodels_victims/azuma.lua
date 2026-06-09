local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'azuma'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/john_clamcy/azuma/azuma.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/john_clamcy/azuma/azuma_arms.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0 } },
    ["outline"] = { id = 2, values = { 0 } },
    ["hair_face"] = { id = 3, values = { 0 } },
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
