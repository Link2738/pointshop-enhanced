local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'that_one_god'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/genshin/that_one_god/that_one_god.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0, 1 } },
    ["Back_Flap"] = { id = 2, values = { 0, 1 } },
    ["Hair"] = { id = 3, values = { 0, 1 } },
    ["Fluff"] = { id = 4, values = { 0, 1 } },
    ["Back_things"] = { id = 5, values = { 0, 1 } },
    ["Dark_leg_piece"] = { id = 6, values = { 0, 1 } },
    ["Light_leg_piece"] = { id = 7, values = { 0, 1 } },
    ["Cape"] = { id = 8, values = { 0, 1 } },
    ["Stars"] = { id = 9, values = { 0, 1 } },
    ["Front_Flaps"] = { id = 10, values = { 0, 1 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
        [5] = 0,
        [6] = 0,
        [7] = 0,
        [8] = 0,
        [9] = 0,
        [10] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
