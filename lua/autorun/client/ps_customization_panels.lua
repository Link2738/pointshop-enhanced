-- Client-side customization panel loader
-- Must load after PS is initialized

if CLIENT then
    include("pointshop/ps_item_defaults.lua")
    include("pointshop/ps_removal_queue.lua")
    include("vgui/DPointShopCustomPanels.lua")
    include("vgui/DPointShopItemCustomization.lua")
    include("vgui/DPointShopOwnerDefaults.lua")
    
    print("[PointShop] Customization panels loaded")
end
