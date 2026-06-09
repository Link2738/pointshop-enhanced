local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'gasgirl'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/xinus22/gas_girl/gasgirl.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/xinus22/gas_girl/c_arms/gasgirlarms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["Gasmask"] = { id = 1, values = { 0 } },
    ["hood"] = { id = 2, values = { 0, 1, 2, 3 } },
    ["eyes"] = { id = 3, values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 } },
    ["mouths"] = { id = 4, values = { 0, 1, 2, 3, 4, 5, 6, 7 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
