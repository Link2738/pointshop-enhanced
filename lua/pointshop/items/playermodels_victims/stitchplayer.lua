local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'stitch_player'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/mrmarco/stitch/stitch_player.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.Arms = 'gemboi/mrmarco/stitch/c_arms/stitch_arms.mdl'
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Space"] = { id = 1, values = { 0, 1 } },
    ["antenna"] = { id = 2, values = { 0, 1 } },
    ["spines"] = { id = 3, values = { 0, 1 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
