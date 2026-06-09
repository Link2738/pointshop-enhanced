local BASE = include("pointshop/sh_swep_base.lua") or {}

ITEM.Name      = 'ciga'
ITEM.Price     = 1000
ITEM.ClassName = 'weapon_ciga'
ITEM.Model     = 'models/gemboi/test/test/ciga.mdl'
ITEM.TYPE      = 'swep'

for k, v in pairs(BASE) do
    ITEM[k] = v
end
