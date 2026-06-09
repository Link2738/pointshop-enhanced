local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'acerola'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/pacagma/acerola/acerola_player.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/pacagma/acerola/acerola_arms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["body"] = { id = 1, values = { 0 } },
    ["Facials"] = { id = 2, values = { 0, 1, 2, 3, 4, 5, 6, 7 } },
    ["Gold"] = { id = 3, values = { 0, 1 } },
    ["Ribbon"] = { id = 4, values = { 0, 1 } },
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
