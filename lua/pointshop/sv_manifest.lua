--[[
	pointshop/sv_manifest.lua
	basic assets required on the client.
]]--

AddCSLuaFile "cl_init.lua"
AddCSLuaFile "cl_player_extension.lua"
AddCSLuaFile "cl_theme.lua"
AddCSLuaFile "cl_theme_classic.lua"
AddCSLuaFile "cl_theme_crimson.lua"
AddCSLuaFile "cl_ui.lua"
AddCSLuaFile "cl_loadout.lua"
AddCSLuaFile "cl_movement.lua"
AddCSLuaFile "vgui/DPointShopLoadouts.lua"
AddCSLuaFile "sh_config.lua"
AddCSLuaFile "sh_init.lua"
AddCSLuaFile "sh_gamemodes.lua"
AddCSLuaFile "sh_theme_sync.lua"
AddCSLuaFile "sh_player_extension.lua"
AddCSLuaFile "sh_item_delta.lua"
AddCSLuaFile "sh_accessory_base.lua"
AddCSLuaFile "sh_playermodel_base.lua"
AddCSLuaFile "vgui/DPointShopGivePoints.lua"
AddCSLuaFile "vgui/DPointShopInspector.lua"
AddCSLuaFile "vgui/DPointShopItem.lua"
AddCSLuaFile "vgui/DPointShopMenu.lua"
AddCSLuaFile "vgui/DPointShopPreview.lua"
AddCSLuaFile "vgui/DPointShopAdmin.lua"
AddCSLuaFile "vgui/DPointShopTheme.lua"
AddCSLuaFile "cl_framework.lua"
AddCSLuaFile "vgui/DPointShopAuthModule.lua"

local gmFiles = file.Find("pointshop/gamemodes/*.lua", "LUA")
for _, name in ipairs(gmFiles) do
	AddCSLuaFile("pointshop/gamemodes/" .. name)
end
