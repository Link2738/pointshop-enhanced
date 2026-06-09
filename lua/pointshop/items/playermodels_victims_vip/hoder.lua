local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'hoder'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/oumashu/hoder/hoder_pm.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'gemboi/oumashu/hoder/hoder_arms.mdl'
ITEM.SkinCount = 2

ITEM.Bodygroups = {
    ["outline"] = { id = 1, values = { 0, 1 } },
    ["face"] = { id = 2, values = { 0 } },
    ["body"] = { id = 3, values = { 0 } },
    ["hair"] = { id = 4, values = { 0 } },
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
