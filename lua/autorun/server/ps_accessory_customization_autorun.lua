-- Autorun loader: ensures unified customization storage is loaded at server start.
-- Also sends the client-side accessory net receiver to clients.

AddCSLuaFile("autorun/ps_client_accessory.lua")
include("pointshop/ps_backend_storage.lua")
AddCSLuaFile("pointshop/ps_item_defaults.lua")
include("pointshop/ps_item_defaults.lua")
