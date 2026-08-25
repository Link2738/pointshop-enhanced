if SERVER then AddCSLuaFile() end

local BASE = {}

function BASE:ApplyModelSettings(ply, modifications)
    ply:SetModel(self.Model)
    if modifications and modifications.skin then
        ply:SetSkin(modifications.skin)
    end
    if modifications and modifications.bodygroups then
        for k, v in pairs(modifications.bodygroups) do
            -- Keys come back from JSON as strings; SetBodygroup needs numbers.
            ply:SetBodygroup(tonumber(k) or k, tonumber(v) or v)
        end
    end
    if modifications and modifications.playercolor then
        -- Both colour channels are written by PS:ApplyColorToPlayer (sh_init.lua) — the
        -- active one to this colour, the other reset to neutral. The two-branch version
        -- that used to live here was one of six copies of that rule.
        --
        -- It also handled the three colour shapes inline; ReadRGB in that function does it
        -- now, including the normalised Vector shape item files write.
        PS:ApplyColorToPlayer(ply, modifications.playercolor, self.UseColor2Proxy)

        local r, g, b = PS:ReadColorRGB(modifications.playercolor)

        -- Store and broadcast color
        if SERVER then
            ply.PS_PlayerColor = Color(r, g, b, 255)
            ply.PS_UseColor2Proxy = self.UseColor2Proxy or false
            
            -- Broadcast color to all clients
            net.Start("PS_PlayerModelColor_Broadcast")
                net.WriteEntity(ply)
                net.WriteUInt(r, 8)
                net.WriteUInt(g, 8)
                net.WriteUInt(b, 8)
                net.WriteBool(self.UseColor2Proxy or false)
            net.Broadcast()
        end
    end
end

local function applyAndPersist(base, ply, itemID, modifications)
    local mods = (PS_GetCustomization and PS_GetCustomization(ply, itemID)) or modifications or {}
    if PS_SetCustomization then PS_SetCustomization(ply, itemID, mods) end
    base:ApplyModelSettings(ply, mods)
end

function BASE:OnEquip(ply, modifications)
    if not ply._OldModel then
        ply._OldModel = ply:GetModel()
    end
    ply._PS_ActivePlayerModel = self.Model
    local itemID = self.ID or self.Model
    if SERVER then
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS Playermodel] OnEquip for %s - itemID: %s, model: %s", ply:Nick(), itemID, self.Model))
        end
        applyAndPersist(self, ply, itemID, modifications)
    end
end

-- Hands the model back to the gamemode rather than replaying a snapshot.
--
-- This restored ply._OldModel, captured in OnEquip behind `if not ply._OldModel`, so it was
-- written once and never cleared. Equip A, then B, then holster B, and you got whatever you
-- wore before A. It also survived team changes, so holstering after switching teams handed
-- back a model for the team you used to be on.
--
-- hook.Run("PlayerSetModel") asks the gamemode instead. That is the standard hook every
-- gamemode already implements to decide what a player wears, so this stays correct on a
-- gamemode that has never heard of Bear Hunt — which is the same reason the theme and the
-- appearance provider go through hooks rather than calling into it.
--
-- Falls back to the old behaviour if nothing answers, so a gamemode that does not implement
-- the hook is no worse off than before.
function BASE:OnHolster(ply)
    ply._PS_ActivePlayerModel = nil

    if SERVER then
        local before = ply:GetModel()
        hook.Run("PlayerSetModel", ply)

        -- Nothing claimed it. Use the snapshot rather than leaving the shop model on.
        if ply:GetModel() == before and ply._OldModel then
            ply:SetModel(ply._OldModel)
        end
    end

    ply._OldModel = nil

    -- Reset all color/bodygroup state so the default model is clean. Neutral through the
    -- modulation path sets modulation to white and clears the proxy, which is both
    -- channels — the same "clear what you are not using" rule, used to clear both.
    PS:ApplyColorToPlayer(ply, Color(255, 255, 255, 255), false)
    -- Reset all bodygroups to 0
    for i = 0, ply:GetNumBodyGroups() - 1 do
        ply:SetBodygroup(i, 0)
    end
    ply:SetSkin(0)
    -- Broadcast the reset to all clients
    if SERVER then
        ply.PS_PlayerColor = Color(255, 255, 255, 255)
        ply.PS_UseColor2Proxy = false
        net.Start("PS_PlayerModelColor_Broadcast")
            net.WriteEntity(ply)
            net.WriteUInt(255, 8)
            net.WriteUInt(255, 8)
            net.WriteUInt(255, 8)
            net.WriteBool(false)
        net.Broadcast()
    end
end

function BASE:OnModify(ply, modifications)
    if not self.Bodygroups then return end
    if SERVER then
        applyAndPersist(self, ply, self.ID or self.Model, modifications)
    end
end

if CLIENT then
    function BASE:Modify(ply, modifications)
        local panel = vgui.Create("PSItemCustomizationPanel")
        panel:SetItem(self)  -- Pass entire item so panel can detect TYPE and load saved data
        if PS and PS.ToggleMenu then PS:ToggleMenu() end
    end
end

return BASE
