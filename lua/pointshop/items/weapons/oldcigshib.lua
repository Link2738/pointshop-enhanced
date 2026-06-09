local BASE = include("pointshop/sh_swep_base.lua") or {}

ITEM.Name      = 'oldcigshib'
ITEM.Price     = 1000
ITEM.ClassName = 'weapon_oldcigshib'
ITEM.Model     = 'models/gemboi/test/test/oldcigshib.mdl'
ITEM.TYPE      = 'swep'

for k, v in pairs(BASE) do
    ITEM[k] = v
end
