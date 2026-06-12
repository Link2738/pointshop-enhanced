-- Unified customization storage backend.
-- Single SQL table keyed by (steamid, item_id) for all item types.
-- Replaces ps_backend_accessory.lua and ps_backend_playermodel.lua.

if not SERVER then return end

util.AddNetworkString("PS_Customization_PING")
util.AddNetworkString("PS_Customization_PONG")

if not sql.TableExists("ps_customization") then
    sql.Query([[CREATE TABLE ps_customization (
        steamid TEXT NOT NULL,
        item_id TEXT NOT NULL,
        mods    TEXT NOT NULL,
        PRIMARY KEY (steamid, item_id)
    )]])
end

-- Returns the saved mods table for a player+item, resolving through three layers:
--   1. SQL row   (per-player override)
--   2. ITEM.DefaultModifications  (designer default shipped with the item file)
--   3. type-appropriate zero fallback (accessory or playermodel)
function PS_GetCustomization(ply, itemID)
    if not IsValid(ply) or not itemID then return nil end
    local steamid = ply:SteamID()

    local row = sql.QueryRow(
        "SELECT mods FROM ps_customization WHERE steamid = " .. sql.SQLStr(steamid) ..
        " AND item_id = " .. sql.SQLStr(itemID)
    )
    if row and row.mods and row.mods ~= "" then
        local ok, tbl = pcall(util.JSONToTable, row.mods)
        if ok and tbl then return tbl end
    end

    local ITEM = PS and PS.Items and PS.Items[itemID]
    if ITEM then
        if ITEM.DefaultModifications then
            return table.Copy(ITEM.DefaultModifications)
        end
        if ITEM.Attachment or ITEM.Bone or ITEM.TYPE == "accessory" then
            return {
                scale = 1, offsetX = 0, offsetY = 0, offsetZ = 0,
                rotation = 0, axis = "Right", axisDeg = -90,
                color = Color(255, 255, 255, 255)
            }
        end
        return { skin = 0, bodygroups = {}, playercolor = {255, 255, 255} }
    end

    return nil
end

-- Persists mods for a player+item. No-ops on nil/empty to avoid clobbering valid data.
function PS_SetCustomization(ply, itemID, mods)
    if not IsValid(ply) or not itemID then return end
    if not mods or (type(mods) == "table" and not next(mods)) then return end
    local steamid = ply:SteamID()
    local mods_json = util.TableToJSON(mods)
    sql.Query(
        "INSERT OR REPLACE INTO ps_customization (steamid, item_id, mods) VALUES (" ..
        sql.SQLStr(steamid) .. ", " .. sql.SQLStr(itemID) .. ", " .. sql.SQLStr(mods_json) .. ")"
    )
end

-- ============================================================================
-- LATE-JOIN SYNC
-- Send equipped accessories' customizations to a newly joining player so they
-- see existing players' cosmetics immediately.
-- ============================================================================

hook.Add("PlayerInitialSpawn", "PS_SendCustomizationsOnJoin", function(ply)
    if not IsValid(ply) then return end
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        for _, otherPly in ipairs(player.GetAll()) do
            if otherPly == ply or not IsValid(otherPly) then continue end
            if not otherPly.PS_Items then continue end
            for itemID, itemData in pairs(otherPly.PS_Items) do
                if not itemData.Equipped then continue end
                local ITEM = PS.Items and PS.Items[itemID]
                if not ITEM then continue end
                if not (ITEM.Attachment or ITEM.Bone or ITEM.TYPE == "accessory") then continue end
                local mods = PS_GetCustomization(otherPly, itemID)
                if mods and next(mods) then
                    net.Start("PS_AccessoryCustomization_Update")
                        net.WriteEntity(otherPly)
                        net.WriteString(itemID)
                        net.WriteTable(mods)
                    net.Send(ply)
                end
            end
        end
    end)
end)

-- ============================================================================
-- CONSOLE COMMANDS
-- ============================================================================

concommand.Add("ps_dump_customization", function(ply, cmd, args)
    if IsValid(ply) then print("[ps_dump_customization] Server console only.") return end
    local steamid = args and args[1]
    local rows
    if steamid and steamid ~= "all" then
        rows = sql.Query("SELECT item_id, mods FROM ps_customization WHERE steamid = " .. sql.SQLStr(steamid))
    else
        rows = sql.Query("SELECT steamid, item_id, mods FROM ps_customization")
    end
    if not rows then print("[PS SQL] No customization rows found.") return end
    for _, row in ipairs(rows) do
        print(string.format("[PS SQL] steamid=%s item_id=%s", tostring(row.steamid or steamid), tostring(row.item_id)))
        local ok, tbl = pcall(util.JSONToTable, row.mods)
        if ok and tbl then PrintTable(tbl) end
    end
end)

concommand.Add("ps_check_customization", function(ply)
    if IsValid(ply) then print("[ps_check_customization] Server console only.") return end
    local rows = sql.Query("SELECT COUNT(*) as n FROM ps_customization")
    print(string.format("[PS SQL] ps_customization rows: %s", rows and rows[1] and rows[1].n or "0"))
end)

net.Receive("PS_Customization_PING", function(len, ply)
    if not IsValid(ply) then return end
    local steamid = ply:SteamID()
    local rows = sql.Query("SELECT COUNT(*) as n FROM ps_customization WHERE steamid = " .. sql.SQLStr(steamid))
    local count = (rows and rows[1] and rows[1].n) or 0
    net.Start("PS_Customization_PONG")
        net.WriteInt(tonumber(count) or 0, 16)
        net.WriteString(tostring(sql.LastError() or ""))
    net.Send(ply)
end)
