local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'teto'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/tismo/teto/teto.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
