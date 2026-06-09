local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'bernard_the_bear'
ITEM.Price = 1000
ITEM.Model = 'models/gemboi/jp_the_fox/bernard/bernard_the_bear.mdl'
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["bernard"] = { id = 1, values = { 0 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
    },
    playercolor = Vector(1, 1, 1)
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
