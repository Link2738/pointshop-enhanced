local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'lappland'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/john_clamcy/lappland/lappland.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/john_clamcy/lappland/c_arms/lappland_arms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["Hands"] = { id = 1, values = { 0 } },
    ["Body"] = { id = 2, values = { 0 } },
    ["Head"] = { id = 3, values = { 0 } },
    ["Hair"] = { id = 4, values = { 0 } },
    ["Tail"] = { id = 5, values = { 0 } },
    ["Belt"] = { id = 6, values = { 0, 1 } },
    ["Button"] = { id = 7, values = { 0, 1 } },
    ["Strap"] = { id = 8, values = { 0, 1 } },
    ["Strip"] = { id = 9, values = { 0, 1 } },
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
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
