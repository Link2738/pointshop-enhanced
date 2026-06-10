-- Client-side helper for accessory customization messaging.
-- Server-side logic is provided by `lua/pointshop/ps_backend_accessory.lua`.

if CLIENT then
    PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}

    local function resolve_model_path_client(id_or_model)
        if not id_or_model then return id_or_model end
        if string.find(id_or_model, "/") then return id_or_model end
        if PS_GetModelPathForItem then return PS_GetModelPathForItem(id_or_model) or id_or_model end
        if PS and PS.Items and PS.Items[id_or_model] and PS.Items[id_or_model].Model then return PS.Items[id_or_model].Model end
        if PS and PS.Items then
            for k,it in pairs(PS.Items) do
                if it then
                    if tostring(it.ID) == tostring(id_or_model) or tostring(it.UniqueID) == tostring(id_or_model) or tostring(k) == tostring(id_or_model) then
                        if it.Model then return it.Model end
                    end
                end
            end
        end
        return id_or_model
    end

    -- Send using itemID (server expects itemID)
    function PS_SendAccessoryCustomization(itemID, mods)
        net.Start("PS_AccessoryCustomization_Update")
            net.WriteString(tostring(itemID))
            net.WriteTable(mods)
        net.SendToServer()
    end

    net.Receive("PS_AccessoryCustomization_Update", function()
        local ply = net.ReadEntity()
        local id_or_model = net.ReadString()
        local mods = net.ReadTable()
        local modelPath = resolve_model_path_client(id_or_model)
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
        PS_AccessoryCustomizations[ply][modelPath] = mods
        
        -- Update existing ClientsideModel immediately (no re-equip needed)
        -- ModifyClientsideModel will fetch the updated PS_AccessoryCustomizations automatically
        if PS and PS.ClientsideModels and PS.ClientsideModels[ply] then
            -- Find which item uses this model path to check UseColor2Proxy flag
            local useColor2 = false
            if PS.Items then
                for item_id, ITEM in pairs(PS.Items) do
                    if ITEM.Model == modelPath and ITEM.UseColor2Proxy then
                        useColor2 = true
                        break
                    end
                end
            end
            
            for k, mdl in pairs(PS.ClientsideModels[ply]) do
                if IsValid(mdl) and mdl.GetModel and mdl:GetModel() == modelPath then
                    -- Update stored modifications (used by some items)
                    mdl.PS_Modifications = mods
                    
                    -- Apply instant visual feedback for scale and color
                    if mods.scale then
                        mdl:SetModelScale(mods.scale, 0)
                    end
                    if mods.color and PS and PS.ApplyColorToModel then
                        PS:ApplyColorToModel(mdl, mods.color, useColor2)
                    end
                    
                    -- Position/rotation/offset will be applied next frame by ModifyClientsideModel
                end
            end
        end
    end)
    -- Client-side quick ping: prints server reply to client console
    concommand.Add("ps_accessory_ping", function()
        local ok, err = pcall(function()
            net.Start("PS_AccessoryCustomization_PING")
            net.SendToServer()
        end)
        if not ok then
            print("[ps_accessory_ping] Failed to start ping: server may not have the accessory module loaded.")
            print("Run on the SERVER console: lua_openscript autorun/server/ps_accessory_customization_autorun.lua")
            print("Or restart the server so ps_backend_accessory.lua is loaded.")
            if err then print("Error:", err) end
        end
    end)

    net.Receive("PS_AccessoryCustomization_PONG", function()
        local count = net.ReadInt(16)
        local lastErr = net.ReadString()
        print("[ps_accessory_ping] server reported rows=", count, " sql.LastError=", lastErr)
    end)
end
