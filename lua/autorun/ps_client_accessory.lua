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

    net.Receive("PS_AccessoryCustomization_Update", function()
        local ply    = net.ReadEntity()
        local itemID = net.ReadString()
        local mods   = net.ReadTable()

        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
        PS_AccessoryCustomizations[ply][itemID] = mods

        -- Apply immediately to any live clientside model for this item
        if PS and PS.ClientsideModels and PS.ClientsideModels[ply] then
            local ITEM = PS.Items and PS.Items[itemID]
            local modelPath = ITEM and ITEM.Model
            local useColor2 = ITEM and ITEM.UseColor2Proxy or false

            for _, mdl in pairs(PS.ClientsideModels[ply]) do
                if IsValid(mdl) and mdl.GetModel and modelPath and mdl:GetModel() == modelPath then
                    mdl.PS_Modifications = mods
                    if mods.scale then mdl:SetModelScale(mods.scale, 0) end
                    if mods.color and PS and PS.ApplyColorToModel then
                        PS:ApplyColorToModel(mdl, mods.color, useColor2)
                    end
                end
            end
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
