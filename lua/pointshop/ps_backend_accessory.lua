if SERVER then
    if PS and PS.Config and PS.Config.Debug then
        print("[ps_backend_accessory] loaded")
    end
    util.AddNetworkString("PS_AccessoryCustomization_Update")
    util.AddNetworkString("PS_AccessoryCustomization_Request")
    util.AddNetworkString("PS_AccessoryCustomization_PING")
    util.AddNetworkString("PS_AccessoryCustomization_PONG")
    util.AddNetworkString("PS_AccessoryCustomization_Closed")
    
    -- Security: Rate limiting for legacy accessory system
    local PS_AccessoryRateLimits = {}
    local ACCESSORY_RATE_LIMIT = 0.5
    
    local function CheckAccessoryRateLimit(ply)
        if not IsValid(ply) then return false end
        local steamid = ply:SteamID()
        local now = CurTime()
        if PS_AccessoryRateLimits[steamid] and (now - PS_AccessoryRateLimits[steamid]) < ACCESSORY_RATE_LIMIT then
            return false
        end
        PS_AccessoryRateLimits[steamid] = now
        return true
    end
    
    hook.Add("PlayerDisconnected", "PS_CleanupAccessoryRateLimits", function(ply)
        PS_AccessoryRateLimits[ply:SteamID()] = nil
    end)
    
    -- Security: Sanitize accessory data (legacy system protection)
    local function SanitizeAccessoryMods(mods)
        if not mods or type(mods) ~= "table" then return {} end
        local sanitized = {}
        
        if mods.scale then
            sanitized.scale = math.Clamp(tonumber(mods.scale) or 1, 0.1, 2)
        end
        if mods.rotation then
            sanitized.rotation = math.Clamp(tonumber(mods.rotation) or 0, 0, 360)
        end
        if mods.offset and type(mods.offset) == "table" then
            sanitized.offset = {
                math.Clamp(tonumber(mods.offset[1] or mods.offset.x) or 0, -30, 30),
                math.Clamp(tonumber(mods.offset[2] or mods.offset.y) or 0, -30, 30),
                math.Clamp(tonumber(mods.offset[3] or mods.offset.z) or 0, -30, 30)
            }
        end
        if mods.axis and type(mods.axis) == "string" then
            local validAxes = {Right = true, Up = true, Forward = true}
            sanitized.axis = validAxes[mods.axis] and mods.axis or "Right"
        end
        if mods.axisDeg then
            sanitized.axisDeg = math.Clamp(tonumber(mods.axisDeg) or -90, -180, 180)
        end
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
        if mods.playercolor and type(mods.playercolor) == "table" then
            sanitized.playercolor = {
                math.Clamp(tonumber(mods.playercolor[1] or mods.playercolor.r) or 255, 0, 255),
                math.Clamp(tonumber(mods.playercolor[2] or mods.playercolor.g) or 255, 0, 255),
                math.Clamp(tonumber(mods.playercolor[3] or mods.playercolor.b) or 255, 0, 255)
            }
        end
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
        
        return sanitized
    end

    -- Create SQL table if it doesn't exist
    if not sql.TableExists("ps_accessory_customization") then
        sql.Query([[CREATE TABLE ps_accessory_customization (
            steamid TEXT NOT NULL,
            model TEXT NOT NULL,
            mods TEXT NOT NULL,
            PRIMARY KEY (steamid, model)
        )]])
    end
    
    -- Helper: Resolve item from ID or model path (consolidates duplicate logic)
    local function ResolveItem(itemID)
        if PS and PS.Items and PS.Items[itemID] then
            return PS.Items[itemID]
        end
        -- Try to resolve by model path
        local tryModel = (PS_GetModelPathForItem and PS_GetModelPathForItem(itemID)) or itemID
        if PS and PS.Items then
            for k, it in pairs(PS.Items) do
                if it and it.Model and tostring(it.Model) == tostring(tryModel) then
                    return it
                end
            end
        end
        return nil
    end

    function PS_GetAccessoryCustomization(ply, model)
        if not IsValid(ply) then return nil end
        local steamid = ply:SteamID()
        
        -- 1. Check saved customization data
        local row = sql.QueryRow("SELECT mods FROM ps_accessory_customization WHERE steamid = " .. sql.SQLStr(steamid) .. " AND model = " .. sql.SQLStr(model))
        if row and row.mods and row.mods ~= "" then
            local ok, tbl = pcall(util.JSONToTable, row.mods)
            if ok and tbl then
                return tbl
            end
        end
        
        -- 2. Check for item defaults
        for _, ITEM in pairs(PS.Items or {}) do
            if ITEM.Model == model then
                if ITEM.DefaultModifications then
                    return table.Copy(ITEM.DefaultModifications)
                end
                
                -- 3. Fallback to zero values if no defaults defined
                return {
                    scale = 1,
                    offsetX = 0,
                    offsetY = 0,
                    offsetZ = 0,
                    rotation = 0,
                    axis = "Right",
                    axisDeg = -90,
                    color = Color(255, 255, 255, 255)
                }
            end
        end
        
        return nil
    end

    function PS_SetAccessoryCustomization(ply, model, mods)
        if not IsValid(ply) then return end
        -- Do not persist nil/empty modification tables; they overwrite valid data with empty values.
        if mods == nil or (type(mods) == "table" and next(mods) == nil) then
            return
        end
        local steamid = ply:SteamID()
        local mods_json = util.TableToJSON(mods or {})
        
        -- Use INSERT OR REPLACE for single-query UPSERT (more efficient than SELECT+UPDATE/INSERT)
        sql.Query("INSERT OR REPLACE INTO ps_accessory_customization (steamid, model, mods) VALUES (" .. sql.SQLStr(steamid) .. ", " .. sql.SQLStr(model) .. ", " .. sql.SQLStr(mods_json) .. ")")
        local err = sql.LastError()
        if err and err ~= "" then
            if PS and PS.Config and PS.Config.Debug then
                print("[PS SQL ERROR] INSERT OR REPLACE:", err)
            end
        end
    end

    net.Receive("PS_AccessoryCustomization_Update", function(len, ply)
        if not IsValid(ply) then return end
        
        -- Security: Check packet size
        if len > 65536 then
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS SECURITY] Blocked oversized accessory packet from %s", ply:Nick()))
            end
            return
        end
        
        -- Security: Check rate limit
        if not CheckAccessoryRateLimit(ply) then
            return
        end
        
        local itemID = net.ReadString()
        local rawMods = net.ReadTable()
        if not itemID then return end
        
        -- Security: Sanitize data
        local mods = SanitizeAccessoryMods(rawMods)
        
        -- Security: Check if player owns the item
        if not (ply.PS_Items and ply.PS_Items[itemID]) then
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS SECURITY] Player %s tried to customize accessory they don't own: %s", 
                    ply:Nick(), itemID))
            end
            return
        end

        local modelPath = (PS_GetModelPathForItem and PS_GetModelPathForItem(itemID)) or itemID

        PS_SetAccessoryCustomization(ply, modelPath, mods)

        -- Also persist the modifiers into the player's PS_Items table so PointShop's
        -- provider persistence picks them up and they are present on spawn/equip.
        if ply.PS_Items and ply.PS_Items[itemID] then
            ply.PS_Items[itemID].Modifiers = mods or {}
            if PS and PS.SavePlayerItem then
                pcall(function()
                    PS:SavePlayerItem(ply, itemID, ply.PS_Items[itemID])
                end)
            end
        end

        -- Apply server-side visual changes so they replicate to other clients immediately
        if mods then
            -- playercolor may be provided as {r,g,b[,a]} or {r=..,g=..,b=..}
            if mods.playercolor then
                local pc = mods.playercolor
                local r = pc[1] or pc.r or 255
                local g = pc[2] or pc.g or 255
                local b = pc[3] or pc.b or 255
                ply:SetPlayerColor(Vector((r or 255)/255, (g or 255)/255, (b or 255)/255))
                ply.PS_PlayerColor = Color(r or 255, g or 255, b or 255, (pc[4] or pc.a or 255))
            end
            if mods.skin then
                ply:SetSkin(mods.skin)
            end
            if mods.bodygroups then
                for k, v in pairs(mods.bodygroups) do
                    ply:SetBodygroup(tonumber(k) or k, v)
                end
            end
        end

        -- Broadcast to ALL clients so everyone sees the update immediately
        net.Start("PS_AccessoryCustomization_Update")
            net.WriteEntity(ply)
            net.WriteString(modelPath)
            net.WriteTable(mods)
        net.Broadcast()

        -- Notify the player customization was saved
        pcall(function()
            if IsValid(ply) and ply.PS_Notify then
                ply:PS_Notify('Customization saved and applied.')
            end
        end)
    end)

    net.Receive("PS_AccessoryCustomization_Request", function(len, ply)
        local itemID = net.ReadString()
        if not IsValid(ply) or not itemID then return end
        local modelPath = (PS_GetModelPathForItem and PS_GetModelPathForItem(itemID)) or itemID
        local mods = PS_GetAccessoryCustomization(ply, modelPath) or {}
        net.Start("PS_AccessoryCustomization_Update")
            net.WriteEntity(ply)
            net.WriteString(itemID)
            net.WriteTable(mods)
        net.Send(ply)
    end)

    net.Receive("PS_AccessoryCustomization_Closed", function(len, ply)
        -- Panel closed - no action needed, customizations already applied
    end)

    -- Send all saved accessory customizations to player on join
    hook.Add("PlayerInitialSpawn", "PS_SendAccessoryCustomizationsOnJoin", function(ply)
        if not IsValid(ply) then return end
        
        -- Send joining player's own customizations
        local steamid = ply:SteamID()
        local rows = sql.Query("SELECT model, mods FROM ps_accessory_customization WHERE steamid = " .. sql.SQLStr(steamid))
        if rows then
            for _, row in ipairs(rows) do
                if row and row.model and row.mods then
                    local ok, mods = pcall(util.JSONToTable, row.mods)
                    if ok and mods then
                        net.Start("PS_AccessoryCustomization_Update")
                            net.WriteEntity(ply)
                            net.WriteString(row.model)
                            net.WriteTable(mods)
                        net.Send(ply)
                    end
                end
            end
        end
        
        -- Send all OTHER players' equipped accessories with customizations to the joining player
        -- (fixes late-joiner bug where they don't see existing players' customizations)
        timer.Simple(0.5, function()
            if not IsValid(ply) then return end
            for _, otherPly in ipairs(player.GetAll()) do
                if otherPly == ply or not IsValid(otherPly) then continue end
                if not otherPly.PS_Items then continue end
                
                for itemID, itemData in pairs(otherPly.PS_Items) do
                    if not itemData.Equipped then continue end
                    if not PS.Items[itemID] then continue end
                    
                    local ITEM = PS.Items[itemID]
                    if not ITEM.Model then continue end
                    
                    -- Get customizations for this accessory
                    local mods = PS_GetAccessoryCustomization(otherPly, ITEM.Model)
                    if mods and next(mods) then
                        net.Start("PS_AccessoryCustomization_Update")
                            net.WriteEntity(otherPly)
                            net.WriteString(ITEM.Model)
                            net.WriteTable(mods)
                        net.Send(ply)
                    end
                end
            end
        end)
    end)

    -- One-shot server console command to dump accessory customization SQL rows
    concommand.Add("ps_dump_accessory_sql", function(ply, cmd, args)
        if IsValid(ply) then
            print("[ps_dump_accessory_sql] This command must be run from the server console.")
            return
        end
        local steamid = args and args[1] or nil
        if not steamid or steamid == "all" then
            local rows = sql.Query("SELECT steamid, model, mods FROM ps_accessory_customization")
            if not rows then
                print("[PS SQL] No accessory customization rows found.")
                return
            end
            for _, row in ipairs(rows) do
                print(string.format("[PS SQL] steamid=%s model=%s", tostring(row.steamid), tostring(row.model)))
                if row.mods and row.mods ~= "" then
                    local ok, tbl = pcall(util.JSONToTable, row.mods)
                    if ok and tbl then
                        PrintTable(tbl)
                    else
                        print("[PS SQL] Failed to parse mods JSON for", row.model)
                    end
                end
            end
        else
            local rows = sql.Query("SELECT model, mods FROM ps_accessory_customization WHERE steamid = " .. sql.SQLStr(steamid))
            if not rows then
                print("[PS SQL] No rows for steamid", steamid)
                return
            end
            for _, row in ipairs(rows) do
                print(string.format("[PS SQL] model=%s", tostring(row.model)))
                if row.mods and row.mods ~= "" then
                    local ok, tbl = pcall(util.JSONToTable, row.mods)
                    if ok and tbl then
                        PrintTable(tbl)
                    else
                        print("[PS SQL] Failed to parse mods JSON for", row.model)
                    end
                end
            end
        end
    end)

    -- Simple server-side health check: prints status and row count for a steamid (or all)
    concommand.Add("ps_check_accessory", function(ply, cmd, args)
        if IsValid(ply) then
            print("[ps_check_accessory] This command must be run from the server console.")
            return
        end
        local steamid = args and args[1] or nil
        if not steamid or steamid == "all" then
            local rows = sql.Query("SELECT steamid, model, mods FROM ps_accessory_customization")
            if not rows then
                print("[ps_check_accessory] No accessory customization rows found.")
                return
            end
            print(string.format("[ps_check_accessory] Found %d rows." , #rows))
            return
        else
            local rows = sql.Query("SELECT model, mods FROM ps_accessory_customization WHERE steamid = " .. sql.SQLStr(steamid))
            if not rows then
                print("[ps_check_accessory] No rows for steamid", steamid)
                return
            end
            print(string.format("[ps_check_accessory] steamid=%s rows=%d", tostring(steamid), #rows))
            return
        end
    end)

    -- Ping handler: client can send a PING and server will reply with basic status
    net.Receive("PS_AccessoryCustomization_PING", function(len, ply)
        if not IsValid(ply) then return end
        local steamid = ply:SteamID()
        local rows = sql.Query("SELECT model, mods FROM ps_accessory_customization WHERE steamid = " .. sql.SQLStr(steamid))
        local count = 0
        if rows then count = #rows end
        net.Start("PS_AccessoryCustomization_PONG")
            net.WriteInt(count, 16)
            net.WriteString(tostring(sql.LastError() or ""))
        net.Send(ply)
    end)
end
