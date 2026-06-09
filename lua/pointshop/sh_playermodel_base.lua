if SERVER then AddCSLuaFile() end

local BASE = {}

function BASE:ApplyModelSettings(ply, modifications)
    ply:SetModel(self.Model)
    if modifications and modifications.skin then
        ply:SetSkin(modifications.skin)
    end
    if modifications and modifications.bodygroups then
        for k, v in pairs(modifications.bodygroups) do
            ply:SetBodygroup(k, v)
        end
    end
    if modifications and modifications.playercolor then
        local c = modifications.playercolor
        local r, g, b
        
        -- Handle Vector format (normalized 0-1) - convert to RGB 0-255
        if type(c) == "Vector" or (type(c) == "table" and c.x) then
            r = math.floor((c.x or 1) * 255)
            g = math.floor((c.y or 1) * 255)
            b = math.floor((c.z or 1) * 255)
        -- Handle table format (RGB 0-255)
        else
            r = (c[1] or 255)
            g = (c[2] or 255)
            b = (c[3] or 255)
        end
        
        if SERVER and PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS Playermodel] Applying color to %s: R=%d G=%d B=%d, UseColor2Proxy=%s", 
                ply:Nick(), r, g, b, tostring(self.UseColor2Proxy)))
        end
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS COLOR DEBUG] BASE:ApplyModelSettings -> player=%s R=%d G=%d B=%d UseColor2Proxy=%s model=%s", ply:Nick(), r, g, b, tostring(self.UseColor2Proxy), tostring(self.Model)))
        end
        if self.UseColor2Proxy then
            -- Clear any leftover render modulation from a previously equipped modulation model
            ply:SetColor(Color(255, 255, 255, 255))
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS COLOR DEBUG] BASE Calling SetPlayerColor(%.3f, %.3f, %.3f)", r/255, g/255, b/255))
            end
            ply:SetPlayerColor(Vector(r/255, g/255, b/255))
            ply:SetRenderMode(RENDERMODE_NORMAL)
        else
            -- Use render color modulation for models without color2 proxy
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS COLOR DEBUG] BASE Calling SetColor(%d, %d, %d)", r, g, b))
            end
            ply:SetColor(Color(r, g, b, 255))
            ply:SetRenderMode(RENDERMODE_NORMAL)
            -- Reset player color so it doesn't interfere
            if PS and PS.Config and PS.Config.Debug then
                print("[PS COLOR DEBUG] BASE Resetting SetPlayerColor to white (was modulation path)")
            end
            ply:SetPlayerColor(Vector(1, 1, 1))
        end
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS COLOR DEBUG] BASE After apply -> GetColor=%s GetPlayerColor=%s", tostring(ply:GetColor()), tostring(ply:GetPlayerColor())))
        end
        
        -- Store and broadcast color
        if SERVER then
            ply.PS_PlayerColor = Color(r, g, b, 255)
            ply.PS_UseColor2Proxy = self.UseColor2Proxy or false
            
            -- Broadcast color to all clients
            net.Start("PS_PlayerModelColor_Broadcast")
                net.WriteEntity(ply)
                net.WriteUInt(r, 8)
                net.WriteUInt(g, 8)
                net.WriteUInt(b, 8)
                net.WriteBool(self.UseColor2Proxy or false)
            net.Broadcast()
        end
    end
end

function BASE:OnEquip(ply, modifications)
    if not ply._OldModel then
        ply._OldModel = ply:GetModel()
    end
    
    -- Track active PointShop playermodel so gamemode ModelFix allows it
    ply._PS_ActivePlayerModel = self.Model
    
    local itemID = self.ID or self.Model
    local modelPath = self.Model
    
    if SERVER then
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS Playermodel] OnEquip for %s - itemID: %s, model: %s", ply:Nick(), itemID, modelPath))
        end
        
        local custom, savedModelPath = PS_GetPlayerModelCustomization(ply, itemID)
        modifications = custom or modifications or {}
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS Playermodel] Loaded mods: %s", util.TableToJSON(modifications or {})))
        end
        
        PS_SetPlayerModelCustomization(ply, itemID, modelPath, modifications)
        self:ApplyModelSettings(ply, modifications)
    end
end

function BASE:OnHolster(ply)
    ply._PS_ActivePlayerModel = nil  -- Clear PointShop model tracking
    if ply._OldModel then
        ply:SetModel(ply._OldModel)
    end
    -- Reset all color/bodygroup state so the default model is clean
    ply:SetColor(Color(255, 255, 255, 255))
    ply:SetPlayerColor(Vector(1, 1, 1))
    ply:SetRenderMode(RENDERMODE_NORMAL)
    -- Reset all bodygroups to 0
    for i = 0, ply:GetNumBodyGroups() - 1 do
        ply:SetBodygroup(i, 0)
    end
    ply:SetSkin(0)
    -- Broadcast the reset to all clients
    if SERVER then
        ply.PS_PlayerColor = Color(255, 255, 255, 255)
        ply.PS_UseColor2Proxy = false
        net.Start("PS_PlayerModelColor_Broadcast")
            net.WriteEntity(ply)
            net.WriteUInt(255, 8)
            net.WriteUInt(255, 8)
            net.WriteUInt(255, 8)
            net.WriteBool(false)
        net.Broadcast()
    end
end

function BASE:OnModify(ply, modifications)
    if not self.Bodygroups then return end
    
    local itemID = self.ID or self.Model
    local modelPath = self.Model
    
    if SERVER then
        local custom, savedModelPath = PS_GetPlayerModelCustomization(ply, itemID)
        modifications = custom or modifications or {}
        PS_SetPlayerModelCustomization(ply, itemID, modelPath, modifications)
        self:ApplyModelSettings(ply, modifications)
    end
end

if CLIENT then
    function BASE:Modify(ply, modifications)
        local panel = vgui.Create("PSItemCustomizationPanel")
        panel:SetItem(self)  -- Pass entire item so panel can detect TYPE and load saved data
        if PS and PS.ToggleMenu then PS:ToggleMenu() end
    end
end

return BASE
