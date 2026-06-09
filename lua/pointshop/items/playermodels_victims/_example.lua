--[[
    EXAMPLE playermodel item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    Which team(s) may wear models in this category is set in __category.lua via
    CATEGORY.AllowedTeams (here { 1 } = TEAM_VICTIMS) and enforced server-side by
    PS:CanEquipForTeam, so a model placed here is only equippable by victims.

    Behaviour (SetModel, skin, bodygroups, player color, holster cleanup) comes from
    sh_playermodel_base.lua.
]]

local BASE = include("pointshop/sh_playermodel_base.lua")

ITEM.Name = 'Example Victim Model'
ITEM.Price = 1000
ITEM.Model = 'models/player/kleiner.mdl'        -- placeholder; point at your .mdl
ITEM.TYPE = 'playermodel'
ITEM.UseColor2Proxy = true                       -- true: recolor via SetPlayerColor ($color2 proxy)
                                                 -- false: recolor via SetColor render modulation
ITEM.Arms = 'models/weapons/c_arms.mdl'          -- optional viewmodel arms
ITEM.SkinCount = 1                               -- number of skins the model has

-- Bodygroups populate the customization panel. id = bodygroup index on the model;
-- values = the selectable sub-model values for that group.
ITEM.Bodygroups = {
    ["Body"] = { id = 1, values = { 0 } },
}

ITEM.DefaultModifications = {
    skin = 0,
    bodygroups = {
        [1] = 0,                                 -- keys are bodygroup ids (numbers)
    },
    playercolor = Vector(1, 1, 1),               -- normalized 0-1 RGB
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
