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

-- Groups allowed to mark items for removal. A table rather than a hardcoded string so
-- renaming the ULX group doesn't silently lock everyone out of the feature — but the
-- default stays owner-only.
--
-- Deliberately NOT falling back to ply:IsSuperAdmin(): that's a privilege check, and
-- other ranks commonly inherit superadmin in ULX, so it would widen this below owner.
-- This feature deletes item files and purges saved data; it stays owner-gated. Add
-- groups here explicitly if you want more.
PS_RemovalQueueGroups = PS_RemovalQueueGroups or { owner = true }

function PS_IsRemovalQueueAdmin(ply)
    if not IsValid(ply) then return false end
    return PS_RemovalQueueGroups[ply:PS_GetUsergroup()] == true
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

    -- Sent only to players who can actually use the removal UI.
    --
    -- This used to go to everyone, including on join. The payload carries markedBy
    -- SteamIDs and server-side Lua file paths, so every player on the server received a
    -- list of who marked what and where those files live on disk — for a feature they
    -- can't even open.
    local function Broadcast(target)
        if target then
            if not PS_IsRemovalQueueAdmin(target) then return end
            net.Start("PS_RemovalQueue_Sync")
                net.WriteTable(PS_RemovalQueue)
            net.Send(target)
            return
        end

        local recipients = {}
        for _, p in ipairs(player.GetAll()) do
            if PS_IsRemovalQueueAdmin(p) then recipients[#recipients + 1] = p end
        end
        if #recipients == 0 then return end

        net.Start("PS_RemovalQueue_Sync")
            net.WriteTable(PS_RemovalQueue)
        net.Send(recipients)
    end

    hook.Add("Initialize", "PS_LoadRemovalQueue", Load)

    hook.Add("PlayerInitialSpawn", "PS_SyncRemovalQueueOnJoin", function(ply)
        timer.Simple(1, function()
            -- Broadcast() re-checks, but bail early so non-admins never even reach it.
            if IsValid(ply) and PS_IsRemovalQueueAdmin(ply) then Broadcast(ply) end
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
