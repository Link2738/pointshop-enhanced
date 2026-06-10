-- Client-side customization panel loader
-- Must load after PS is initialized

if CLIENT then
    include("vgui/DPointShopCustomPanels.lua")
    include("vgui/DPointShopItemCustomization.lua")
    
    print("[PointShop] Customization panels loaded")
end
