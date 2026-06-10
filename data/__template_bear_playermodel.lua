local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'ITEM_NAME_HERE'
ITEM.Price = 1000
ITEM.Model = 'models/path/to/bearmodel.mdl'
ITEM.TYPE = 'playermodel'
ITEM.Bodygroups = {
    ["GroupName"] = { id = 1, values = { 0, 1 } },
}

-- Default customization values
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
