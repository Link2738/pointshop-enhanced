local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'stickguy'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/conex/stickguy/stickguy.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'models/gemboi/conex/stickguy/stickguy_arms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["police"] = { id = 1, values = { 0 } },
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
