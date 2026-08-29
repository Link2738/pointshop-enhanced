if SERVER then 
	-- Send client files
	AddCSLuaFile()
	AddCSLuaFile("autorun/ps_client_accessory.lua")
	AddCSLuaFile("autorun/ps_backend_unified.lua")
	AddCSLuaFile("autorun/client/ps_customization_panels.lua")
	AddCSLuaFile("vgui/DPointShopItemCustomization.lua")
	
	-- Load server files
	include("pointshop/sv_init.lua")
	print("[PointShop] Server initializing...")
	PS:Initialize()
	print("[PointShop] Server initialized. Loaded " .. table.Count(PS.Items) .. " items in " .. table.Count(PS.Categories) .. " categories.")
end

if CLIENT then 
	include("pointshop/cl_init.lua")
	print("[PointShop] Client initializing...")
	PS:Initialize()
	print("[PointShop] Client initialized. " .. table.Count(PS.Items) .. " items available.")
end




