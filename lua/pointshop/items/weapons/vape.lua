local BASE = include("pointshop/sh_swep_base.lua") or {}

ITEM.Name      = 'vape'
ITEM.Price     = 1000
ITEM.ClassName = 'weapon_vape'
ITEM.Model     = 'models/gemboi/test/test/vape.mdl'
ITEM.TYPE      = 'swep'

for k, v in pairs(BASE) do
    ITEM[k] = v
end
