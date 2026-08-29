if SERVER then AddCSLuaFile() end

local BASE = {}

function BASE:ApplyModelSettings(ply, modifications)
    -- Only when it actually differs.
    --
    -- SetModel resets skin and bodygroups, and this is now the apply half of
    -- PS:ApplyAppearance, which runs on every appearance change rather than once per equip.
    -- Calling it unconditionally meant every hat equipped re-set the body underneath it --
    -- and a powerup that has shrunk the player (ply:SetModelScale in its own OnEquip) is
    -- exactly the kind of state that a needless SetModel puts back.
    if ply:GetModel() ~= self.Model then
        ply:SetModel(self.Model)
    end

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

        if SERVER then
            local r, g, b = PS:ReadColorRGB(modifications.playercolor)
            ply.PS_PlayerColor = Color(r, g, b, 255)
            ply.PS_UseColor2Proxy = self.UseColor2Proxy or false
        end

        -- The PS_PlayerModelColor_Broadcast that used to be here is gone. It had three
        -- senders and no receiver anywhere in the addon — the colour reaches clients as
        -- entity state, because SetColor and SetPlayerColor are both networked.
        --
        -- Harmless when it ran on an equip. Not harmless now: this function is the apply
        -- half of PS:ApplyAppearance, which runs on every appearance change, so a dead
        -- broadcast to every player would have been the cost of the whole refactor.
    end
end

-- OnEquip and OnHolster PERSIST. They no longer touch the character.
--
-- They used to do both, and that is what forced the loadout system to grow its own copy of
-- the apply half (Wear) -- there was no way to show an item without also saving it. Two apply
-- paths that did not know about each other is how equipping a hat half-replaced a loadout.
--
-- The character is PS:ApplyAppearance's, and only its. The equip path calls it once after the
-- item's own hooks have run.

function BASE:OnEquip(ply, modifications)
    if not SERVER then return end

    if not ply._OldModel then
        ply._OldModel = ply:GetModel()
    end

    local itemID = self.ID or self.Model

    -- Stored first, passed second. The stored row is what the player customised; the passed
    -- table is what the caller happened to have, which for a brand-new item is empty.
    local mods = (PS_GetCustomization and PS_GetCustomization(ply, itemID)) or modifications or {}
    if PS_SetCustomization then PS_SetCustomization(ply, itemID, mods) end

    if PS and PS.Config and PS.Config.Debug then
        print(string.format("[PS Playermodel] OnEquip for %s - itemID: %s, model: %s",
            ply:Nick(), itemID, self.Model))
    end
end

-- Nothing.
--
-- Taking a playermodel off is not an event this item can act on: what happens next depends on
-- whether the player owns another one, whether it is legal for their team, and whether an
-- overlay is on -- none of which this item knows. PS:ApplyAppearance answers all three, and
-- resets the character only when the answer is "no model at all".
--
-- This used to re-resolve the model, restore a snapshot, reset every bodygroup, reset the
-- skin, reset both colour channels and broadcast, on every holster of every model, including
-- the very common case where another model was about to replace it a moment later.
function BASE:OnHolster(ply)
end

function BASE:OnModify(ply, modifications)
    if not self.Bodygroups then return end
    if not SERVER then return end

    local itemID = self.ID or self.Model
    local mods = (PS_GetCustomization and PS_GetCustomization(ply, itemID)) or modifications or {}
    if PS_SetCustomization then PS_SetCustomization(ply, itemID, mods) end
end

if CLIENT then
    function BASE:Modify(ply, modifications)
        local panel = PS.UI.Open("PSItemCustomizationPanel")
        panel:SetItem(self)  -- Pass entire item so panel can detect TYPE and load saved data
        if PS and PS.ToggleMenu then PS:ToggleMenu() end
    end
end

return BASE
