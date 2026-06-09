-- Autorun loader: ensures accessory customization server module is included on server start
-- Also sends client files to clients

-- Send client autorun files
AddCSLuaFile("autorun/ps_client_accessory.lua")

-- Load server backend
include("pointshop/ps_backend_accessory.lua")
print("[ps_accessory_customization_autorun] loaded and included pointshop/ps_backend_accessory.lua")
