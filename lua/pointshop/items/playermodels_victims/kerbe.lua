local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'kerbe'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/grudomir/kerbe/kerbe.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["body"] = { id = 1, values = { 0 } },
    ["Hats"] = { id = 2, values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 } },
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
