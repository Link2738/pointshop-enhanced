local BASE = include("pointshop/sh_swep_base.lua") or {}

ITEM.Name      = 'popcorn'
ITEM.Price     = 1000
ITEM.ClassName = 'weapon_popcorn'
ITEM.Model     = 'models/gemboi/test/test/popcorn.mdl'
ITEM.TYPE      = 'swep'

for k, v in pairs(BASE) do
    ITEM[k] = v
end
