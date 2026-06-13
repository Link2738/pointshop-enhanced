-- Owner-only panel for editing per-item server defaults.
-- Opened from the item dropdown ("Edit Default..."), visible to ULX "owner" group only.
-- Has live accessory preview and camera orbit controls.

local PANEL = {}

function PANEL:Init()
    self:SetTitle("")
    self:SetSize(380, 10)
    self:SetPos(ScrW() - 400, ScrH() / 2 - 200)
    self:MakePopup()
    self:SetDraggable(true)
    self:SetSizable(false)
    self:ShowCloseButton(true)

    self._controls = {}
    self._sliders  = {}
    self.orbitRadius = 60

    self:SetupHooks()
end

-- ============================================================================
-- CAMERA / PREVIEW HOOKS
-- ============================================================================

function PANEL:SetupHooks()
    hook.Add("ShouldDrawLocalPlayer", "PSOwnerDefaults_DrawSelf", function()
        return IsValid(self) and self:IsVisible()
    end)

    hook.Add("CalcView", "PSOwnerDefaults_CalcView", function(ply, pos, angles, fov)
        if not (IsValid(self) and self:IsVisible()) then return end
        if ply ~= LocalPlayer() or not ply:Alive() then return end

        local sl = self._sliders
        local rotDeg = sl.camRot   and sl.camRot:GetValue()   or 0
        local yOff   = sl.camY     and sl.camY:GetValue()     or 0
        local radius = sl.camZoom  and sl.camZoom:GetValue()  or self.orbitRadius

        local theta  = math.rad(rotDeg)
        local phi    = math.pi / 2
        local target = ply:GetPos() + Vector(0, 0, 64 + yOff)
        local view   = {}
        view.origin  = target + Vector(
            radius * math.sin(phi) * math.cos(theta),
            radius * math.sin(phi) * math.sin(theta),
            radius * math.cos(phi)
        )
        view.angles   = (target - view.origin):Angle()
        view.fov      = fov
        view.drawviewer = true
        return view
    end)
end

-- ============================================================================
-- LIVE PREVIEW
-- ============================================================================

function PANEL:ApplyLivePreview()
    if self.itemType ~= "accessory" then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local sl = self._sliders
    local mods = {
        offset = {
            sl.offsetX and sl.offsetX:GetValue() or 0,
            sl.offsetY and sl.offsetY:GetValue() or 0,
            sl.offsetZ and sl.offsetZ:GetValue() or 0,
        },
        ang = {
            sl.pitch and sl.pitch:GetValue() or 0,
            sl.yaw   and sl.yaw:GetValue()   or 0,
            sl.roll  and sl.roll:GetValue()   or 0,
        },
        scale = sl.scale and sl.scale:GetValue() or 1,
    }

    PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
    PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
    PS_AccessoryCustomizations[ply][self.itemID] = mods
end

function PANEL:RestoreOriginal()
    if self.itemType ~= "accessory" then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not self._originalMods then return end
    PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
    PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
    PS_AccessoryCustomizations[ply][self.itemID] = self._originalMods
end

-- ============================================================================
-- BUILD UI
-- ============================================================================

function PANEL:SetItem(item)
    if not item then return end
    self.itemID   = item.ID   or item.Model or ""
    self.itemType = item.TYPE or "accessory"

    -- Snapshot current live mods so we can restore on discard
    local ply = LocalPlayer()
    if IsValid(ply) then
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
        self._originalMods = table.Copy(PS_AccessoryCustomizations[ply][self.itemID] or {})
    end

    for _, c in ipairs(self._controls) do
        if IsValid(c) then c:Remove() end
    end
    self._controls = {}
    self._sliders  = {}

    local baseX = 14
    local y     = 36
    local w     = self:GetWide() - 28

    local function track(c) self._controls[#self._controls + 1] = c end

    local function SectionTitle(txt)
        local lbl = self:Add("DLabel")
        lbl:SetPos(baseX, y); lbl:SetSize(w, 18)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetTextColor(Color(180, 140, 30))
        lbl:SetText(txt)
        track(lbl); y = y + 20
    end

    local function Slider(label, key, min, max, dec, onChange)
        local row = self:Add("DPanel")
        row:SetPos(baseX, y); row:SetSize(w, 22)
        row.Paint = function() end
        track(row)

        local lbl = row:Add("DLabel")
        lbl:SetPos(0, 0); lbl:SetSize(90, 22)
        lbl:SetText(label); lbl:SetTextColor(Color(200, 200, 200))

        local sl = row:Add("DNumSlider")
        sl:SetPos(88, 0); sl:SetSize(w - 88, 22)
        sl:SetText(""); sl:SetMin(min); sl:SetMax(max)
        sl:SetDecimals(dec or 2); sl:SetValue(0)
        sl.OnValueChanged = function(_, val)
            if onChange then onChange(val) end
            self:ApplyLivePreview()
        end

        self._sliders[key] = sl
        y = y + 26
        return sl
    end

    local function Spacer(n) y = y + (n or 6) end

    -- Seed defaults
    local defaults = PS_GetItemDefault and PS_GetItemDefault(self.itemID) or {}
    local function seed(key, fallback)
        local v = defaults[key]; return (v ~= nil) and v or fallback
    end

    if self.itemType == "accessory" then
        local off = defaults.offset or {}
        local ang = defaults.ang    or {}

        SectionTitle("Position")
        Slider("Offset X", "offsetX", -30, 30, 2):SetValue(off[1] or off.x or seed("offsetX", 0))
        Slider("Offset Y", "offsetY", -30, 30, 2):SetValue(off[2] or off.y or seed("offsetY", 0))
        Slider("Offset Z", "offsetZ", -30, 30, 2):SetValue(off[3] or off.z or seed("offsetZ", 0))
        Spacer()
        SectionTitle("Rotation")
        Slider("Pitch", "pitch", -180, 180, 1):SetValue(ang[1] or seed("pitch", 0))
        Slider("Yaw",   "yaw",   -180, 180, 1):SetValue(ang[2] or seed("yaw",   0))
        Slider("Roll",  "roll",  -180, 180, 1):SetValue(ang[3] or seed("roll",  0))
        Spacer()
        SectionTitle("Scale")
        Slider("Scale", "scale", 0.1, 2, 2):SetValue(seed("scale", 1))
        Spacer()

        -- Bone selector
        SectionTitle("Bone")
        local bones = {
            { label = "Head",            bone = "ValveBiped.Bip01_Head1"      },
            { label = "Spine 4 (chest)", bone = "ValveBiped.Bip01_Spine4"     },
            { label = "Spine 2",         bone = "ValveBiped.Bip01_Spine2"     },
            { label = "Spine",           bone = "ValveBiped.Bip01_Spine"      },
            { label = "Pelvis",          bone = "ValveBiped.Bip01_Pelvis"     },
            { label = "Right Hand",      bone = "ValveBiped.Bip01_R_Hand"     },
            { label = "Left Hand",       bone = "ValveBiped.Bip01_L_Hand"     },
            { label = "Right Forearm",   bone = "ValveBiped.Bip01_R_Forearm"  },
            { label = "Left Forearm",    bone = "ValveBiped.Bip01_L_Forearm"  },
            { label = "Right Upper Arm", bone = "ValveBiped.Bip01_R_UpperArm" },
            { label = "Left Upper Arm",  bone = "ValveBiped.Bip01_L_UpperArm" },
            { label = "Right Foot",      bone = "ValveBiped.Bip01_R_Foot"     },
            { label = "Left Foot",       bone = "ValveBiped.Bip01_L_Foot"     },
        }

        -- Current bone: owner override → item Lua default
        local itemDef    = PS and PS.Items and PS.Items[self.itemID]
        local currentBone = defaults.bone or (itemDef and itemDef.Bone) or "ValveBiped.Bip01_Head1"

        local combo = self:Add("DComboBox")
        combo:SetPos(baseX, y); combo:SetSize(w, 24); combo:SetValue(currentBone)
        for _, entry in ipairs(bones) do
            combo:AddChoice(entry.label .. "  (" .. entry.bone .. ")", entry.bone)
            if entry.bone == currentBone then
                combo:SetValue(entry.label .. "  (" .. entry.bone .. ")")
            end
        end
        combo.OnSelect = function(_, _, _, boneStr)
            self._selectedBone = boneStr
        end
        self._selectedBone = currentBone
        self._boneCombo    = combo
        track(combo)
        y = y + 28

    elseif self.itemType == "playermodel" then
        SectionTitle("Skin")
        Slider("Skin", "skin", 0, 63, 0):SetValue(seed("skin", 0))
    end

    Spacer(8)
    SectionTitle("Camera")
    Slider("Rotation", "camRot",  0,   360, 1)
    Slider("Height",   "camY",   -100, 100, 1)
    Slider("Zoom",     "camZoom", 20,  300, 0):SetValue(self.orbitRadius)

    Spacer(10)

    -- Save button
    local saveBtn = self:Add("DButton")
    saveBtn:SetPos(baseX, y); saveBtn:SetSize(w, 26); saveBtn:SetText("")
    saveBtn.DoClick = function()
        local mods = self:CollectMods()
        net.Start("PS_ItemDefault_Set")
            net.WriteString(self.itemID)
            net.WriteTable(mods)
            net.WriteBool(false)
        net.SendToServer()
        self._originalMods = table.Copy(mods)
        notification.AddLegacy("Saved default for " .. self.itemID, NOTIFY_GENERIC, 3)
    end
    saveBtn.Paint = function(s, pw, ph)
        s._ha = Lerp(FrameTime() * 10, s._ha or 0, s:IsHovered() and 1 or 0)
        local b = 100 + s._ha * 25
        draw.RoundedBox(4, 0, 0, pw, ph, Color(b, b * 0.75, 20, 255))
        surface.SetDrawColor(180, 140, 30, 200); surface.DrawOutlinedRect(0, 0, pw, ph)
        draw.SimpleText("Save as Default", "DermaDefaultBold", pw/2, ph/2, Color(255, 230, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    track(saveBtn); y = y + 30

    -- Discard button
    local discardBtn = self:Add("DButton")
    discardBtn:SetPos(baseX, y); discardBtn:SetSize(w, 24); discardBtn:SetText("")
    discardBtn.DoClick = function()
        self:RestoreOriginal()
        self:Remove()
    end
    discardBtn.Paint = function(s, pw, ph)
        s._ha = Lerp(FrameTime() * 10, s._ha or 0, s:IsHovered() and 1 or 0)
        local g = 65 + s._ha * 15
        draw.RoundedBox(4, 0, 0, pw, ph, Color(g, g, g, 255))
        surface.SetDrawColor(120, 120, 120, 200); surface.DrawOutlinedRect(0, 0, pw, ph)
        draw.SimpleText("Discard", "DermaDefault", pw/2, ph/2, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    track(discardBtn); y = y + 28

    -- Clear button
    local clearBtn = self:Add("DButton")
    clearBtn:SetPos(baseX, y); clearBtn:SetSize(w, 24); clearBtn:SetText("")
    clearBtn.DoClick = function()
        net.Start("PS_ItemDefault_Set")
            net.WriteString(self.itemID)
            net.WriteTable({})
            net.WriteBool(true)
        net.SendToServer()
        notification.AddLegacy("Cleared default for " .. self.itemID, NOTIFY_GENERIC, 3)
    end
    clearBtn.Paint = function(s, pw, ph)
        s._ha = Lerp(FrameTime() * 10, s._ha or 0, s:IsHovered() and 1 or 0)
        local r = 100 + s._ha * 25
        draw.RoundedBox(4, 0, 0, pw, ph, Color(r, 35, 35, 255))
        surface.SetDrawColor(160, 70, 70, 200); surface.DrawOutlinedRect(0, 0, pw, ph)
        draw.SimpleText("Clear Default", "DermaDefault", pw/2, ph/2, Color(255, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    track(clearBtn); y = y + 28

    self:SetTall(y + 10)
    self:SetPos(ScrW() - self:GetWide() - 10, ScrH() / 2 - self:GetTall() / 2)

    -- Apply current slider state as initial live preview
    timer.Simple(0.05, function()
        if IsValid(self) then self:ApplyLivePreview() end
    end)
end

-- ============================================================================
-- COLLECT MODS FROM SLIDERS
-- ============================================================================

function PANEL:CollectMods()
    local sl = self._sliders or {}
    if self.itemType == "accessory" then
        return {
            offset = {
                sl.offsetX and sl.offsetX:GetValue() or 0,
                sl.offsetY and sl.offsetY:GetValue() or 0,
                sl.offsetZ and sl.offsetZ:GetValue() or 0,
            },
            ang = {
                sl.pitch and sl.pitch:GetValue() or 0,
                sl.yaw   and sl.yaw:GetValue()   or 0,
                sl.roll  and sl.roll:GetValue()   or 0,
            },
            scale = sl.scale and sl.scale:GetValue() or 1,
            bone  = self._selectedBone or nil,
        }
    elseif self.itemType == "playermodel" then
        return { skin = sl.skin and math.Round(sl.skin:GetValue()) or 0 }
    end
    return {}
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function PANEL:OnClose()
    hook.Remove("ShouldDrawLocalPlayer", "PSOwnerDefaults_DrawSelf")
    hook.Remove("CalcView", "PSOwnerDefaults_CalcView")
    self:RestoreOriginal()
end

-- ============================================================================
-- RENDERING
-- ============================================================================

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, Color(28, 28, 32, 255))
    surface.SetDrawColor(180, 140, 30, 120)
    surface.DrawOutlinedRect(0, 0, w, h)
    draw.RoundedBoxEx(6, 0, 0, w, 28, Color(40, 32, 10, 255), true, true, false, false)
    surface.SetDrawColor(180, 140, 30, 80)
    surface.DrawRect(0, 28, w, 1)
    draw.SimpleText("Edit Item Default  —  " .. (self.itemID or ""), "DermaDefaultBold",
        w / 2, 14, Color(220, 180, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("PSOwnerDefaultsPanel", PANEL, "DFrame")
