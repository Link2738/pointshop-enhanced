--[[
    EXAMPLE trail item — TEMPLATE ONLY (skipped by the loader; "_"-prefixed).
    Copy to a real filename to use it.

    A trail is a sprite ribbon attached to the player. The base handles equip/holster/
    spawn/modify and the color customization panel. Set ITEM.Material to the .vmt sprite.
]]

local BASE = include("pointshop/sh_trail_base.lua") or {}

ITEM.Name = 'Example Trail'
ITEM.Price = 150
ITEM.Material = 'trails/laser.vmt'
ITEM.TYPE = "trail"

for k, v in pairs(BASE) do ITEM[k] = v end
