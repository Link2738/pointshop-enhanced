local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'freddyar'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/cktheamazingfrog/freddy/freddyar.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/cktheamazingfrog/freddy/c_arms/freddyararms.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {},
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
