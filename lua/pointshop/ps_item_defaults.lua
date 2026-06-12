-- Owner-level item default overrides.
-- Sits between per-player SQL data and the item's Lua DefaultModifications,
-- letting the server owner tune default positions/colors without editing item files.
--
-- Resolution order in PS_GetCustomization:
--   1. SQL row  (per-player)
--   2. PS_ItemDefaultOverrides[itemID]  ← this file
--   3. ITEM.DefaultModifications  (shipped Lua)
--   4. Type-appropriate zero fallback

if SERVER then
    util.AddNetworkString("PS_ItemDefaults_Sync")
    util.AddNetworkString("PS_ItemDefault_Set")
end

local DATA_PATH = "pointshop/item_defaults.json"

-- In-memory table, populated on load. Shared on both realms after client sync.
PS_ItemDefaultOverrides = PS_ItemDefaultOverrides or {}

-- ============================================================================
-- SHARED GATE
-- ============================================================================

-- Returns true if the player holds the ULX "owner" group.
-- Checked on both client (to hide the sub-panel) and server (to reject the net message).
function PS_IsItemDefaultOwner(ply)
    if not IsValid(ply) then return false end
    return ply:PS_GetUsergroup() == "owner"
end

-- ============================================================================
-- SHARED HELPER
-- ============================================================================

-- Returns the effective default mods for an item: owner override if present,
-- otherwise the item's own DefaultModifications, otherwise nil.
function PS_GetItemDefault(itemID)
    if not itemID then return nil end
    if PS_ItemDefaultOverrides[itemID] then
        return table.Copy(PS_ItemDefaultOverrides[itemID])
    end
    local ITEM = PS and PS.Items and PS.Items[itemID]
    if ITEM and ITEM.DefaultModifications then
        return table.Copy(ITEM.DefaultModifications)
    end
    return nil
end

-- ============================================================================
-- SERVER: LOAD / SAVE
-- ============================================================================

if SERVER then
    local function LoadDefaults()
        if not file.Exists(DATA_PATH, "DATA") then return end
        local raw = file.Read(DATA_PATH, "DATA")
        if not raw or raw == "" then return end
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and tbl then
            PS_ItemDefaultOverrides = tbl
            print(string.format("[PS Defaults] Loaded %d override(s) from %s", table.Count(tbl), DATA_PATH))
        else
            print("[PS Defaults] Failed to parse " .. DATA_PATH)
        end
    end

    local function SaveDefaults()
        if not file.IsDir("pointshop", "DATA") then
            file.CreateDir("pointshop")
        end
        file.Write(DATA_PATH, util.TableToJSON(PS_ItemDefaultOverrides, true))
        print(string.format("[PS Defaults] Saved %d override(s) to %s", table.Count(PS_ItemDefaultOverrides), DATA_PATH))
    end

    local function BroadcastDefaults(target)
        net.Start("PS_ItemDefaults_Sync")
            net.WriteTable(PS_ItemDefaultOverrides)
        if target then
            net.Send(target)
        else
            net.Broadcast()
        end
    end

    -- Load on server startup (items may not be registered yet; we just populate
    -- the table — PS_GetItemDefault merges lazily at call time)
    hook.Add("Initialize", "PS_LoadItemDefaults", function()
        LoadDefaults()
    end)

    -- Send to each client when they join
    hook.Add("PlayerInitialSpawn", "PS_SyncItemDefaultsOnJoin", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then BroadcastDefaults(ply) end
        end)
    end)

    -- ============================================================================
    -- CONSOLE COMMANDS  (server console only)
    -- ============================================================================

    -- ps_default_get <itemID>
    -- Print the effective defaults for an item.
    concommand.Add("ps_default_get", function(ply, cmd, args)
        if IsValid(ply) then print("[ps_default_get] Server console only.") return end
        local id = args and args[1]
        if not id then print("Usage: ps_default_get <itemID>") return end
        local d = PS_GetItemDefault(id)
        if d then
            print("[PS Defaults] " .. id .. ":")
            PrintTable(d)
        else
            print("[PS Defaults] No defaults found for " .. id)
        end
    end)

    -- ps_default_set <itemID> <field> <value>
    -- Set a single field on an item's override.
    -- Numeric values are stored as numbers; tables use JSON syntax.
    -- Example:  ps_default_set hat_guitar scale 1.5
    --           ps_default_set hat_guitar offset [0,5,10]
    --           ps_default_set hat_guitar ang [-90,0,0]
    concommand.Add("ps_default_set", function(ply, cmd, args)
        if IsValid(ply) then print("[ps_default_set] Server console only.") return end
        if not args or #args < 3 then
            print("Usage: ps_default_set <itemID> <field> <value>")
            return
        end
        local id, field, raw = args[1], args[2], table.concat(args, " ", 3)

        -- Try to parse as JSON (catches arrays, objects, booleans)
        local val
        local ok, parsed = pcall(util.JSONToTable, raw)
        if ok and parsed then
            val = parsed
        else
            -- Try number
            local n = tonumber(raw)
            if n ~= nil then
                val = n
            else
                val = raw  -- treat as string
            end
        end

        PS_ItemDefaultOverrides[id] = PS_ItemDefaultOverrides[id] or {}
        PS_ItemDefaultOverrides[id][field] = val
        SaveDefaults()
        BroadcastDefaults()
        print(string.format("[PS Defaults] Set %s.%s = %s", id, field, tostring(val)))
    end)

    -- ps_default_replace <itemID> <json>
    -- Replace the entire override table for one item with a JSON object.
    -- Example:  ps_default_replace hat_guitar {"scale":1.2,"ang":[-90,0,0]}
    concommand.Add("ps_default_replace", function(ply, cmd, args)
        if IsValid(ply) then print("[ps_default_replace] Server console only.") return end
        if not args or #args < 2 then
            print("Usage: ps_default_replace <itemID> <json>")
            return
        end
        local id = args[1]
        local raw = table.concat(args, " ", 2)
        local ok, tbl = pcall(util.JSONToTable, raw)
        if not ok or type(tbl) ~= "table" then
            print("[PS Defaults] Invalid JSON: " .. tostring(raw))
            return
        end
        PS_ItemDefaultOverrides[id] = tbl
        SaveDefaults()
        BroadcastDefaults()
        print("[PS Defaults] Replaced override for " .. id)
        PrintTable(tbl)
    end)

    -- ps_default_clear <itemID>
    -- Remove the owner override for one item, falling back to Lua DefaultModifications.
    concommand.Add("ps_default_clear", function(ply, cmd, args)
        if IsValid(ply) then print("[ps_default_clear] Server console only.") return end
        local id = args and args[1]
        if not id then print("Usage: ps_default_clear <itemID>") return end
        if PS_ItemDefaultOverrides[id] then
            PS_ItemDefaultOverrides[id] = nil
            SaveDefaults()
            BroadcastDefaults()
            print("[PS Defaults] Cleared override for " .. id)
        else
            print("[PS Defaults] No override found for " .. id)
        end
    end)

    -- ps_default_dump
    -- Print all current overrides.
    concommand.Add("ps_default_dump", function(ply)
        if IsValid(ply) then print("[ps_default_dump] Server console only.") return end
        local count = table.Count(PS_ItemDefaultOverrides)
        if count == 0 then print("[PS Defaults] No overrides.") return end
        print(string.format("[PS Defaults] %d override(s):", count))
        PrintTable(PS_ItemDefaultOverrides)
    end)

    -- ps_default_save
    -- Explicitly flush the in-memory table to disk (auto-saved after every set/clear).
    concommand.Add("ps_default_save", function(ply)
        if IsValid(ply) then print("[ps_default_save] Server console only.") return end
        SaveDefaults()
    end)

    -- ============================================================================
    -- NET: OWNER PANEL SAVE
    -- Receives a full mods table from the owner's in-game default editor panel.
    -- ============================================================================
    net.Receive("PS_ItemDefault_Set", function(len, ply)
        local itemID = net.ReadString()
        local mods   = net.ReadTable()
        local clear  = net.ReadBool()

        if not PS_IsItemDefaultOwner(ply) then return end
        if not itemID or itemID == "" then return end

        if clear then
            PS_ItemDefaultOverrides[itemID] = nil
        else
            if not mods or not next(mods) then return end
            if PS_SanitizeCustomizationData then
                local ITEM = PS and PS.Items and PS.Items[itemID]
                local itemType = ITEM and ITEM.TYPE or "accessory"
                mods = PS_SanitizeCustomizationData(mods, itemType)
            end
            PS_ItemDefaultOverrides[itemID] = mods
        end

        SaveDefaults()
        BroadcastDefaults()
    end)
end

-- ============================================================================
-- CLIENT: RECEIVE SYNC
-- ============================================================================

if CLIENT then
    net.Receive("PS_ItemDefaults_Sync", function()
        PS_ItemDefaultOverrides = net.ReadTable()
    end)
end
