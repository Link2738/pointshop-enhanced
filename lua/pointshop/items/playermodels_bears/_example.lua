--[[
    EXAMPLE bear playermodel item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    Same schema as any playermodel. __category.lua restricts this category to the bear
    teams (CATEGORY.AllowedTeams = { 2, 3 } = TEAM_BEAR, TEAM_INFTBEAR), enforced
    server-side by PS:CanEquipForTeam — so only bears can equip models placed here.
]]

local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'Example Bear Model'
ITEM.Price = 1000
ITEM.Model = 'models/player/kleiner.mdl'        -- placeholder; point at your .mdl
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = false
ITEM.SkinCount = 1

ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,
    },
    playercolor = Vector(1, 1, 1),
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
