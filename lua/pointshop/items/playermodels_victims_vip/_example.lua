--[[
    EXAMPLE VIP playermodel item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    Same schema as a normal playermodel. The difference is gating: __category.lua here
    restricts both team (CATEGORY.AllowedTeams = { 1 } = TEAM_VICTIMS) AND VIP status via
    CATEGORY:CanPlayerSee -> PS.Config.IsVIP(ply). Define PS.Config.IsVIP in sh_config.lua
    to control who sees/buys VIP items.
]]

local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'Example VIP Victim Model'
ITEM.Price = 1000
ITEM.Model = 'models/player/alyx.mdl'           -- placeholder; point at your .mdl
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true
ITEM.Arms = 'models/weapons/c_arms.mdl'
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
