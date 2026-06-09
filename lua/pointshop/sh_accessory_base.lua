if SERVER then
    AddCSLuaFile()
    -- Network strings are registered by ps_backend_accessory.lua
    -- No need to duplicate util.AddNetworkString here
end

local BASE = {}

function BASE:ApplyAccessorySettings(ply, modifications)
    if modifications then
        ply._AccessoryModifications = ply._AccessoryModifications or {}
        ply._AccessoryModifications[self.Model] = modifications
        -- Also populate player's PS_Items modifiers cache on the client so
        -- clientside recreation (PS_AddClientsideModel) can read the item data
        -- immediately when re-equipping after a holster+reequip cycle.
        if CLIENT then
            ply.PS_Items = ply.PS_Items or {}
            local key = self.ID or self.Model
            ply.PS_Items[key] = ply.PS_Items[key] or {}
            ply.PS_Items[key].Modifiers = modifications
        end
    end
end

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

    function PS_RequestApplyAccessoryCustomization(itemID, mods)
        -- Send the canonical itemID to the server (server resolves to a model path)
        if PS_SendAccessoryCustomization then
            PS_SendAccessoryCustomization(itemID, mods)
            return
        end
        net.Start("PS_AccessoryCustomization_Update")
            net.WriteString(tostring(itemID))
            net.WriteTable(mods)
        net.SendToServer()
    end

    function PS_RequestAccessoryCustomization(itemID)
        net.Start("PS_AccessoryCustomization_Request")
            net.WriteString(tostring(itemID))
        net.SendToServer()
    end

    concommand.Add("ps_dump_local_accessories", function()
        print("[ps_dump_local_accessories] PS_AccessoryCustomizations:")
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PrintTable(PS_AccessoryCustomizations)
    end)

    function PS_GetAccessoryCustomization(ply, modelPath)
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        if not ply or not modelPath then return nil end
        if PS_AccessoryCustomizations[ply] then
            return PS_AccessoryCustomizations[ply][modelPath]
        end
        return nil
    end

    function BASE:Modify(ply, modifications)
        if CLIENT then
            local panel = vgui.Create("PSItemCustomizationPanel")
            panel:SetItem(self)  -- Pass entire item so panel can detect TYPE and load saved data
            if PS and PS.ToggleMenu then PS:ToggleMenu() end
        end
    end
end

function BASE:OnEquip(ply, modifications)
    if SERVER then
        local mods = nil
        -- Treat an empty table the same as nil so we fall through to stored/default data.
        -- PointShop passes modifications = {} for brand-new items that have never been
        -- customised, which would otherwise skip PS_GetAccessoryCustomization entirely.
        if modifications ~= nil and type(modifications) == "table" and next(modifications) ~= nil then
            mods = modifications
        elseif PS_GetAccessoryCustomization then
            mods = PS_GetAccessoryCustomization(ply, self.Model)
        end
        -- Only persist/broadcast when we actually have customization data to avoid
        -- overwriting stored data with an empty table.
        if mods then
            -- Apply settings locally first so the player's appearance updates immediately
            self:ApplyAccessorySettings(ply, mods)
            -- Persist using the provider function if available; otherwise run the apply hook as a fallback
            if PS_SetAccessoryCustomization then
                PS_SetAccessoryCustomization(ply, self.Model, mods)
            else
                hook.Run("PS_AccessoryCustomization_Apply", ply, self.Model, mods)
            end
            -- Broadcast to clients so they can apply the clientsidemodel modifications for this player
            net.Start("PS_AccessoryCustomization_Update")
                net.WriteEntity(ply)
                net.WriteString(self.Model)
                net.WriteTable(mods)
            net.Broadcast()
        end
    end

    -- Runs on both realms: server broadcasts net message, client creates the model locally
    ply:PS_AddClientsideModel(self.ID)
end

function BASE:OnHolster(ply)
    ply:PS_RemoveClientsideModel(self.ID)
end

function BASE:ModifyClientsideModel(ply, model, pos, ang, modifications)
    if not modifications and PS_GetAccessoryCustomization then
        modifications = PS_GetAccessoryCustomization(ply, self.Model)
    end
    local scale = modifications and modifications.scale or 1
    model:SetModelScale(scale, 0)

    -- Apply offset and angle modifications if present
    if modifications then
        -- offset can be a table {x,y,z} or a Vector
        local off = modifications.offset
        local ox, oy, oz = 0, 0, 0
        if off then
            if type(off) == "table" then
                ox = off[1] or 0
                oy = off[2] or 0
                oz = off[3] or 0
            elseif type(off) == "Vector" or tostring(type(off)) == "Vector" then
                ox, oy, oz = off.x or 0, off.y or 0, off.z or 0
            end
        end

        -- Rotation can be provided as an `ang` table/Angle or as explicit `axis` + `axisDeg`.
        -- Prefer `ang` first so stored angle data is applied directly; fall back to axis+axisDeg.
        local ap, ay, ar = 0, 0, 0
        if modifications.ang then
            local aang = modifications.ang
            if type(aang) == "table" then
                ap = aang[1] or 0
                ay = aang[2] or 0
                ar = aang[3] or 0
            elseif type(aang) == "Angle" or tostring(type(aang)) == "Angle" then
                ap, ay, ar = aang.p or 0, aang.y or 0, aang.r or 0
            end
        elseif modifications.axis and modifications.axisDeg then
            local ax = tostring(modifications.axis)
            local deg = tonumber(modifications.axisDeg) or 0
            if ax == "Right" then
                ap = deg
            elseif ax == "Up" then
                ay = deg
            elseif ax == "Forward" then
                ar = deg
            end
        end

        local rotation = modifications.rotation or 0

        -- apply rotation and ang offsets
        ang:RotateAroundAxis(ang:Up(), rotation)
        ang:RotateAroundAxis(ang:Right(), ap)
        ang:RotateAroundAxis(ang:Up(), ay)
        ang:RotateAroundAxis(ang:Forward(), ar)

        -- compute final position using transformed ang
        local finalPos = pos + ang:Forward() * ox + ang:Right() * oy + ang:Up() * oz
        pos = finalPos
        
        -- Apply color from modifications using PS:ApplyColorToModel
        if CLIENT and modifications.color then
            local col = modifications.color
            local r = col.r or col[1] or 255
            local g = col.g or col[2] or 255
            local b = col.b or col[3] or 255
            local a = col.a or col[4] or 255
            local useColor2 = self.UseColor2Proxy or false
            PS:ApplyColorToModel(model, Color(r, g, b, a), useColor2)
        end
    end

    return model, pos, ang
end

function BASE:OnModify(ply, modifications)
    if SERVER then
        local custom = PS_GetAccessoryCustomization(ply, self.Model)
        -- Prefer explicit `modifications` when provided; otherwise use stored `custom`.
        -- Do not default to an empty table, as that would overwrite stored data.
        local modsToSave = nil
        if modifications ~= nil then
            modsToSave = modifications
        elseif custom ~= nil then
            modsToSave = custom
        end
        if modsToSave then
            -- Apply locally first
            self:ApplyAccessorySettings(ply, modsToSave)
            if PS_SetAccessoryCustomization then
                PS_SetAccessoryCustomization(ply, self.Model, modsToSave)
            else
                hook.Run("PS_AccessoryCustomization_Apply", ply, self.Model, modsToSave)
            end
            -- Broadcast customization to ALL clients so everyone sees the update
            net.Start("PS_AccessoryCustomization_Update")
                net.WriteEntity(ply)
                net.WriteString(self.Model)
                net.WriteTable(modsToSave)
            net.Broadcast()
        end
    end
    if CLIENT then
        if IsValid(ply) then self:ApplyAccessorySettings(ply, modifications) end
    end
end

function BASE:Move(pl, modifications, ply, data) end

if CLIENT then
    -- Refresh the clientsided model for this accessory on the given player by
    -- performing the minimal remove+recreate sequence the equip/holster flow uses.
    -- This intentionally calls the client's PS_Add/Remove helpers to keep behavior
    -- consistent with the rest of the system while allowing callers to trigger
    -- a local refresh without invoking full equip/holster logic.
    function BASE:RefreshClientsideModel(ply)
        if not IsValid(ply) then return end
        pcall(function()
            if ply.PS_RemoveClientsideModel then
                pcall(function() ply:PS_RemoveClientsideModel(self.ID) end)
            end
            timer.Simple(0.15, function()
                if not IsValid(ply) then return end
                if ply.PS_AddClientsideModel then
                    pcall(function() ply:PS_AddClientsideModel(self.ID) end)
                end
            end)
        end)
    end
end

-- Holster the accessory then re-equip it after a short delay. This is useful for
-- forcing a full clientsided-model refresh that uses server-authoritative data.
function BASE:HolsterAndReequip(ply)
    pcall(function()
        if not IsValid(ply) then return end
        -- Call holster immediately
        pcall(function() self:OnHolster(ply) end)
        -- Re-equip after a short delay so server updates and clientside model recreation happen
        timer.Simple(1, function()
            if not IsValid(ply) then return end
            -- Try to obtain server-authoritative modifications to pass into OnEquip so
            -- the client recreates the clientsided model using authoritative data.
            local mods = nil
            -- Prefer provider/getter when available
            if PS_GetAccessoryCustomization then
                pcall(function()
                    mods = PS_GetAccessoryCustomization(ply, self.Model)
                end)
            end
            -- Fallback to player's PS_Items if net.Receive populated it
            if not mods and ply and ply.PS_Items and self.ID and ply.PS_Items[self.ID] and ply.PS_Items[self.ID].Modifiers then
                mods = ply.PS_Items[self.ID].Modifiers
            end
            pcall(function() self:OnEquip(ply, mods) end)
        end)
    end)
end

return BASE
