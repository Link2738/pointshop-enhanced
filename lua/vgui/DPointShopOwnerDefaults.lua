-- Owner-only panel for editing per-item server defaults.
-- Opened from the item dropdown ("Edit Default..."), visible to ULX "owner" group only.

local PANEL = {}

function PANEL:Init()
    self:SetTitle("")
    self:SetSize(380, 10)
    self:SetPos(ScrW() - 400, ScrH() / 2 - 200)
    self:MakePopup()
    self:SetDraggable(true)
    self:SetSizable(false)
    self:ShowCloseButton(true)
end

function PANEL:SetItem(item)
    if not item then return end
    self.itemID   = item.ID   or item.Model or ""
    self.itemType = item.TYPE or "accessory"

    -- Remove any previously built controls
    for _, c in ipairs(self._controls or {}) do
        if IsValid(c) then c:Remove() end
    end
    self._controls = {}
    self._sliders  = {}

    local baseX = 14
    local y     = 36
    local w     = self:GetWide() - 28

    local function track(c) self._controls[#self._controls + 1] = c end

    local function Title(txt)
        local lbl = self:Add("DLabel")
        lbl:SetPos(baseX, y)
        lbl:SetSize(w, 18)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetTextColor(Color(180, 140, 30))
        lbl:SetText(txt)
        track(lbl)
        y = y + 20
    end

    local function Slider(label, key, min, max, dec)
        local row = self:Add("DPanel")
        row:SetPos(baseX, y)
        row:SetSize(w, 22)
        row.Paint = function() end
        track(row)

        local lbl = row:Add("DLabel")
        lbl:SetPos(0, 0)
        lbl:SetSize(90, 22)
        lbl:SetText(label)
        lbl:SetTextColor(Color(200, 200, 200))

        local sl = row:Add("DNumSlider")
        sl:SetPos(88, 0)
        sl:SetSize(w - 88, 22)
        sl:SetText("")
        sl:SetMin(min)
        sl:SetMax(max)
        sl:SetDecimals(dec or 2)
        sl:SetValue(0)

        self._sliders[key] = sl
        y = y + 26
        return sl
    end

    local function Spacer(n)
        y = y + (n or 6)
    end

    -- Seed from current owner override → item Lua defaults
    local defaults = PS_GetItemDefault and PS_GetItemDefault(self.itemID) or {}

    local function seed(key, fallback)
        local v = defaults[key]
        return (v ~= nil) and v or fallback
    end

    if self.itemType == "accessory" then
        Title("Position")
        local off = defaults.offset or {}
        Slider("Offset X", "offsetX", -30, 30, 2):SetValue(off[1] or off.x or seed("offsetX", 0))
        Slider("Offset Y", "offsetY", -30, 30, 2):SetValue(off[2] or off.y or seed("offsetY", 0))
        Slider("Offset Z", "offsetZ", -30, 30, 2):SetValue(off[3] or off.z or seed("offsetZ", 0))
        Spacer()
        Title("Rotation")
        local ang = defaults.ang or {}
        Slider("Pitch", "pitch", -180, 180, 1):SetValue(ang[1] or seed("pitch", 0))
        Slider("Yaw",   "yaw",   -180, 180, 1):SetValue(ang[2] or seed("yaw",   0))
        Slider("Roll",  "roll",  -180, 180, 1):SetValue(ang[3] or seed("roll",  0))
        Spacer()
        Title("Scale")
        Slider("Scale", "scale", 0.1, 2, 2):SetValue(seed("scale", 1))
    elseif self.itemType == "playermodel" then
        Title("Skin")
        Slider("Skin", "skin", 0, 63, 0):SetValue(seed("skin", 0))
    end

    Spacer(8)

    -- Save button
    local saveBtn = self:Add("DButton")
    saveBtn:SetPos(baseX, y)
    saveBtn:SetSize(w, 26)
    saveBtn:SetText("")
    saveBtn.DoClick = function()
        local mods = self:CollectMods()
        net.Start("PS_ItemDefault_Set")
            net.WriteString(self.itemID)
            net.WriteTable(mods)
            net.WriteBool(false)
        net.SendToServer()
        notification.AddLegacy("Saved default for " .. self.itemID, NOTIFY_GENERIC, 3)
    end
    saveBtn.Paint = function(s, pw, ph)
        s._ha = Lerp(FrameTime() * 10, s._ha or 0, s:IsHovered() and 1 or 0)
        local b = 100 + s._ha * 25
        draw.RoundedBox(4, 0, 0, pw, ph, Color(b, b * 0.75, 20, 255))
        surface.SetDrawColor(180, 140, 30, 200); surface.DrawOutlinedRect(0, 0, pw, ph)
        draw.SimpleText("Save as Default", "DermaDefaultBold", pw/2, ph/2, Color(255, 230, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    track(saveBtn)
    y = y + 30

    -- Clear button
    local clearBtn = self:Add("DButton")
    clearBtn:SetPos(baseX, y)
    clearBtn:SetSize(w, 24)
    clearBtn:SetText("")
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
    track(clearBtn)
    y = y + 28

    self:SetTall(y + 10)
    self:SetPos(ScrW() - self:GetWide() - 10, ScrH() / 2 - self:GetTall() / 2)
end

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
        }
    elseif self.itemType == "playermodel" then
        return { skin = sl.skin and math.Round(sl.skin:GetValue()) or 0 }
    end
    return {}
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, Color(28, 28, 32, 255))
    surface.SetDrawColor(180, 140, 30, 120)
    surface.DrawOutlinedRect(0, 0, w, h)
    -- Title bar
    draw.RoundedBoxEx(6, 0, 0, w, 28, Color(40, 32, 10, 255), true, true, false, false)
    surface.SetDrawColor(180, 140, 30, 80)
    surface.DrawRect(0, 28, w, 1)
    draw.SimpleText("Edit Item Default", "DermaDefaultBold", w / 2, 14, Color(220, 180, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("PSOwnerDefaultsPanel", PANEL, "DFrame")
