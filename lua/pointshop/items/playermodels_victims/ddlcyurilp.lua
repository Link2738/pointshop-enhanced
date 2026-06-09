local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'ddlc_yuri_lp'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/mochi/ddlc/ddlc_yuri_lp.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/mochi/ddlc/c_arms/c_arms_ddlc_lp.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0 } },
    ["Outfit"] = { id = 2, values = { 0, 1 } },
    ["Eyes"] = { id = 3, values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 } },
    ["Mouth"] = { id = 4, values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } },
    ["Blush"] = { id = 5, values = { 0, 1 } },
    ["Crying"] = { id = 6, values = { 0, 1, 2 } },
    ["Sweat"] = { id = 7, values = { 0, 1 } },
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
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
