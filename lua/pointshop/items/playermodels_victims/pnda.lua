local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'pnda'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/sarugetchu/panda/pnda.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["pnda"] = { id = 1, values = { 0 } },
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
