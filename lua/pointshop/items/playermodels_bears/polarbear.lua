local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'polar_bear'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/ssbu/ice_climbers/polar_bear.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/ssbu/ice_climbers/c_arms/polar_bear_arms.mdl'
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
