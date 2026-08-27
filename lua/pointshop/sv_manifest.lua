--[[
	pointshop/sv_manifest.lua
	basic assets required on the client.
]]--

AddCSLuaFile "cl_init.lua"
AddCSLuaFile "cl_player_extension.lua"
AddCSLuaFile "cl_theme.lua"
AddCSLuaFile "cl_theme_classic.lua"
AddCSLuaFile "cl_theme_responsive.lua"
AddCSLuaFile "cl_ui.lua"
AddCSLuaFile "cl_tune.lua"
AddCSLuaFile "sh_config.lua"
AddCSLuaFile "sh_init.lua"
AddCSLuaFile "sh_gamemodes.lua"
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

-- Every gamemode profile, not just this server's.
--
-- LoadGamemodeProfile does its own AddCSLuaFile for the active one, which is correct but
-- happens during PS:Initialize -- and the client runs its own PS:Initialize and asks
-- file.Exists for the profile. If the transfer has not landed by then the client silently
-- gets no profile and falls back to "this gamemode gates by team", while the server has
-- the profile and does not. The two realms then disagree about which items are equippable,
-- and the client shows a category the server will refuse.
--
-- Sending all of them from the manifest removes the race: they are a few hundred bytes
-- each, and a profile for a gamemode this server is not running is inert.
local gmFiles = file.Find("pointshop/gamemodes/*.lua", "LUA")
for _, name in ipairs(gmFiles) do
	AddCSLuaFile("pointshop/gamemodes/" .. name)
end
