-- Unified persistent storage for player model customizations
-- Server-side: stores per-player, per-itemID settings (bodygroups, skin, colors)
-- itemID = item.ID (unique identifier), modelpath = item.Model (mdl file path)

if SERVER then
    util.AddNetworkString("PS_PlayerModelCustomization_Request")
    util.AddNetworkString("PS_PlayerModelCustomization_Update")
    util.AddNetworkString("PS_PlayerModelColor_Broadcast")
    
    -- Security: Rate limiting for legacy playermodel system
    local PS_PlayerModelRateLimits = {}
    local PLAYERMODEL_RATE_LIMIT = 0.5
    
    local function CheckPlayerModelRateLimit(ply)
        if not IsValid(ply) then return false end
        local steamid = ply:SteamID()
        local now = CurTime()
        if PS_PlayerModelRateLimits[steamid] and (now - PS_PlayerModelRateLimits[steamid]) < PLAYERMODEL_RATE_LIMIT then
            return false
        end
        PS_PlayerModelRateLimits[steamid] = now
        return true
    end
    
    hook.Add("PlayerDisconnected", "PS_CleanupPlayerModelRateLimits", function(ply)
        PS_PlayerModelRateLimits[ply:SteamID()] = nil
    end)
    
    -- Security: Sanitize playermodel data (legacy system protection)
    local function SanitizePlayerModelMods(mods)
        if not mods or type(mods) ~= "table" then return {} end
        local sanitized = {}
        
        if mods.skin then
            sanitized.skin = math.Clamp(math.Round(tonumber(mods.skin) or 0), 0, 255)
        end
        if mods.bodygroups and type(mods.bodygroups) == "table" then
            sanitized.bodygroups = {}
            local count = 0
            for k, v in pairs(mods.bodygroups) do
                if count >= 32 then break end
                local id = tonumber(k)
                local val = tonumber(v)
                if id and val and id >= 0 and id < 32 and val >= 0 and val < 16 then
                    sanitized.bodygroups[id] = math.floor(val)
                    count = count + 1
                end
            end
        end
        if mods.playercolor then
            -- Handle Vector format (normalized 0-1) - convert to RGB 0-255
            if type(mods.playercolor) == "Vector" or (type(mods.playercolor) == "table" and mods.playercolor.x) then
                local r = math.Clamp((mods.playercolor.x or 1) * 255, 0, 255)
                local g = math.Clamp((mods.playercolor.y or 1) * 255, 0, 255)
                local b = math.Clamp((mods.playercolor.z or 1) * 255, 0, 255)
                sanitized.playercolor = {math.floor(r), math.floor(g), math.floor(b)}
            -- Handle table format (RGB 0-255)
            elseif type(mods.playercolor) == "table" then
                sanitized.playercolor = {
                    math.Clamp(tonumber(mods.playercolor[1] or mods.playercolor.r) or 255, 0, 255),
                    math.Clamp(tonumber(mods.playercolor[2] or mods.playercolor.g) or 255, 0, 255),
                    math.Clamp(tonumber(mods.playercolor[3] or mods.playercolor.b) or 255, 0, 255)
                }
            end
        end
        
        return sanitized
    end

    -- Create SQL table (fresh structure, no migration)
    if not sql.TableExists("ps_playermodel_customization") then
        sql.Query([[CREATE TABLE ps_playermodel_customization (
            steamid TEXT NOT NULL,
            itemid TEXT NOT NULL,
            modelpath TEXT NOT NULL,
            mods TEXT NOT NULL,
            PRIMARY KEY (steamid, itemid)
        )]])
        if PS and PS.Config and PS.Config.Debug then
            print("[PS Playermodel] Created customization database")
        end
    end

    -- Get customization for player by itemID, returns {mods, modelpath}
    function PS_GetPlayerModelCustomization(ply, itemID)
        local steamid = ply:SteamID()
        
        -- 1. Check saved customization data
        local row = sql.QueryRow("SELECT modelpath, mods FROM ps_playermodel_customization WHERE steamid = " .. sql.SQLStr(steamid) .. " AND itemid = " .. sql.SQLStr(itemID))
        if row and row.mods then
            return util.JSONToTable(row.mods), row.modelpath
        end
        
        -- 2. Check for item defaults
        local ITEM = PS.Items and PS.Items[itemID]
        if ITEM then
            if ITEM.DefaultModifications then
                local defaults = table.Copy(ITEM.DefaultModifications)
                -- Normalize Vector playercolor to table format
                if defaults.playercolor and (type(defaults.playercolor) == "Vector" or (type(defaults.playercolor) == "table" and defaults.playercolor.x)) then
                    local pc = defaults.playercolor
                    defaults.playercolor = {
                        math.floor((pc.x or 1) * 255),
                        math.floor((pc.y or 1) * 255),
                        math.floor((pc.z or 1) * 255)
                    }
                end
                return defaults, ITEM.Model
            end
            
            -- 3. Fallback to zero values if no defaults defined
            return {
                skin = 0,
                bodygroups = {},
                playercolor = {255, 255, 255}
            }, ITEM.Model
        end
        
        return nil, nil
    end

    -- Set customization for player by itemID
    function PS_SetPlayerModelCustomization(ply, itemID, modelPath, mods)
        local steamid = ply:SteamID()
        local mods_json = util.TableToJSON(mods, true)
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS Playermodel] Saving customization for %s - itemID: %s", ply:Nick(), itemID))
            print("[PS Playermodel] Mods:", mods_json)
        end
        
        sql.Query("INSERT OR REPLACE INTO ps_playermodel_customization (steamid, itemid, modelpath, mods) VALUES (" 
            .. sql.SQLStr(steamid) .. ", " 
            .. sql.SQLStr(itemID) .. ", " 
            .. sql.SQLStr(modelPath) .. ", " 
            .. sql.SQLStr(mods_json) .. ")")
    end
    
    -- Apply customization to player
    local function ApplyPlayerModelToPlayer(ply, modelPath, mods, itemID)
        if not IsValid(ply) or not modelPath then return end
        
        ply:SetModel(modelPath)
        if mods then
            if mods.skin then ply:SetSkin(mods.skin) end
            if mods.bodygroups then
                for k, v in pairs(mods.bodygroups) do
                    ply:SetBodygroup(k, v)
                end
            end
            if mods.playercolor then
                local pc = mods.playercolor
                local r, g, b
                
                -- Handle Vector format (normalized 0-1) - convert to RGB 0-255
                if type(pc) == "Vector" or (type(pc) == "table" and pc.x) then
                    r = math.floor((pc.x or 1) * 255)
                    g = math.floor((pc.y or 1) * 255)
                    b = math.floor((pc.z or 1) * 255)
                -- Handle table format (RGB 0-255)
                else
                    r = (pc[1] or pc.r or 255)
                    g = (pc[2] or pc.g or 255)
                    b = (pc[3] or pc.b or 255)
                end
                
                -- Check if item uses color2 proxy
                local useColor2 = false
                if itemID and PS.Items and PS.Items[itemID] then
                    useColor2 = PS.Items[itemID].UseColor2Proxy or false
                end
                
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS COLOR DEBUG] ApplyPlayerModelToPlayer -> player=%s R=%d G=%d B=%d useColor2=%s itemID=%s", ply:Nick(), r, g, b, tostring(useColor2), tostring(itemID)))
                end
                if useColor2 then
                    -- Clear any leftover render modulation from a previously equipped modulation model
                    ply:SetColor(Color(255, 255, 255, 255))
                    if PS and PS.Config and PS.Config.Debug then
                        print(string.format("[PS COLOR DEBUG] Calling SetPlayerColor(%.3f, %.3f, %.3f)", r/255, g/255, b/255))
                    end
                    ply:SetPlayerColor(Vector(r/255, g/255, b/255))
                    ply:SetRenderMode(RENDERMODE_NORMAL)
                else
                    -- Use render color modulation for models without color2 proxy
                    if PS and PS.Config and PS.Config.Debug then
                        print(string.format("[PS COLOR DEBUG] Calling SetColor(%d, %d, %d)", r, g, b))
                    end
                    ply:SetColor(Color(r, g, b, 255))
                    ply:SetRenderMode(RENDERMODE_NORMAL)
                    -- Reset player color so it doesn't interfere
                    if PS and PS.Config and PS.Config.Debug then
                        print("[PS COLOR DEBUG] Resetting SetPlayerColor to white (was modulation path)")
                    end
                    ply:SetPlayerColor(Vector(1, 1, 1))
                end
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS COLOR DEBUG] After apply -> GetColor=%s GetPlayerColor=%s", tostring(ply:GetColor()), tostring(ply:GetPlayerColor())))
                end
                
                -- Store color for client-side rendering
                ply.PS_PlayerColor = Color(r, g, b, 255)
                ply.PS_UseColor2Proxy = useColor2
                
                -- Broadcast color to all clients
                net.Start("PS_PlayerModelColor_Broadcast")
                    net.WriteEntity(ply)
                    net.WriteUInt(r, 8)
                    net.WriteUInt(g, 8)
                    net.WriteUInt(b, 8)
                    net.WriteBool(useColor2)
                net.Broadcast()
            end
        end
    end

    -- Net receive: update customization
    net.Receive("PS_PlayerModelCustomization_Update", function(len, ply)
        if not IsValid(ply) then return end
        
        -- Security: Check packet size
        if len > 65536 then
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS SECURITY] Blocked oversized playermodel packet from %s", ply:Nick()))
            end
            return
        end
        
        -- Security: Check rate limit
        if not CheckPlayerModelRateLimit(ply) then
            return
        end
        
        local itemID = net.ReadString()
        local modelPath = net.ReadString()
        local rawMods = net.ReadTable()
        
        -- Security: Sanitize data
        local mods = SanitizePlayerModelMods(rawMods)
        
        -- Security: Check if player owns the item
        if not (ply.PS_Items and ply.PS_Items[itemID]) then
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS SECURITY] Player %s tried to customize playermodel they don't own: %s", 
                    ply:Nick(), itemID))
            end
            return
        end
        
        ApplyPlayerModelToPlayer(ply, modelPath, mods, itemID)
        PS_SetPlayerModelCustomization(ply, itemID, modelPath, mods)
    end)

    -- Net receive: client requests current customization for an itemID
    net.Receive("PS_PlayerModelCustomization_Request", function(len, ply)
        local itemID = net.ReadString()
        local mods, modelPath = PS_GetPlayerModelCustomization(ply, itemID)
        net.Start("PS_PlayerModelCustomization_Update")
        net.WriteString(itemID)
        net.WriteString(modelPath or "")
        net.WriteTable(mods or {})
        net.Send(ply)
    end)
end

if CLIENT then
    -- Receive playermodel color broadcast from server
    net.Receive("PS_PlayerModelColor_Broadcast", function()
        local ply = net.ReadEntity()
        local r = net.ReadUInt(8)
        local g = net.ReadUInt(8)
        local b = net.ReadUInt(8)
        local useColor2 = net.ReadBool()
        
        if not IsValid(ply) then return end
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS CLIENT] Received color broadcast for %s: R=%d G=%d B=%d UseColor2=%s", 
                ply:Nick(), r, g, b, tostring(useColor2)))
        end
        
        ply.PS_PlayerColor = Color(r, g, b, 255)
        ply.PS_UseColor2Proxy = useColor2
        
        -- Apply the color immediately
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS COLOR DEBUG] CLIENT broadcast receiver -> player=%s R=%d G=%d B=%d useColor2=%s", ply:Nick(), r, g, b, tostring(useColor2)))
        end
        if useColor2 then
            -- Clear any leftover render modulation from a previously equipped modulation model
            ply:SetColor(Color(255, 255, 255, 255))
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS COLOR DEBUG] CLIENT Calling SetPlayerColor(%.3f, %.3f, %.3f)", r/255, g/255, b/255))
            end
            ply:SetPlayerColor(Vector(r/255, g/255, b/255))
            ply:SetRenderMode(RENDERMODE_NORMAL)
        else
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS COLOR DEBUG] CLIENT Calling SetColor(%d, %d, %d)", r, g, b))
            end
            ply:SetColor(Color(r, g, b, 255))
            ply:SetRenderMode(RENDERMODE_NORMAL)
            -- Reset player color so it doesn't interfere
            if PS and PS.Config and PS.Config.Debug then
                print("[PS COLOR DEBUG] CLIENT Resetting SetPlayerColor to white (was modulation path)")
            end
            ply:SetPlayerColor(Vector(1, 1, 1))
        end
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS COLOR DEBUG] CLIENT After apply -> GetColor=%s GetPlayerColor=%s", tostring(ply:GetColor()), tostring(ply:GetPlayerColor())))
        end
    end)
    
    -- Send customization update to server
    function PS_SendPlayerModelCustomization(itemID, modelPath, mods)
        net.Start("PS_PlayerModelCustomization_Update")
        net.WriteString(itemID)
        net.WriteString(modelPath)
        net.WriteTable(mods)
        net.SendToServer()
    end
    
    -- Request server to apply customization
    function PS_RequestApplyPlayerModelCustomization(itemID, modelPath, mods)
        PS_SendPlayerModelCustomization(itemID, modelPath, mods)
    end
end
