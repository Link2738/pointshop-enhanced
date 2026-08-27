-- DPointShopCustomPanels: Contains both ColorChooser and BodygroupSelector panels

-- DPointShopColorChooser
local COLOR_PANEL = {}

function COLOR_PANEL:Init()
    self:SetTitle("PointShop Color Chooser")
    self:SetSize(300, 300)
    self:SetBackgroundBlur(true)
    self:SetDrawOnTop(true)
    self.colorpicker = vgui.Create('DColorMixer', self)
    self.colorpicker:Dock(FILL)
    local done = vgui.Create('DButton', self)
    done:DockMargin(0, 5, 0, 0)
    done:Dock(BOTTOM)
    done:SetText('Done')
    done.DoClick = function()
        self.OnChoose(self.colorpicker:GetColor())
        self:Close()
    end
    self:Center()
    self:Show()
end

function COLOR_PANEL:OnChoose(color)
    -- nothing, gets over-ridden
end

function COLOR_PANEL:SetColor(color)
    self.colorpicker:SetColor(color or Color(255, 255, 255, 255))
end

vgui.Register('DPointShopColorChooser', COLOR_PANEL, 'DFrame')

-- DPointShopBodygroupSelector
local BODYGROUP_PANEL = {}

function BODYGROUP_PANEL:Init()
    self:SetSize(400, 350)
    self:Center()
    self:MakePopup()
    self:SetTitle('Bodygroup Selector')
    self:DockPadding(0, 24, 0, 0)
    self.ModelPanel = self:Add('DModelPanel')
    self.ModelPanel:Dock(LEFT)
    self.ModelPanel:SetWide(220)
    self.ModelPanel:SetFOV(45)
    self.Scroll = self:Add('DScrollPanel')
    self.Scroll:Dock(FILL)
    self.Submit = self:Add('DButton')
    self.Submit:Dock(BOTTOM)
    self.Submit:DockMargin(4, 4, 4, 4)
    self.Submit:SetText('Submit')
end

function BODYGROUP_PANEL:SetItem(item, modifications)
    self:SetTitle('Modify ' .. (item.Name or 'Model'))
    if not item.Model or not util.IsValidModel(item.Model) then
        self.ModelPanel:SetModel('models/error.mdl')
        self.Scroll:Clear()
        self.Submit:SetDisabled(true)
        return
    end
    self.ModelPanel:SetModel(item.Model)
    self.Mods = table.Copy(modifications or {})
    local ent = self.ModelPanel.Entity
    self.Sliders = {}
    if not istable(item.Bodygroups) then
        self.Scroll:Clear()
        self.Submit:SetDisabled(true)
        return
    end
    local validBodygroup = false
    for name, bg in pairs(item.Bodygroups) do
        if type(bg.id) == 'number' and istable(bg.values) and #bg.values >= 1 and ent:GetBodygroup(bg.id) then
            validBodygroup = true
            local panel = self.Scroll:Add('DPanel')
            panel:Dock(TOP)
            panel:SetTall(48)
            panel.Paint = function(this, w, h)
                draw.SimpleText(name, 'PS_DefaultBold', w/2, 8, color_white, TEXT_ALIGN_CENTER)
            end
            local slider = panel:Add('DNumSlider')
            slider:Dock(BOTTOM)
            slider.Label:Hide()
            slider:SetMin(1)
            slider:SetMax(#bg.values)
            slider:SetDecimals(0)
            local val = self.Mods[name] or bg.values[1]
            local idx = 1
            for i, v in ipairs(bg.values) do
                if v == val then idx = i break end
            end
            slider:SetValue(idx)
            slider.OnValueChanged = function(s, v)
                local idx = math.Round(v)
                if idx < 1 or idx > #bg.values then return end
                local bgval = bg.values[idx]
                ent:SetBodygroup(bg.id, bgval)
                self.Mods[name] = bgval
                if ConVarExists("ps_debug") and GetConVar("ps_debug"):GetBool() then
                    print("[BodygroupSelector] Slider changed:", name, "id:", bg.id, "value:", bgval)
                end
            end
            self.Sliders[name] = slider
        end
    end
    self.Submit:SetDisabled(not validBodygroup)
    self.Submit.DoClick = function()
        if ConVarExists("ps_debug") and GetConVar("ps_debug"):GetBool() then
            print("[BodygroupSelector] Submit pressed. Mods:", util.TableToJSON(self.Mods))
        end
        if self.OnSubmit then self:OnSubmit(self.Mods) end
        self:Close()
    end
end

vgui.Register('DPointShopBodygroupSelector', BODYGROUP_PANEL, 'DFrame')
