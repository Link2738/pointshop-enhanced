local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'eva'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/clancy/eva/eva.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/clancy/eva/c_arms/eva_arms.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0 } },
    ["Headset"] = { id = 2, values = { 0, 1 } },
    ["Sunglasses"] = { id = 3, values = { 0, 1 } },
    ["Vest"] = { id = 4, values = { 0, 1 } },
    ["Horn"] = { id = 5, values = { 0, 1 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
