-- Unified Item Customization Backend
-- Net handlers, sanitization, and rate limiting for all item customization.
-- Storage is handled by ps_backend_storage.lua (PS_GetCustomization / PS_SetCustomization).

if SERVER then
    -- Unified customization messages
    util.AddNetworkString("PS_ItemCustomization_Update")
    util.AddNetworkString("PS_ItemCustomization_Request")
    util.AddNetworkString("PS_ItemCustomization_Closed")
    util.AddNetworkString("PS_ItemCustomization_PreviewUpdate")
    -- Accessory broadcast (consumed by ps_client_accessory.lua)
    util.AddNetworkString("PS_AccessoryCustomization_Update")
    -- Playermodel color broadcast (consumed by ps_backend_playermodel.lua client section → now inline)
    util.AddNetworkString("PS_PlayerModelColor_Broadcast")
    
    -- Rate limiting tracking
    local PS_CustomizationRateLimits = {}
    local RATE_LIMIT_DELAY = 0.5  -- seconds between customization updates per player
    local RATE_LIMIT_VIOLATIONS = {}
    local MAX_VIOLATIONS = 10  -- kick after this many violations
    
    -- Server-side sanitization function (mirrors client-side for security)
    -- Global so other server code (e.g. PS_BuyItem's initial-mods path) can reuse it.
    function PS_SanitizeCustomizationData(mods, itemType)
        if not mods or type(mods) ~= "table" then return {} end

        -- Upgrade legacy shapes before sanitizing. This addon is distributed, so a
        -- client running an older build can still send offsetX/axis/axisDeg — without
        -- this they'd be dropped by the sanitizer and the player would silently lose
        -- their positioning on save.
        if PS_NormalizeMods then mods = PS_NormalizeMods(mods) end

        local sanitized = {}
        
        if itemType == "accessory" then
            -- Sanitize accessory data
            if mods.scale then
                sanitized.scale = math.Clamp(tonumber(mods.scale) or 1, 0.1, 2)
            end
            
            if mods.offset and type(mods.offset) == "table" then
                sanitized.offset = {
                    math.Clamp(tonumber(mods.offset[1] or mods.offset.x) or 0, -30, 30),
                    math.Clamp(tonumber(mods.offset[2] or mods.offset.y) or 0, -30, 30),
                    math.Clamp(tonumber(mods.offset[3] or mods.offset.z) or 0, -30, 30)
                }
            end

            -- Legacy `rotation`, `axis` and `axisDeg` are deliberately not sanitized
            -- through: nothing reads them any more, so letting them past would just
            -- persist dead keys into new SQL rows.

            if mods.ang and type(mods.ang) == "table" then
                sanitized.ang = {
                    math.Clamp(tonumber(mods.ang[1]) or 0, -180, 180),
                    math.Clamp(tonumber(mods.ang[2]) or 0, -180, 180),
                    math.Clamp(tonumber(mods.ang[3]) or 0, -180, 180)
                }
            end
            
            if mods.color and type(mods.color) == "table" then
                sanitized.color = {
                    r = math.Clamp(tonumber(mods.color.r or mods.color[1]) or 255, 0, 255),
                    g = math.Clamp(tonumber(mods.color.g or mods.color[2]) or 255, 0, 255),
                    b = math.Clamp(tonumber(mods.color.b or mods.color[3]) or 255, 0, 255),
                    a = math.Clamp(tonumber(mods.color.a or mods.color[4]) or 255, 0, 255)
                }
            end

            -- Bone override: whitelist known ValveBiped bones only
            if mods.bone and type(mods.bone) == "string" then
                local validBones = {
                    ["ValveBiped.Bip01_Head1"]  = true,
                    ["ValveBiped.Bip01_Spine4"] = true,
                    ["ValveBiped.Bip01_Spine2"] = true,
                    ["ValveBiped.Bip01_Spine"]  = true,
                    ["ValveBiped.Bip01_Pelvis"] = true,
                    ["ValveBiped.Bip01_R_Hand"] = true,
                    ["ValveBiped.Bip01_L_Hand"] = true,
                    ["ValveBiped.Bip01_R_Forearm"] = true,
                    ["ValveBiped.Bip01_L_Forearm"] = true,
                    ["ValveBiped.Bip01_R_UpperArm"] = true,
                    ["ValveBiped.Bip01_L_UpperArm"] = true,
                    ["ValveBiped.Bip01_R_Foot"]  = true,
                    ["ValveBiped.Bip01_L_Foot"]  = true,
                }
                if validBones[mods.bone] then
                    sanitized.bone = mods.bone
                end
            end

        elseif itemType == "playermodel" then
            -- Sanitize playermodel data
            if mods.skin then
                sanitized.skin = math.Clamp(math.Round(tonumber(mods.skin) or 0), 0, 255)
            end
            
            if mods.bodygroups and type(mods.bodygroups) == "table" then
                sanitized.bodygroups = {}
                local count = 0
                for bgID, bgValue in pairs(mods.bodygroups) do
                    if count >= 32 then break end  -- Max 32 bodygroups
                    local id = tonumber(bgID)
                    local val = tonumber(bgValue)
                    if id and val and id >= 0 and id < 32 and val >= 0 and val < 16 then
                        sanitized.bodygroups[id] = math.floor(val)
                        count = count + 1
                    end
                end
            end
            
            if mods.playercolor and type(mods.playercolor) == "table" then
                sanitized.playercolor = {
                    math.Clamp(tonumber(mods.playercolor[1] or mods.playercolor.r) or 255, 0, 255),
                    math.Clamp(tonumber(mods.playercolor[2] or mods.playercolor.g) or 255, 0, 255),
                    math.Clamp(tonumber(mods.playercolor[3] or mods.playercolor.b) or 255, 0, 255)
                }
            end
        elseif itemType == "trail" then
            -- Sanitize trail data (color only)
            if mods.color and type(mods.color) == "table" then
                sanitized.color = {
                    r = math.Clamp(tonumber(mods.color.r or mods.color[1]) or 255, 0, 255),
                    g = math.Clamp(tonumber(mods.color.g or mods.color[2]) or 255, 0, 255),
                    b = math.Clamp(tonumber(mods.color.b or mods.color[3]) or 255, 0, 255),
                    a = math.Clamp(tonumber(mods.color.a or mods.color[4]) or 255, 0, 255)
                }
            end
        end
        
        return sanitized
    end
    
    -- Check if player owns the item
    local function PlayerOwnsItem(ply, itemID)
        if not IsValid(ply) or not itemID then return false end
        
        -- Check PS_Items table (PointShop ownership)
        if ply.PS_Items and ply.PS_Items[itemID] then
            return true
        end
        
        -- Check if item exists in global items table
        if PS and PS.Items and PS.Items[itemID] then
            local item = PS.Items[itemID]
            -- Allow customization for free items or admin-only items if player is admin
            if item.Price == 0 or (item.AdminOnly and ply:IsAdmin()) then
                return true
            end
        end
        
        return false
    end
    
    -- Check rate limit for player
    local function CheckRateLimit(ply)
        if not IsValid(ply) then return false end
        
        local steamid = ply:SteamID()
        local now = CurTime()
        
        -- Check last update time
        if PS_CustomizationRateLimits[steamid] then
            local timeSince = now - PS_CustomizationRateLimits[steamid]
            if timeSince < RATE_LIMIT_DELAY then
                -- Rate limit violation
                RATE_LIMIT_VIOLATIONS[steamid] = (RATE_LIMIT_VIOLATIONS[steamid] or 0) + 1
                
                if RATE_LIMIT_VIOLATIONS[steamid] >= MAX_VIOLATIONS then
                    print(string.format("[PS SECURITY] Kicking %s for customization spam (%d violations)", 
                        ply:Nick(), RATE_LIMIT_VIOLATIONS[steamid]))
                    ply:Kick("Excessive customization updates. Please don't spam.")
                end
                
                return false
            end
        end
        
        -- Update last update time
        PS_CustomizationRateLimits[steamid] = now
        return true
    end
    
    -- Clean up rate limit data when player disconnects
    hook.Add("PlayerDisconnected", "PS_CleanupRateLimits", function(ply)
        local steamid = ply:SteamID()
        PS_CustomizationRateLimits[steamid] = nil
        RATE_LIMIT_VIOLATIONS[steamid] = nil
    end)
    
    -- ============================================================================
    -- SERVER WRAPPER FUNCTIONS
    -- ============================================================================
    
    -- ============================================================================
    -- UNIFIED NETWORK RECEIVERS
    -- ============================================================================

    -- Receive: Request customization data
    net.Receive("PS_ItemCustomization_Request", function(len, ply)
        if not IsValid(ply) then return end

        -- Light rate limit for requests (less strict than updates)
        local steamid = ply:SteamID()
        local now = CurTime()
        if PS_CustomizationRateLimits[steamid .. "_request"] and
           (now - PS_CustomizationRateLimits[steamid .. "_request"]) < 0.1 then
            return
        end
        PS_CustomizationRateLimits[steamid .. "_request"] = now

        local itemID   = net.ReadString()
        local itemType = net.ReadString()

        local mods = PS_GetCustomization and PS_GetCustomization(ply, itemID) or {}

        net.Start("PS_ItemCustomization_Update")
            net.WriteString(itemID)
            net.WriteString(itemType)
            net.WriteTable(mods or {})
        net.Send(ply)

        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS UNIFIED] Sent customization to %s: type=%s id=%s",
                ply:Nick(), itemType, itemID))
        end
    end)

    -- Receive: Apply customization
    net.Receive("PS_ItemCustomization_Update", function(len, ply)
        if not IsValid(ply) then return end

        if len > 65536 then
            print(string.format("[PS SECURITY] Blocked oversized customization packet from %s (%d bytes)",
                ply:Nick(), len))
            return
        end

        if not CheckRateLimit(ply) then
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS SECURITY] Rate limited customization from %s", ply:Nick()))
            end
            return
        end

        local itemID   = net.ReadString()
        local itemType = net.ReadString()
        local rawMods  = net.ReadTable()

        if itemType ~= "accessory" and itemType ~= "playermodel" and itemType ~= "trail" then
            print(string.format("[PS SECURITY] Invalid item type from %s: %s", ply:Nick(), tostring(itemType)))
            return
        end

        if not PlayerOwnsItem(ply, itemID) then
            print(string.format("[PS SECURITY] Player %s tried to customize item they don't own: %s",
                ply:Nick(), itemID))
            return
        end

        local mods = PS_SanitizeCustomizationData(rawMods, itemType)

        if next(rawMods) ~= nil and next(mods) == nil then
            print(string.format("[PS SECURITY] All customization data was invalid from %s", ply:Nick()))
            return
        end

        if itemType == "accessory" then
            PS_SetCustomization(ply, itemID, mods)

            if ply.PS_Items and ply.PS_Items[itemID] then
                ply.PS_Items[itemID].Modifiers = mods
                if PS and PS.SavePlayerItem then
                    pcall(function() PS:SavePlayerItem(ply, itemID, ply.PS_Items[itemID]) end)
                end
            end

            -- Broadcast with itemID as key (client table is now keyed by itemID)
            net.Start("PS_AccessoryCustomization_Update")
                net.WriteEntity(ply)
                net.WriteString(itemID)
                net.WriteTable(mods)
            net.Broadcast()

            if PS and PS.Notify then PS:Notify(ply, "Accessory customization saved and applied.") end

        elseif itemType == "playermodel" then
            PS_SetCustomization(ply, itemID, mods)

            ply:SetModel(ply:GetModel())
            if mods.skin then ply:SetSkin(mods.skin) end
            if mods.bodygroups then
                for k, v in pairs(mods.bodygroups) do
                    ply:SetBodygroup(tonumber(k) or k, tonumber(v) or v)
                end
            end

            if mods.playercolor then
                local pc = mods.playercolor
                local r, g, b
                if type(pc) == "Vector" or (type(pc) == "table" and pc.x) then
                    r = math.floor((pc.x or 1) * 255)
                    g = math.floor((pc.y or 1) * 255)
                    b = math.floor((pc.z or 1) * 255)
                else
                    r = pc[1] or pc.r or 255
                    g = pc[2] or pc.g or 255
                    b = pc[3] or pc.b or 255
                end

                local useColor2 = PS.Items and PS.Items[itemID] and PS.Items[itemID].UseColor2Proxy or false
                if useColor2 then
                    ply:SetPlayerColor(Vector(r/255, g/255, b/255))
                    ply:SetColor(Color(255, 255, 255, 255))
                else
                    ply:SetColor(Color(r, g, b, 255))
                    ply:SetPlayerColor(Vector(1, 1, 1))
                end
                ply:SetRenderMode(RENDERMODE_NORMAL)
                ply.PS_PlayerColor   = Color(r, g, b, 255)
                ply.PS_UseColor2Proxy = useColor2

                net.Start("PS_PlayerModelColor_Broadcast")
                    net.WriteEntity(ply)
                    net.WriteUInt(r, 8)
                    net.WriteUInt(g, 8)
                    net.WriteUInt(b, 8)
                    net.WriteBool(useColor2)
                net.Broadcast()
            end

            if PS and PS.Notify then PS:Notify(ply, "Player model customization saved.") end

        elseif itemType == "trail" then
            -- PS_ModifyItem calls OnModify and persists via the provider
            if ply.PS_Items and ply.PS_Items[itemID] then
                ply:PS_ModifyItem(itemID, mods)
            end
            if PS and PS.Notify then PS:Notify(ply, "Trail color saved.") end
        end

        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS UNIFIED] Saved customization from %s: type=%s id=%s",
                ply:Nick(), itemType, itemID))
            PrintTable(mods)
        end
    end)
    
    -- Receive: Preview update (for immediate visual feedback)
    net.Receive("PS_ItemCustomization_PreviewUpdate", function(len, ply)
        if not IsValid(ply) then return end

        -- Size limit for preview updates (1KB)
        if len > 1024 then return end

        local itemType = net.ReadString()
        local updateType = net.ReadString() -- "bodygroup", "skin", "playercolor"
        local itemID = net.ReadString()

        -- Ownership check: must own the item being previewed
        if not PlayerOwnsItem(ply, itemID) then return end

        -- Team gate: same check applied on the save path
        if PS and PS.Items and PS.Items[itemID] then
            if not PS:CanEquipForTeam(ply, PS.Items[itemID]) then return end
        end

        -- Validate and sanitize preview updates
        if updateType == "bodygroup" then
            local bgID = net.ReadUInt(8)
            local bgValue = net.ReadUInt(8)
            -- Sanitize bodygroup values
            if bgID < 32 and bgValue < 16 then
                ply:SetBodygroup(bgID, bgValue)
            end
        elseif updateType == "skin" then
            local skinValue = net.ReadUInt(8)
            -- Sanitize skin value
            if skinValue <= 255 then
                ply:SetSkin(skinValue)
            end
        elseif updateType == "playercolor" then
            local r = net.ReadUInt(8)
            local g = net.ReadUInt(8)
            local b = net.ReadUInt(8)
            -- Values are already 0-255 from UInt(8), safe to apply
            ply:SetPlayerColor(Vector(r / 255, g / 255, b / 255))
        end
    end)
    
    -- Receive: Panel closed
    net.Receive("PS_ItemCustomization_Closed", function(len, ply)
        local itemType = net.ReadString()
        -- Panel closed - customizations already applied, no action needed
    end)
end

if CLIENT then
    -- ============================================================================
    -- CLIENT WRAPPER FUNCTIONS
    -- ============================================================================
    
    -- Request customization data from server
    function PS_RequestItemCustomization(itemID, itemType)
        if not itemID or not itemType then return end
        
        net.Start("PS_ItemCustomization_Request")
        net.WriteString(itemID)
        net.WriteString(itemType)
        net.SendToServer()
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS UNIFIED CLIENT] Requested customization: type=%s id=%s", 
                itemType, itemID))
        end
    end
    
    -- Throttle tracker for preview updates (prevents spam when dragging sliders)
    local previewUpdateThrottle = {}

    -- Send immediate preview update to server for visual feedback
    -- itemID is required so the server can verify ownership and team restrictions
    function PS_SendPreviewUpdate(itemType, itemID, updateType, ...)
        if not itemType or not itemID or not updateType then return end

        -- Throttle: only send once per 100ms per update type
        local throttleKey = itemType .. "_" .. updateType
        local now = RealTime()
        if previewUpdateThrottle[throttleKey] and (now - previewUpdateThrottle[throttleKey]) < 0.1 then
            return
        end
        previewUpdateThrottle[throttleKey] = now

        net.Start("PS_ItemCustomization_PreviewUpdate")
        net.WriteString(itemType)
        net.WriteString(updateType)
        net.WriteString(itemID)

        if updateType == "bodygroup" then
            local bgID, bgValue = ...
            net.WriteUInt(bgID, 8)
            net.WriteUInt(bgValue, 8)
        elseif updateType == "skin" then
            local skinValue = ...
            net.WriteUInt(skinValue, 8)
        elseif updateType == "playercolor" then
            local r, g, b = ...
            net.WriteUInt(r, 8)
            net.WriteUInt(g, 8)
            net.WriteUInt(b, 8)
        end

        net.SendToServer()
    end
    
    -- Apply customization (send to server)
    function PS_ApplyItemCustomization(itemID, itemType, mods)
        if not itemID or not itemType or not mods then return end
        
        net.Start("PS_ItemCustomization_Update")
        net.WriteString(itemID)
        net.WriteString(itemType)
        net.WriteTable(mods)
        net.SendToServer()
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS UNIFIED CLIENT] Applying customization: type=%s id=%s", 
                itemType, itemID))
            PrintTable(mods)
        end
    end
    
    -- Notify server that panel closed
    function PS_NotifyItemCustomizationClosed(itemType)
        if not itemType then return end
        
        net.Start("PS_ItemCustomization_Closed")
        net.WriteString(itemType)
        net.SendToServer()
    end
    
    -- ============================================================================
    -- UNIFIED NETWORK RECEIVERS
    -- ============================================================================
    
    -- NOTE: Client-side net.Receive for PS_ItemCustomization_Update is handled by
    -- DPointShopItemCustomization.lua to load saved data into the panel UI.
    -- Previously had HolsterAndReequip logic here, but removed since customizations
    -- now apply immediately without re-equipping.
end

if PS and PS.Config and PS.Config.Debug then
    print("[PointShop] Unified customization backend loaded")
end
