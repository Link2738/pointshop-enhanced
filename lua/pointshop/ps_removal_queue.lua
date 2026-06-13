-- Item removal queue.
-- Owner marks items in-game; entries are written to data/pointshop/removal_queue.json
-- for the Python toolbelt to consume (delete lua file, model, materials, purge SQL rows).

if SERVER then
    util.AddNetworkString("PS_RemovalQueue_Mark")
    util.AddNetworkString("PS_RemovalQueue_Sync")
end

local DATA_PATH = "pointshop/removal_queue.json"

PS_RemovalQueue = PS_RemovalQueue or {}

-- ============================================================================
-- SHARED
-- ============================================================================

function PS_IsRemovalQueueAdmin(ply)
    if not IsValid(ply) then return false end
    return ply:PS_GetUsergroup() == "owner"
end

-- ============================================================================
-- SERVER
-- ============================================================================

if SERVER then
    local function Load()
        if not file.Exists(DATA_PATH, "DATA") then return end
        local raw = file.Read(DATA_PATH, "DATA")
        if not raw or raw == "" then return end
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and tbl then
            PS_RemovalQueue = tbl
            print(string.format("[PS Removal] Loaded %d queued item(s)", table.Count(tbl)))
        end
    end

    local function Save()
        if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end
        file.Write(DATA_PATH, util.TableToJSON(PS_RemovalQueue, true))
    end

    local function Broadcast(target)
        net.Start("PS_RemovalQueue_Sync")
            net.WriteTable(PS_RemovalQueue)
        if target then net.Send(target) else net.Broadcast() end
    end

    hook.Add("Initialize", "PS_LoadRemovalQueue", Load)

    hook.Add("PlayerInitialSpawn", "PS_SyncRemovalQueueOnJoin", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then Broadcast(ply) end
        end)
    end)

    net.Receive("PS_RemovalQueue_Mark", function(len, ply)
        if not PS_IsRemovalQueueAdmin(ply) then return end

        local itemID = net.ReadString()
        local unmark = net.ReadBool()

        if unmark then
            PS_RemovalQueue[itemID] = nil
            Save()
            Broadcast()
            return
        end

        local ITEM = PS and PS.Items and PS.Items[itemID]
        if not ITEM then return end

        PS_RemovalQueue[itemID] = {
            itemID   = itemID,
            name     = ITEM.Name     or itemID,
            model    = ITEM.Model    or "",
            material = ITEM.Material or "",
            type     = ITEM.TYPE     or "unknown",
            luaFile  = ITEM.__luaFile or "",
            category = ITEM.Category or "",
            markedAt = os.time(),
            markedBy = ply:SteamID(),
        }

        Save()
        Broadcast()
        print(string.format("[PS Removal] %s marked '%s' (%s) for removal", ply:Nick(), itemID, ITEM.Name or "?"))
    end)
end

-- ============================================================================
-- CLIENT
-- ============================================================================

if CLIENT then
    net.Receive("PS_RemovalQueue_Sync", function()
        PS_RemovalQueue = net.ReadTable()
    end)

    function PS_MarkItemForRemoval(itemID, unmark)
        net.Start("PS_RemovalQueue_Mark")
            net.WriteString(itemID)
            net.WriteBool(unmark or false)
        net.SendToServer()
    end
end
