--[[
    EXAMPLE accessory item — TEMPLATE ONLY.
    Files whose name starts with "_" are skipped by the item loader (see PS:LoadItems),
    so this never appears in the shop. Copy it to a real filename (e.g. fedora.lua) and
    fill in your own values.

    An accessory is a prop bolted to a bone (hats, wings, backpacks, masks...). The shared
    behaviour — bone follow, customization panel, color, offset/rotation/scale — comes from
    sh_accessory_base.lua. Players customize each item; all values are clamped server-side.
]]

local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'Example Accessory'                     -- name shown in the shop
ITEM.Price = 1000                                   -- cost in points
ITEM.Model = 'models/props_junk/watermelon01.mdl'   -- placeholder; point at your .mdl
ITEM.Bone = 'ValveBiped.Bip01_Head1'                -- bone the prop attaches to
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false                         -- true only if the model has a $color2 material proxy

-- Starting transform used the first time a player customizes this item.
ITEM.DefaultModifications = {
    scale = 1,                          -- clamped 0.1 - 2
    offsetX = 0,                        -- clamped -30 - 30
    offsetY = 0,
    offsetZ = 0,
    rotation = 0,                       -- 0 - 360, spin around the bone's up axis
    axis = "Right",                     -- "Right" | "Up" | "Forward"
    axisDeg = -90,                      -- -180 - 180, tilt along the chosen axis
    color = Color(255, 255, 255, 255),
}

for k, v in pairs(BASE) do
    ITEM[k] = v
end
