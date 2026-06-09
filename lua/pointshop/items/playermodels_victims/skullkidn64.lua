local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'skull_kidn64'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/nintendo/skull_kid/skull_kidn64.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/nintendo/skull_kid/c_arms/c_arms_skull_kid.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Skull"] = { id = 1, values = { 0 } },
    ["majoras_mask"] = { id = 2, values = { 0, 1, 2 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
