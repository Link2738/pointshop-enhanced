-- Client-side helper for accessory customization messaging.
-- Server-side storage is handled by ps_backend_storage.lua.

if CLIENT then
    -- PS_AccessoryCustomizations[ply][itemID] = mods
    -- Keyed by itemID (not model path) to match ps_backend_storage.lua's schema.
    PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}

    function PS_SendAccessoryCustomization(itemID, mods)
        net.Start("PS_AccessoryCustomization_Update")
            net.WriteString(tostring(itemID))
            net.WriteTable(mods)
        net.SendToServer()
    end

    -- Records one item's modifiers for a player and pushes them into any live model.
    --
    -- Extracted because two messages arrive here now: the per-item customization broadcast,
    -- and the loadout overlay, which carries a whole set at once. Both mean the same thing to
    -- the renderer -- these are the modifiers to draw this player's accessory with.
    local function StoreMods(ply, itemID, mods)
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
        PS_AccessoryCustomizations[ply][itemID] = mods

        if not (PS and PS.ClientsideModels and PS.ClientsideModels[ply]) then return end

        local ITEM = PS.Items and PS.Items[itemID]
        local modelPath = ITEM and ITEM.Model
        local useColor2 = ITEM and ITEM.UseColor2Proxy or false

        for _, mdl in pairs(PS.ClientsideModels[ply]) do
            if IsValid(mdl) and mdl.GetModel and modelPath and mdl:GetModel() == modelPath then
                mdl.PS_Modifications = mods
                if mods.scale then mdl:SetModelScale(mods.scale, 0) end
                if mods.color and PS.ApplyColorToModel then
                    PS:ApplyColorToModel(mdl, mods.color, useColor2)
                end
            end
        end
    end

    net.Receive("PS_AccessoryCustomization_Update", function()
        local ply    = net.ReadEntity()
        local itemID = net.ReadString()
        local mods   = net.ReadTable()

        StoreMods(ply, itemID, mods)
    end)

    -- A player's whole accessory overlay, in one bit-packed message.
    --
    -- Replaces one PS_AccessoryCustomization_Update broadcast per item, each carrying a
    -- net.WriteTable -- a six-piece loadout was six untyped tables to every player, and
    -- clearing it was six more. The modifiers come through PS_ReadModifiers, the same decoder
    -- the item sync uses.
    net.Receive("PS_Appearance_Sync", function()
        local ply   = net.ReadEntity()

        -- 8 bits, matching the writer in sv_appearance.lua. This carries the owned set as well
        -- as a loadout, and nothing caps the owned set at 24.
        local count = net.ReadUInt(8)

        for _ = 1, count do
            local itemID = net.ReadString()
            local mods   = PS_ReadModifiers()

            -- Read before the validity check, always: the fields are positional, so skipping
            -- one leaves every entry after it reading the wrong bits.
            if IsValid(ply) then StoreMods(ply, itemID, mods) end
        end
    end)

    concommand.Add("ps_customization_ping", function()
        local ok, err = pcall(function()
            net.Start("PS_Customization_PING")
            net.SendToServer()
        end)
        if not ok then
            print("[ps_customization_ping] Failed:", err)
        end
    end)

    net.Receive("PS_Customization_PONG", function()
        local count    = net.ReadInt(16)
        local hadError = net.ReadBool()
        -- The error text itself stays server-side (it leaks schema and paths); the
        -- client only learns whether one occurred, and the detail is in the server log.
        print("[ps_customization_ping] rows=", count,
            hadError and " (server reported a SQL error — see server console)" or "")
    end)
end
