-- Unified Item Customization Panel
-- Handles both accessories and playermodels with type detection
-- Uses in-world dummy preview for both types

local PANEL = {}

-- Global table to store pending saved data that arrives before panel is created
PS_PendingCustomizationData = PS_PendingCustomizationData or {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Sanitize incoming customization data for safety
local function SanitizeCustomizationData(mods, itemType)
    if not mods or type(mods) ~= "table" then return {} end
    
    local sanitized = {}
    
    if itemType == "accessory" then
        -- Sanitize accessory data
        -- Scale: 0.1 to 2
        if mods.scale then
            sanitized.scale = math.Clamp(tonumber(mods.scale) or 1, 0.1, 2)
        end
        
        -- Rotation: 0 to 360
        if mods.rotation then
            sanitized.rotation = math.Clamp(tonumber(mods.rotation) or 0, 0, 360)
        end
        
        -- Offset: -30 to 30 for each axis
        if mods.offset and type(mods.offset) == "table" then
            sanitized.offset = {
                math.Clamp(tonumber(mods.offset[1] or mods.offset.x) or 0, -30, 30),
                math.Clamp(tonumber(mods.offset[2] or mods.offset.y) or 0, -30, 30),
                math.Clamp(tonumber(mods.offset[3] or mods.offset.z) or 0, -30, 30)
            }
        end
        
        -- Axis: must be valid string
        if mods.axis and type(mods.axis) == "string" then
            local validAxes = {Right = true, Up = true, Forward = true}
            sanitized.axis = validAxes[mods.axis] and mods.axis or "Right"
        end
        
        -- Axis degrees: -180 to 180
        if mods.axisDeg then
            sanitized.axisDeg = math.Clamp(tonumber(mods.axisDeg) or -90, -180, 180)
        end
        
        -- Angle table: -180 to 180 for each component
        if mods.ang and type(mods.ang) == "table" then
            sanitized.ang = {
                math.Clamp(tonumber(mods.ang[1]) or 0, -180, 180),
                math.Clamp(tonumber(mods.ang[2]) or 0, -180, 180),
                math.Clamp(tonumber(mods.ang[3]) or 0, -180, 180)
            }
        end
        
        -- Color: 0 to 255 for RGBA
        if mods.color and type(mods.color) == "table" then
            sanitized.color = {
                r = math.Clamp(tonumber(mods.color.r or mods.color[1]) or 255, 0, 255),
                g = math.Clamp(tonumber(mods.color.g or mods.color[2]) or 255, 0, 255),
                b = math.Clamp(tonumber(mods.color.b or mods.color[3]) or 255, 0, 255),
                a = math.Clamp(tonumber(mods.color.a or mods.color[4]) or 255, 0, 255)
            }
        end
        
    elseif itemType == "playermodel" then
        -- Sanitize playermodel data
        -- Skin: 0 to 255 (most models have far fewer, but this is a safe upper bound)
        if mods.skin then
            sanitized.skin = math.Clamp(math.Round(tonumber(mods.skin) or 0), 0, 255)
        end
        
        -- Bodygroups: validate IDs and values
        if mods.bodygroups and type(mods.bodygroups) == "table" then
            sanitized.bodygroups = {}
            for bgID, bgValue in pairs(mods.bodygroups) do
                local id = tonumber(bgID)
                local val = tonumber(bgValue)
                if id and val and id >= 0 and id < 32 and val >= 0 and val < 16 then
                    sanitized.bodygroups[id] = math.floor(val)
                end
            end
        end
        
        -- Player color: 0 to 255 for RGB
        if mods.playercolor and type(mods.playercolor) == "table" then
            sanitized.playercolor = {
                math.Clamp(tonumber(mods.playercolor[1] or mods.playercolor.r) or 255, 0, 255),
                math.Clamp(tonumber(mods.playercolor[2] or mods.playercolor.g) or 255, 0, 255),
                math.Clamp(tonumber(mods.playercolor[3] or mods.playercolor.b) or 255, 0, 255)
            }
        end
    elseif itemType == "trail" then
        -- Sanitize trail data (color only)
        if mods.color and type(mods.color) == "table" then
            sanitized.color = {
                r = math.Clamp(tonumber(mods.color.r or mods.color[1]) or 255, 0, 255),
                g = math.Clamp(tonumber(mods.color.g or mods.color[2]) or 255, 0, 255),
                b = math.Clamp(tonumber(mods.color.b or mods.color[3]) or 255, 0, 255),
                a = math.Clamp(tonumber(mods.color.a or mods.color[4]) or 255, 0, 255)
            }
        end
    end
    
    return sanitized
end

-- Get current slider values based on item type
function PANEL:GetSliderValues()
    if self.itemType == "accessory" then
        -- Accessories: position/scale/rotation data
        local axis = (self.rotateAxisCombo and self.rotateAxisCombo:GetValue()) or "Right"
        local rawAxisDeg = self.axisDegSlider and self.axisDegSlider:GetValue()
        local axisDeg = math.Clamp(tonumber(rawAxisDeg) or -90, -180, 180)
        
        if PS and PS.Config and PS.Config.Debug then
            print("[PS GETVALS] axis=" .. tostring(axis) .. " rawAxisDeg=" .. tostring(rawAxisDeg) .. " (" .. type(rawAxisDeg) .. ") -> axisDeg=" .. tostring(axisDeg))
        end
        
        local angTable = {0, 0, 0}
        if axis == "Right" then
            angTable[1] = axisDeg
        elseif axis == "Up" then
            angTable[2] = axisDeg
        elseif axis == "Forward" then
            angTable[3] = axisDeg
        end

        local result = {
            scale = math.Clamp(self.scaleSlider and self.scaleSlider:GetValue() or 1, 0.1, 2),
            rotation = math.Clamp(self.rotationSlider and self.rotationSlider:GetValue() or 0, 0, 360),
            offset = {
                math.Clamp(self.offsetXSlider and self.offsetXSlider:GetValue() or 0, -30, 30),
                math.Clamp(self.offsetYSlider and self.offsetYSlider:GetValue() or 0, -30, 30),
                math.Clamp(self.offsetZSlider and self.offsetZSlider:GetValue() or 0, -30, 30)
            },
            ang = angTable,
            axis = axis,
            axisDeg = axisDeg
        }
        
        -- Add color if color mixer exists
        if self.accessoryColorMixer then
            local col = self.accessoryColorMixer:GetColor()
            result.color = {r = col.r, g = col.g, b = col.b, a = col.a}
        end
        
        return result
    elseif self.itemType == "playermodel" then
        -- Playermodels: bodygroup/skin/color data
        local mods = {
            skin = self.skinSlider and math.Round(self.skinSlider:GetValue()) or 0,
            bodygroups = {},
            playercolor = nil
        }
        
        if self._bodygroupValues then
            for bgID, value in pairs(self._bodygroupValues) do
                mods.bodygroups[bgID] = value
            end
        end
        
        if self.colorMixer then
            local col = self.colorMixer:GetColor()
            mods.playercolor = {col.r, col.g, col.b}
            
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS PANEL] Playercolor from mixer: R=%d G=%d B=%d", col.r, col.g, col.b))
            end
        end
        
        return mods
    elseif self.itemType == "trail" then
        -- Trails: just color data
        local result = {}
        if self.trailColorMixer then
            local col = self.trailColorMixer:GetColor()
            result.color = {r = col.r, g = col.g, b = col.b, a = col.a}
        end
        return result
    end
    
    return {}
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function PANEL:Init()
    -- DEBUG: Show which file is loading
    if PS and PS.Config and PS.Config.Debug then
        local info = debug.getinfo(1, "S")
        if info and info.source then
            print("[PS UNIFIED PANEL] Loading from: " .. info.source)
            print("[PS UNIFIED PANEL] Version: v2.0_Unified_Feb9_2026")
        end
    end
    
    self:SetTitle("")
    self:SetSize(450, 400)
    self:SetMinWidth(340)
    self:SetMinHeight(350)
    self:SetPos(10, ScrH() / 2 - 200)
    self:MakePopup()
    self:SetMouseInputEnabled(true)
    self:SetKeyBoardInputEnabled(true)
    
    self.orbitRadius = 60
    self.orbitPhi = math.pi / 2
    self.previewEnabled = false
    
    -- Type-specific controls will be created in SetItem()
    self:SetupHooks()
end

function PANEL:SetupHooks()
    -- Third-person camera hook
    hook.Add("ShouldDrawLocalPlayer", "PSItemCustomizationPanel_ShouldDrawLocalPlayer", function()
        return IsValid(self) and self:IsVisible()
    end)

    hook.Add("CalcView", "PSItemCustomizationPanel_CalcView", function(ply, pos, angles, fov)
        if not (IsValid(self) and self:IsVisible()) then return end
        if ply ~= LocalPlayer() or not ply:Alive() then return end
        
        local rotDeg = (self.cameraRotationSlider and self.cameraRotationSlider:GetValue()) or 0
        local yOffset = (self.cameraYSlider and self.cameraYSlider:GetValue()) or 0
        local radius = (self.cameraZoomSlider and self.cameraZoomSlider:GetValue()) or self.orbitRadius
        
        local theta = math.rad(rotDeg)
        local target = ply:GetPos() + Vector(0, 0, 64 + yOffset)
        local x = radius * math.sin(self.orbitPhi) * math.cos(theta)
        local y = radius * math.sin(self.orbitPhi) * math.sin(theta)
        local z = radius * math.cos(self.orbitPhi)
        
        local view = {}
        view.origin = target + Vector(x, y, z)
        view.angles = (target - view.origin):Angle()
        view.fov = fov
        view.drawviewer = true
        return view
    end)
end

-- ============================================================================
-- ACCESSORY-SPECIFIC UI
-- ============================================================================

function PANEL:CreateAccessorySliders()
    local sliderW = math.max(150, self:GetWide() - 90)
    local sliderH = 24
    local baseX, y = 20, 40
    
    -- Helper function to create slider+box pair
    local function CreateSliderPair(parent, label, min, max, default, decimals)
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS PANEL DEBUG] CreateSliderPair: %s | min=%s max=%s default=%s", 
                label, tostring(min), tostring(max), tostring(default)))
        end
        
        local slider = parent:Add("DNumSlider")
        slider:SetText(label)
        slider:SetDecimals(decimals or 2)
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetValue(default)
        slider:SetPos(baseX, y)
        slider:SetSize(sliderW - 60, sliderH)
        
        local box = parent:Add("DNumberWang")
        box:SetDecimals(decimals or 2)
        box:SetMin(min)
        box:SetMax(max)
        box:SetValue(default)
        box:SetSize(50, sliderH)
        box:SetPos(baseX + sliderW - 50, y)
        box:SetMouseInputEnabled(true)
        box:SetKeyboardInputEnabled(true)
        
        -- Mouse wheel support
        box.OnMouseWheeled = function(_, delta)
            if not IsValid(box) then return true end
            local step = (decimals and decimals > 0) and (1 / (10 ^ decimals)) or 1
            box:SetValue((tonumber(box:GetValue()) or 0) + (tonumber(delta) or 0) * step)
            if box.OnValueChanged then box.OnValueChanged(box, box:GetValue()) end
            return true
        end
        
        -- Sync box to slider
        box.OnValueChanged = function(_, val)
            if not IsValid(parent) then return end
            if parent._resetting or parent._syncing then return end
            parent._syncing = true
            local ok, err = pcall(function()
                local v = tonumber(val) or 0
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS SYNC] %s box->slider: val=%s parsed=%s", label, tostring(val), tostring(v)))
                end
                slider:SetValue(v)
                if parent.previewEnabled then parent:ApplyLivePreview() end
            end)
            parent._syncing = false
            if not ok then print("[PS SYNC ERROR] " .. label .. " box->slider: " .. tostring(err)) end
        end
        
        -- Sync slider to box
        slider.OnValueChanged = function(_, val)
            if not IsValid(parent) then return end
            if parent._resetting or parent._syncing then return end
            parent._syncing = true
            local ok, err = pcall(function()
                local v = tonumber(val) or 0
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS SYNC] %s slider->box: val=%s parsed=%s", label, tostring(val), tostring(v)))
                end
                if box and IsValid(box) and box.SetValue then box:SetValue(v) end
                if parent.previewEnabled then parent:ApplyLivePreview() end
            end)
            parent._syncing = false
            if not ok then print("[PS SYNC ERROR] " .. label .. " slider->box: " .. tostring(err)) end
        end
        
        -- Enable preview on interaction
        slider.OnMousePressed = function()
            if IsValid(parent) then
                parent.previewEnabled = true
                parent:ApplyLivePreview()
            end
        end
        
        y = y + sliderH
        return slider, box
    end
    
    -- Create offset sliders
    self.offsetXSlider, self.offsetXBox = CreateSliderPair(self, "Offset X", -30, 30, 0, 2)
    self.offsetYSlider, self.offsetYBox = CreateSliderPair(self, "Offset Y", -30, 30, 0, 2)
    self.offsetZSlider, self.offsetZBox = CreateSliderPair(self, "Offset Z", -30, 30, 0, 2)
    
    y = y + 8
    
    -- Axis combo box
    self.rotateAxisCombo = self:Add("DComboBox")
    self.rotateAxisCombo:SetPos(baseX, y)
    self.rotateAxisCombo:SetSize(sliderW - 60, sliderH)
    self.rotateAxisCombo:SetValue("Right")
    self.rotateAxisCombo:AddChoice("Right")
    self.rotateAxisCombo:AddChoice("Up")
    self.rotateAxisCombo:AddChoice("Forward")
    self.rotateAxisCombo.OnSelect = function(_, index, value)
        if IsValid(self) then
            self.previewEnabled = true
            self:ApplyLivePreview()
        end
    end
    y = y + sliderH
    
    -- Axis rotation slider
    self.axisDegSlider, self.axisDegBox = CreateSliderPair(self, "Axis Rotation", -180, 180, -90, 1)
    
    y = y + 8
    
    -- Scale slider
    self.scaleSlider, self.scaleBox = CreateSliderPair(self, "Scale", 0.1, 2, 1, 2)
    
    y = y + 8
    
    -- Color picker for accessories
    local colorLabel = self:Add("DLabel")
    colorLabel:SetText("Model Color:")
    colorLabel:SetPos(baseX, y)
    colorLabel:SetSize(sliderW - 60, 20)
    y = y + 22
    
    self.accessoryColorMixer = self:Add("DColorMixer")
    self.accessoryColorMixer:SetPos(baseX, y)
    self.accessoryColorMixer:SetSize(sliderW - 60, 150)
    self.accessoryColorMixer:SetPalette(true)
    self.accessoryColorMixer:SetAlphaBar(true)
    self.accessoryColorMixer:SetWangs(true)
    self.accessoryColorMixer:SetColor(Color(255, 255, 255, 255))
    self.accessoryColorMixer.ValueChanged = function(_, col)
        if not IsValid(self) then return end
        self.previewEnabled = true
        self:ApplyLivePreview()
    end
    y = y + 155
    
    y = y + 8
    
    -- Legacy yaw rotation
    self.rotationSlider, self.rotationBox = CreateSliderPair(self, "Legacy Yaw", 0, 360, 0, 0)
    
    y = y + 8
    
    -- Camera controls (don't trigger preview)
    self.cameraRotationSlider, self.cameraRotationBox = CreateSliderPair(self, "Camera Rotation", 0, 360, 0, 1)
    self.cameraRotationSlider.OnMousePressed = nil
    self.cameraRotationBox.OnValueChanged = function(_, val)
        if not IsValid(self) then return end
        val = tonumber(val) or 0
        if math.abs((tonumber(self.cameraRotationSlider:GetValue()) or 0) - val) > 1e-6 then 
            self.cameraRotationSlider:SetValue(val)
        end
    end
    
    self.cameraYSlider, self.cameraYBox = CreateSliderPair(self, "Camera Y", -100, 100, 0, 1)
    self.cameraYSlider.OnMousePressed = nil
    self.cameraYBox.OnValueChanged = function(_, val)
        if not IsValid(self) then return end
        val = tonumber(val) or 0
        if math.abs((tonumber(self.cameraYSlider:GetValue()) or 0) - val) > 1e-6 then 
            self.cameraYSlider:SetValue(val)
        end
    end
    
    y = y + 8
    
    self.cameraZoomSlider, self.cameraZoomBox = CreateSliderPair(self, "Camera Zoom", 20, 300, self.orbitRadius, 0)
    self.cameraZoomSlider.OnMousePressed = nil
    self.cameraZoomBox.OnValueChanged = function(_, val)
        if not IsValid(self) then return end
        val = tonumber(val) or 0
        if math.abs((tonumber(self.cameraZoomSlider:GetValue()) or 0) - val) > 1e-6 then 
            self.cameraZoomSlider:SetValue(val)
        end
    end
    
    -- Store Y position for buttons
    self._controlsEndY = y + 32
    
    -- Disable all controls initially (waiting for server data)
    self:SetControlsEnabled(false)
end

-- ============================================================================
-- PLAYERMODEL-SPECIFIC UI
-- ============================================================================

function PANEL:CreatePlayermodelControls()
    local baseX, y = 20, 40
    local w = self:GetWide() - 40
    
    -- Color mixer
    local colorLabel = self:Add("DLabel")
    colorLabel:SetText("Player Color")
    colorLabel:SetPos(baseX, y)
    colorLabel:SetSize(w, 20)
    y = y + 20
    
    self.colorMixer = self:Add("DColorMixer")
    self.colorMixer:SetPos(baseX, y)
    self.colorMixer:SetSize(w, 120)
    self.colorMixer:SetPalette(true)
    self.colorMixer:SetAlphaBar(false)
    self.colorMixer:SetWangs(true)
    self.colorMixer:SetColor(Color(255, 255, 255))
    self.colorMixer.ValueChanged = function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            local col = self.colorMixer:GetColor()
            
            -- Check if this item uses Color2Proxy
            local useColor2 = false
            if self.itemID and PS.Items and PS.Items[self.itemID] then
                useColor2 = PS.Items[self.itemID].UseColor2Proxy or false
            end
            
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS COLOR DEBUG] PREVIEW colorMixer -> R=%d G=%d B=%d useColor2=%s itemID=%s", col.r, col.g, col.b, tostring(useColor2), tostring(self.itemID)))
            end
            if useColor2 then
                -- Clear any leftover render modulation from a previously equipped modulation model
                ply:SetColor(Color(255, 255, 255, 255))
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS COLOR DEBUG] PREVIEW Calling SetPlayerColor(%.3f, %.3f, %.3f)", col.r/255, col.g/255, col.b/255))
                end
                ply:SetPlayerColor(Vector(col.r / 255, col.g / 255, col.b / 255))
                ply:SetRenderMode(RENDERMODE_NORMAL)
            else
                -- Use SetColor for render modulation
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS COLOR DEBUG] PREVIEW Calling SetColor(%d, %d, %d)", col.r, col.g, col.b))
                end
                ply:SetColor(Color(col.r, col.g, col.b, 255))
                ply:SetRenderMode(RENDERMODE_NORMAL)
                -- Reset player color so it doesn't interfere
                if PS and PS.Config and PS.Config.Debug then
                    print("[PS COLOR DEBUG] PREVIEW Resetting SetPlayerColor to white (was modulation path)")
                end
                ply:SetPlayerColor(Vector(1, 1, 1))
            end
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS COLOR DEBUG] PREVIEW After apply -> GetColor=%s GetPlayerColor=%s", tostring(ply:GetColor()), tostring(ply:GetPlayerColor())))
            end
            
            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS PREVIEW] Color changed: R=%d G=%d B=%d UseColor2=%s", 
                    col.r, col.g, col.b, tostring(useColor2)))
            end
            
            -- Send to server for authoritative update
            if PS_SendPreviewUpdate then
                PS_SendPreviewUpdate(self.itemType, "playercolor", col.r, col.g, col.b)
            end
        end
    end
    y = y + 130
    
    -- Scrollable area for bodygroups and skin
    local scrollPanel = self:Add("DScrollPanel")
    scrollPanel:SetPos(baseX, y)
    scrollPanel:SetSize(w, 200)
    self.bodygroupScroll = scrollPanel
    
    local scrollY = 0
    
    -- Skin slider
    local skinLabel = scrollPanel:Add("DLabel")
    skinLabel:SetText("Skin")
    skinLabel:SetPos(5, scrollY)
    skinLabel:SetSize(w - 10, 20)
    scrollY = scrollY + 20
    
    self.skinSlider = scrollPanel:Add("DNumSlider")
    self.skinSlider:SetPos(5, scrollY)
    self.skinSlider:SetSize(w - 10, 24)
    self.skinSlider:SetText("")
    self.skinSlider:SetMin(0)
    self.skinSlider:SetMax(0)
    self.skinSlider:SetDecimals(0)
    self.skinSlider:SetValue(0)
    self.skinSlider.OnValueChanged = function(_, val)
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:SetSkin(math.Round(val))
            
            -- Send to server for authoritative update
            if PS_SendPreviewUpdate then
                PS_SendPreviewUpdate(self.itemType, "skin", math.Round(val))
            end
        end
    end
    scrollY = scrollY + 30
    
    -- Bodygroup buttons will be created dynamically in SetItem()
    self.bodygroupButtons = {}
    self._bodygroupValues = {}
    self._bodygroupScrollY = scrollY
    
    y = y + 210
    
    -- Camera controls
    self.cameraRotationSlider = self:Add("DNumSlider")
    self.cameraRotationSlider:SetText("Camera Rotation")
    self.cameraRotationSlider:SetPos(baseX, y)
    self.cameraRotationSlider:SetSize(w, 24)
    self.cameraRotationSlider:SetMin(0)
    self.cameraRotationSlider:SetMax(360)
    self.cameraRotationSlider:SetDecimals(1)
    self.cameraRotationSlider:SetValue(0)
    y = y + 30
    
    self.cameraYSlider = self:Add("DNumSlider")
    self.cameraYSlider:SetText("Camera Y")
    self.cameraYSlider:SetPos(baseX, y)
    self.cameraYSlider:SetSize(w, 24)
    self.cameraYSlider:SetMin(-100)
    self.cameraYSlider:SetMax(100)
    self.cameraYSlider:SetDecimals(1)
    self.cameraYSlider:SetValue(0)
    y = y + 30
    
    self.cameraZoomSlider = self:Add("DNumSlider")
    self.cameraZoomSlider:SetText("Camera Zoom")
    self.cameraZoomSlider:SetPos(baseX, y)
    self.cameraZoomSlider:SetSize(w, 24)
    self.cameraZoomSlider:SetMin(20)
    self.cameraZoomSlider:SetMax(300)
    self.cameraZoomSlider:SetDecimals(0)
    self.cameraZoomSlider:SetValue(self.orbitRadius)
    y = y + 35
    
    -- Store Y position for buttons
    self._controlsEndY = y
    
    -- Disable all controls initially (waiting for server data)
    self:SetControlsEnabled(false)
end

function PANEL:CreateBodygroupButtons()
    if not self.bodygroupScroll then return end
    
    -- For playermodels, use the real player
    local ent = LocalPlayer()
    if not IsValid(ent) then return end
    
    -- Update skin slider max from the entity's actual skin count
    if self.skinSlider then
        local skinMax = ent:SkinCount() - 1
        -- Also check ITEM.SkinCount as a fallback / override
        if self._itemSkinCount and self._itemSkinCount > 0 then
            skinMax = math.max(skinMax, self._itemSkinCount - 1)
        end
        if skinMax < 0 then skinMax = 0 end
        self.skinSlider:SetMax(skinMax)
    end
    
    -- Clear existing bodygroup controls
    if self.bodygroupButtons then
        for _, buttonGroup in pairs(self.bodygroupButtons) do
            for _, btn in pairs(buttonGroup) do
                if IsValid(btn) then btn:Remove() end
            end
        end
    end
    self.bodygroupButtons = {}
    self._bodygroupValues = {}
    
    local scrollY = self._bodygroupScrollY or 60
    local w = self.bodygroupScroll:GetWide() - 10
    
    -- Create buttons for each bodygroup
    for bgID = 0, ent:GetNumBodyGroups() - 1 do
        local count = ent:GetBodygroupCount(bgID)
        if count > 1 then
            local name = ent:GetBodygroupName(bgID)
            
            local label = self.bodygroupScroll:Add("DLabel")
            label:SetText(name)
            label:SetPos(5, scrollY)
            label:SetSize(w, 20)
            scrollY = scrollY + 20
            
            self.bodygroupButtons[bgID] = {}
            self._bodygroupValues[bgID] = 0
            
            -- Create a button for each value
            local buttonWidth = (w - 5 * (count - 1)) / count
            for val = 0, count - 1 do
                local btn = self.bodygroupScroll:Add("DButton")
                btn:SetText(tostring(val))
                btn:SetPos(5 + (buttonWidth + 5) * val, scrollY)
                btn:SetSize(buttonWidth, 25)
                
                btn.DoClick = function()
                    -- Update stored value
                    self._bodygroupValues[bgID] = val
                    
                    -- Apply to player immediately
                    local ply = LocalPlayer()
                    if IsValid(ply) then
                        ply:SetBodygroup(bgID, val)
                        
                        -- Force visual refresh
                        ply:InvalidateBoneCache()
                        ply:SetupBones()
                    end
                    
                    -- Send to server for authoritative update
                    if PS_SendPreviewUpdate then
                        PS_SendPreviewUpdate(self.itemType, "bodygroup", bgID, val)
                    end
                    
                    -- Update button visuals
                    self:UpdateBodygroupButtonVisuals(bgID)
                    
                    if PS and PS.Config and PS.Config.Debug then
                        print(string.format("[PS PANEL DEBUG] Button click: Set bodygroup %d to %d (result: %d)", 
                            bgID, val, ply:GetBodygroup(bgID)))
                    end
                end
                
                btn.Paint = function(panel, w, h)
                    local isSelected = self._bodygroupValues[bgID] == val
                    local isHovered = panel:IsHovered()
                    
                    -- Smooth color transitions
                    panel._hoverAlpha = panel._hoverAlpha or 0
                    panel._hoverAlpha = Lerp(FrameTime() * 8, panel._hoverAlpha, isHovered and 1 or 0)
                    
                    if isSelected then
                        -- Selected button: blue gradient
                        draw.RoundedBox(4, 0, 0, w, h, Color(80, 130, 220, 255))
                        draw.RoundedBox(4, 0, 0, w, h/2, Color(100, 150, 255, 80))
                        
                        -- Glow effect
                        surface.SetDrawColor(100, 150, 255, 50 + panel._hoverAlpha * 50)
                        surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
                    else
                        -- Unselected button: dark gradient
                        local baseCol = 50 + panel._hoverAlpha * 20
                        draw.RoundedBox(4, 0, 0, w, h, Color(baseCol, baseCol, baseCol + 5, 255))
                        draw.RoundedBox(4, 0, 0, w, h/2, Color(baseCol + 20, baseCol + 20, baseCol + 25, 50))
                    end
                    
                    -- Border
                    local borderCol = isSelected and Color(120, 170, 255, 200) or Color(100, 100, 110, 150 + panel._hoverAlpha * 100)
                    surface.SetDrawColor(borderCol)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
                
                self.bodygroupButtons[bgID][val] = btn
            end
            
            scrollY = scrollY + 30
        end
    end
    
    if PS and PS.Config and PS.Config.Debug then
        print(string.format("[PS PANEL DEBUG] Created button groups for %d bodygroups", table.Count(self.bodygroupButtons)))
    end
    
    -- Check for pending saved data (data that arrived before panel was created)
    local pendingKey = self.itemType .. "_" .. self.itemID
    local mods = self._pendingSavedData or PS_PendingCustomizationData[pendingKey]
    
    if mods then
        if PS and PS.Config and PS.Config.Debug then
            print("[PS PANEL DEBUG] Applying pending saved data to newly created buttons")
            print("  Source:", self._pendingSavedData and "panel-local" or "global")
        end
        
        -- Clear both sources
        self._pendingSavedData = nil
        PS_PendingCustomizationData[pendingKey] = nil
        
        -- Apply skin
        if mods.skin and self.skinSlider then
            self.skinSlider:SetValue(mods.skin)
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:SetSkin(mods.skin)
                if PS_SendPreviewUpdate then
                    PS_SendPreviewUpdate(self.itemType, "skin", mods.skin)
                end
            end
        end
        
        -- Apply bodygroups
        if mods.bodygroups then
            for bgID, bgValue in pairs(mods.bodygroups) do
                self._bodygroupValues[bgID] = bgValue
                local ply = LocalPlayer()
                if IsValid(ply) then
                    ply:SetBodygroup(bgID, bgValue)
                    ply:InvalidateBoneCache()
                    ply:SetupBones()
                    if PS_SendPreviewUpdate then
                        PS_SendPreviewUpdate(self.itemType, "bodygroup", bgID, bgValue)
                    end
                end
                self:UpdateBodygroupButtonVisuals(bgID)
            end
        end
        
        -- Apply player color
        if mods.playercolor and self.colorMixer then
            local pc = mods.playercolor
            self.colorMixer:SetColor(Color(
                pc[1] or pc.r or 255,
                pc[2] or pc.g or 255,
                pc[3] or pc.b or 255
            ))
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:SetPlayerColor(Vector(
                    (pc[1] or pc.r or 255) / 255,
                    (pc[2] or pc.g or 255) / 255,
                    (pc[3] or pc.b or 255) / 255
                ))
                if PS_SendPreviewUpdate then
                    PS_SendPreviewUpdate(self.itemType, "playercolor", 
                        pc[1] or pc.r or 255,
                        pc[2] or pc.g or 255,
                        pc[3] or pc.b or 255
                    )
                end
            end
        end
    end
end

function PANEL:UpdateBodygroupButtonVisuals(bgID)
    if not self.bodygroupButtons or not self.bodygroupButtons[bgID] then return end
    
    -- Just trigger a repaint - the Paint function checks _bodygroupValues
    for _, btn in pairs(self.bodygroupButtons[bgID]) do
        if IsValid(btn) then
            btn:InvalidateLayout(true)
        end
    end
end

-- ============================================================================
-- BUTTONS
-- ============================================================================

function PANEL:CreateButtons()
    local sliderW = math.max(150, self:GetWide() - 90)
    local baseX = 20
    local y = self._controlsEndY or 450
    
    -- Apply button
    self.applyButton = self:Add("DButton")
    self.applyButton:SetText("")
    self.applyButton:SetSize(sliderW - 60, 28)
    self.applyButton:SetPos(baseX, y)
    self.applyButton.DoClick = function()
        self:ApplyCustomization()
    end
    self.applyButton.Paint = function(panel, w, h)
        local isHovered = panel:IsHovered()
        panel._hoverAlpha = panel._hoverAlpha or 0
        panel._hoverAlpha = Lerp(FrameTime() * 10, panel._hoverAlpha, isHovered and 1 or 0)
        
        -- Green gradient background
        local baseGreen = 80 + panel._hoverAlpha * 30
        draw.RoundedBox(6, 0, 0, w, h, Color(40, baseGreen, 50, 255))
        draw.RoundedBox(6, 0, 0, w, h/2, Color(60, baseGreen + 40, 70, 100))
        
        -- Outer glow on hover
        if panel._hoverAlpha > 0 then
            surface.SetDrawColor(80, 200, 100, panel._hoverAlpha * 80)
            surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
            surface.SetDrawColor(80, 200, 100, panel._hoverAlpha * 40)
            surface.DrawOutlinedRect(-2, -2, w + 4, h + 4)
        end
        
        -- Border
        surface.SetDrawColor(100, 180, 120, 200)
        surface.DrawOutlinedRect(0, 0, w, h)
        
        -- Text with shadow
        draw.SimpleText("Apply Customization", "DermaDefaultBold", w/2 + 1, h/2 + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Apply Customization", "DermaDefaultBold", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    y = y + 32
    
    -- Reset button (accessories and playermodels)
    if self.itemType == "accessory" or self.itemType == "playermodel" then
        self.resetButton = self:Add("DButton")
        self.resetButton:SetText("")
        self.resetButton:SetSize(sliderW - 60, 24)
        self.resetButton:SetPos(baseX, y)
        self.resetButton.DoClick = function()
            if self.itemType == "playermodel" then
                self:ResetPlayermodel()
            else
                self:ResetSliders()
            end
        end
        self.resetButton.Paint = function(panel, w, h)
            local isHovered = panel:IsHovered()
            panel._hoverAlpha = panel._hoverAlpha or 0
            panel._hoverAlpha = Lerp(FrameTime() * 10, panel._hoverAlpha, isHovered and 1 or 0)
            
            -- Orange/yellow gradient for reset
            local baseOrange = 120 + panel._hoverAlpha * 20
            draw.RoundedBox(4, 0, 0, w, h, Color(baseOrange, 80, 30, 255))
            draw.RoundedBox(4, 0, 0, w, h/2, Color(baseOrange + 40, 100, 40, 80))
            
            -- Border
            surface.SetDrawColor(180, 120, 60, 200)
            surface.DrawOutlinedRect(0, 0, w, h)
            
            -- Text with shadow
            draw.SimpleText("Reset Values", "DermaDefault", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Reset Values", "DermaDefault", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        y = y + 28
    end
    
    -- Auto-size panel based on content height
    local contentHeight = y + 30 -- Add bottom padding
    self:SetTall(contentHeight)
    self:SetPos(10, ScrH() / 2 - contentHeight / 2)
end

function PANEL:ResetSliders()
    if self.itemType ~= "accessory" then return end
    
    if PS and PS.Config and PS.Config.Debug then
        print("[PS RESET] ResetSliders called")
        print("[PS RESET] _syncing=" .. tostring(self._syncing) .. " _resetting=" .. tostring(self._resetting))
    end
    
    -- Suppress slider/box sync callbacks during bulk reset to prevent reentrancy
    self._resetting = true
    self._syncing = false  -- Clear any stuck sync flag
    
    -- Get default values from item's DefaultModifications or use hardcoded fallback
    local defaults = {
        scale = 1,
        offsetX = 0,
        offsetY = 0,
        offsetZ = 0,
        rotation = 0,
        axis = "Right",
        axisDeg = -90,
        color = Color(255, 255, 255, 255)
    }
    
    -- Check if item has DefaultModifications defined
    if PS and PS.Items and self.itemID then
        local ITEM = PS.Items[self.itemID]
        if ITEM and ITEM.DefaultModifications then
            local dm = ITEM.DefaultModifications
            if PS and PS.Config and PS.Config.Debug then
                print("[PS RESET] Found DefaultModifications for " .. tostring(self.itemID))
                print("[PS RESET]   dm.axisDeg=" .. tostring(dm.axisDeg) .. " dm.axis=" .. tostring(dm.axis) .. " dm.scale=" .. tostring(dm.scale) .. " dm.rotation=" .. tostring(dm.rotation))
            end
            defaults.scale = dm.scale or defaults.scale
            defaults.offsetX = dm.offsetX or defaults.offsetX
            defaults.offsetY = dm.offsetY or defaults.offsetY
            defaults.offsetZ = dm.offsetZ or defaults.offsetZ
            defaults.rotation = dm.rotation or defaults.rotation
            defaults.axis = dm.axis or defaults.axis
            defaults.axisDeg = dm.axisDeg or defaults.axisDeg
            defaults.color = dm.color or defaults.color
        else
            if PS and PS.Config and PS.Config.Debug then
                print("[PS RESET] No DefaultModifications found for " .. tostring(self.itemID) .. " (ITEM exists=" .. tostring(ITEM ~= nil) .. ")")
            end
        end
    else
        if PS and PS.Config and PS.Config.Debug then
            print("[PS RESET] Cannot lookup item: PS=" .. tostring(PS ~= nil) .. " PS.Items=" .. tostring(PS and PS.Items ~= nil) .. " itemID=" .. tostring(self.itemID))
        end
    end
    
    if PS and PS.Config and PS.Config.Debug then
        print("[PS RESET] Final defaults: axisDeg=" .. tostring(defaults.axisDeg) .. " axis=" .. tostring(defaults.axis) .. " scale=" .. tostring(defaults.scale) .. " rotation=" .. tostring(defaults.rotation))
    end
    
    -- Apply default values to controls (also sync number boxes directly to avoid missed updates)
    if self.scaleSlider then self.scaleSlider:SetValue(defaults.scale) end
    if self.scaleBox then self.scaleBox:SetValue(defaults.scale) end
    if self.rotationSlider then self.rotationSlider:SetValue(defaults.rotation) end
    if self.rotationBox then self.rotationBox:SetValue(defaults.rotation) end
    if self.offsetXSlider then self.offsetXSlider:SetValue(defaults.offsetX) end
    if self.offsetXBox then self.offsetXBox:SetValue(defaults.offsetX) end
    if self.offsetYSlider then self.offsetYSlider:SetValue(defaults.offsetY) end
    if self.offsetYBox then self.offsetYBox:SetValue(defaults.offsetY) end
    if self.offsetZSlider then self.offsetZSlider:SetValue(defaults.offsetZ) end
    if self.offsetZBox then self.offsetZBox:SetValue(defaults.offsetZ) end
    if self.rotateAxisCombo then self.rotateAxisCombo:SetValue(defaults.axis) end
    if self.axisDegSlider then self.axisDegSlider:SetValue(defaults.axisDeg) end
    if self.axisDegBox then self.axisDegBox:SetValue(defaults.axisDeg) end
    if self.accessoryColorMixer then self.accessoryColorMixer:SetColor(defaults.color) end
    
    -- Re-enable callbacks
    self._resetting = false
    
    -- Verify values after setting
    if PS and PS.Config and PS.Config.Debug then
        print("[PS RESET] After set: axisDegSlider=" .. tostring(self.axisDegSlider and self.axisDegSlider:GetValue()) .. " axisDegBox=" .. tostring(self.axisDegBox and self.axisDegBox:GetValue()))
        print("[PS RESET] After set: _syncing=" .. tostring(self._syncing) .. " _resetting=" .. tostring(self._resetting))
    end
    
    -- Apply the reset values to the live preview so the model actually updates
    self:ApplyLivePreview()
end

-- Reset a playermodel's skin, bodygroups and player color to a clean baseline:
-- skin 0, all bodygroups 0, white color. We intentionally do NOT use the item's
-- DefaultModifications here — item defaults often ship a tinted (e.g. blue) player
-- color, whereas "reset" should give the engine-default clean slate. Like
-- ResetSliders, this only updates the controls + live preview; the player still
-- presses "Apply Customization" to persist.
function PANEL:ResetPlayermodel()
    if self.itemType ~= "playermodel" then return end

    -- Hardcoded baseline only.
    local defaults = { skin = 0, bodygroups = {}, playercolor = {255, 255, 255} }

    local ply = LocalPlayer()

    -- Skin
    if self.skinSlider then self.skinSlider:SetValue(defaults.skin) end
    if IsValid(ply) then ply:SetSkin(defaults.skin) end
    if PS_SendPreviewUpdate then PS_SendPreviewUpdate(self.itemType, "skin", defaults.skin) end

    -- Bodygroups: every group the panel built gets its default (0 unless overridden).
    if self.bodygroupButtons then
        for bgID in pairs(self.bodygroupButtons) do
            local val = defaults.bodygroups[bgID] or 0
            self._bodygroupValues[bgID] = val
            if IsValid(ply) then
                ply:SetBodygroup(bgID, val)
                ply:InvalidateBoneCache()
                ply:SetupBones()
            end
            if PS_SendPreviewUpdate then PS_SendPreviewUpdate(self.itemType, "bodygroup", bgID, val) end
            self:UpdateBodygroupButtonVisuals(bgID)
        end
    end

    -- Player color (apply with the same color2-proxy awareness as the live mixer).
    local r, g, b = defaults.playercolor[1], defaults.playercolor[2], defaults.playercolor[3]
    if self.colorMixer then self.colorMixer:SetColor(Color(r, g, b)) end
    if IsValid(ply) then
        local useColor2 = false
        if self.itemID and PS.Items and PS.Items[self.itemID] then
            useColor2 = PS.Items[self.itemID].UseColor2Proxy or false
        end
        if useColor2 then
            ply:SetColor(Color(255, 255, 255, 255))
            ply:SetPlayerColor(Vector(r / 255, g / 255, b / 255))
        else
            ply:SetColor(Color(r, g, b, 255))
            ply:SetPlayerColor(Vector(1, 1, 1))
        end
        ply:SetRenderMode(RENDERMODE_NORMAL)
    end
    if PS_SendPreviewUpdate then PS_SendPreviewUpdate(self.itemType, "playercolor", r, g, b) end
end

-- ============================================================================
-- PREVIEW SYSTEM
-- ============================================================================

function PANEL:EnablePreview()
    if self.previewEnabled then return end
    
    self.previewEnabled = true
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    -- Freeze player animations to prevent bone movement (for both types)
    self._originalSequence = ply:GetSequence()
    self._originalCycle = ply:GetCycle()
    self._originalPlaybackRate = ply:GetPlaybackRate()
    
    ply:SetSequence(ply:LookupSequence("idle_all_01") or 0)
    ply:SetCycle(0)
    ply:SetPlaybackRate(0)
    
    if self.itemType == "accessory" then
        -- For accessories: store original modifiers from the customization table
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
        if self.itemModelPath then
            self._originalModifiers = table.Copy(PS_AccessoryCustomizations[ply][self.itemModelPath] or {})
        end
    elseif self.itemType == "playermodel" then
        -- For playermodels: store original values
        self._originalSkin = ply:GetSkin()
        self._originalBodygroups = {}
        for i = 0, ply:GetNumBodyGroups() - 1 do
            self._originalBodygroups[i] = ply:GetBodygroup(i)
        end
        self._originalPlayerColor = ply:GetPlayerColor()
    elseif self.itemType == "trail" then
        -- Trails are server-side entities; nothing to preview locally
    end
    
    -- Apply initial preview state
    timer.Simple(0.05, function()
        if IsValid(self) then self:ApplyLivePreview() end
    end)
end

-- Removed: No longer using dummy models, preview applies directly to real clientside models

function PANEL:ApplyLivePreview()
    if not self.previewEnabled then return end
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    if self.itemType == "accessory" then
        -- Accessories: update real accessory modifiers in the customization table (real-time preview)
        local mods = self:GetSliderValues()
        if PS and PS.Config and PS.Config.Debug then
            print("[PS PREVIEW] ApplyLivePreview: axisDeg=" .. tostring(mods.axisDeg) .. " axis=" .. tostring(mods.axis) .. " rotation=" .. tostring(mods.rotation) .. " scale=" .. tostring(mods.scale))
        end
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
        if self.itemModelPath then
            PS_AccessoryCustomizations[ply][self.itemModelPath] = mods
            
            -- Apply color to the clientside model immediately if it exists
            if mods.color and PS and PS.ClientsideModels and PS.ClientsideModels[ply] then
                -- Determine if this item uses Color2Proxy
                local ITEM = PS and PS.Items and PS.Items[self.itemID]
                local useColor2 = ITEM and ITEM.UseColor2Proxy or false
                
                for k, mdl in pairs(PS.ClientsideModels[ply]) do
                    if IsValid(mdl) and mdl.GetModel and mdl:GetModel() == self.itemModelPath then
                        -- Use PS:ApplyColorToModel for proper color handling
                        local col = mods.color
                        local r = col.r or col[1] or 255
                        local g = col.g or col[2] or 255
                        local b = col.b or col[3] or 255
                        local a = col.a or col[4] or 255
                        PS:ApplyColorToModel(mdl, Color(r, g, b, a), useColor2)
                        break
                    end
                end
            end
        end
    elseif self.itemType == "playermodel" then
        -- Playermodels: apply directly (individual controls do this in callbacks)
        self:ApplyPlayermodelPreview()
    elseif self.itemType == "trail" then
        -- Trails are server-side entities; no live preview possible
    end
end

function PANEL:ApplyPlayermodelPreview()
    -- Individual controls now apply directly to player in their callbacks
    -- This function is mainly for debug logging now
    if PS and PS.Config and PS.Config.Debug then
        local ply = LocalPlayer()
        if IsValid(ply) then
            print("[PS PANEL DEBUG] Current player state:")
            print("  Skin:", ply:GetSkin())
            print("  Bodygroups:", table.Count(self._bodygroupValues or {}))
            if self.colorMixer then
                local col = self.colorMixer:GetColor()
                print("  Color:", col)
            end
        end
    end
end

-- Removed: No longer manually positioning dummy models

function PANEL:DisablePreview(restoreAccessories)
    if restoreAccessories == nil then restoreAccessories = true end
    if not self.previewEnabled then return end
    
    self.previewEnabled = false
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    if self.itemType == "accessory" then
        -- Restore original accessory modifiers (unless we're applying changes)
        if not self._applyingChanges and self.itemModelPath and self._originalModifiers then
            PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
            PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
            PS_AccessoryCustomizations[ply][self.itemModelPath] = self._originalModifiers
        end
    elseif self.itemType == "playermodel" then
        -- Restore original player state (unless we're applying changes)
        if not self._applyingChanges and self._originalSkin then
            ply:SetSkin(self._originalSkin)
            
            if self._originalBodygroups then
                for bgID, bgValue in pairs(self._originalBodygroups) do
                    ply:SetBodygroup(bgID, bgValue)
                end
            end
            
            if self._originalPlayerColor then
                -- Restore using correct method based on item type
                local useColor2 = false
                if self.itemID and PS.Items and PS.Items[self.itemID] then
                    useColor2 = PS.Items[self.itemID].UseColor2Proxy or false
                end
                if useColor2 then
                    ply:SetPlayerColor(self._originalPlayerColor)
                else
                    -- originalPlayerColor is a Vector, convert back to Color for modulation
                    local v = self._originalPlayerColor
                    ply:SetColor(Color(v.x * 255, v.y * 255, v.z * 255, 255))
                    ply:SetRenderMode(RENDERMODE_NORMAL)
                end
            end
        end
    elseif self.itemType == "trail" then
        -- Nothing to restore for trails (server-side entities)
    end
    
    -- Restore player animations (for both types)
    if self._originalSequence then
        ply:SetSequence(self._originalSequence)
        ply:SetCycle(self._originalCycle or 0)
        ply:SetPlaybackRate(self._originalPlaybackRate or 1)
    end
end

-- Removed: No longer hiding clientside models, we preview on real models now

-- ============================================================================
-- USER ACTIONS
-- ============================================================================

function PANEL:ApplyCustomization()
    local mods = self:GetSliderValues()
    
    if PS and PS.Config and PS.Config.Debug then
        print("[PS PANEL DEBUG] ApplyCustomization:")
        print("  ItemID:", self.itemID)
        print("  ItemType:", self.itemType)
        print("  Looking up PS.Items[" .. tostring(self.itemID) .. "]...")
        if PS.Items and PS.Items[self.itemID] then
            print("  Item found! UseColor2Proxy:", PS.Items[self.itemID].UseColor2Proxy)
            print("  Item name:", PS.Items[self.itemID].Name)
        else
            print("  Item NOT FOUND in PS.Items!")
        end
        PrintTable(mods)
    end
    
    -- Mark that we're applying changes (don't restore original state)
    self._applyingChanges = true
    
    -- Cleanup preview (won't restore for playermodels since _applyingChanges is true)
    self:DisablePreview(false)
    
    -- Send to server via unified backend
    if PS_ApplyItemCustomization then
        PS_ApplyItemCustomization(self.itemID, self.itemType, mods)
    end
    
    self:Close()
end

function PANEL:OnClose()
    -- Cleanup preview (will restore original state if changes weren't applied)
    self:DisablePreview(false)
    
    -- Notify server that panel was closed
    if PS_NotifyItemCustomizationClosed then
        PS_NotifyItemCustomizationClosed(self.itemType)
    end
end

-- ============================================================================
-- SETTERS / INITIALIZATION
-- ============================================================================

function PANEL:SetItem(item)
    if not item then return end
    
    self.itemID = item.ID or item.Model or ""
    self.itemType = item.TYPE or "accessory"
    self.itemModelPath = item.Model
    self.itemBone = item.Bone
    self._itemSkinCount = item.SkinCount or 0
    
    -- Create type-appropriate controls
    if self.itemType == "accessory" then
        self:CreateAccessorySliders()
    elseif self.itemType == "playermodel" then
        self:CreatePlayermodelControls()
    elseif self.itemType == "trail" then
        self:CreateTrailControls()
    end
    
    -- Create buttons
    self:CreateButtons()
    
    -- Create loading indicator
    self.loadingLabel = self:Add("DLabel")
    self.loadingLabel:SetText("Loading customization data...")
    self.loadingLabel:SetFont("DermaDefaultBold")
    self.loadingLabel:SetTextColor(Color(60, 120, 180, 255))
    self.loadingLabel:SizeToContents()
    self.loadingLabel:SetPos((self:GetWide() - self.loadingLabel:GetWide()) / 2, self:GetTall() / 2)
    self.loadingLabel.Think = function(lbl)
        if not IsValid(lbl) then return end
        local time = CurTime() * 2
        local alpha = math.abs(math.sin(time)) * 155 + 100
        lbl:SetTextColor(Color(60, 120, 180, alpha))
    end
    
    -- Resize panel to fit content
    local newHeight = (self._controlsEndY or 450) + 60
    self:SetTall(math.max(420, math.min(newHeight, ScrH() - 100)))
    -- Keep on left side, vertically centered
    self:SetPos(10, math.max(0, (ScrH() - self:GetTall()) / 2))
    
    -- Check for global pending data (for accessories, since they don't have delayed creation)
    if self.itemType == "accessory" then
        timer.Simple(0.05, function()
            if not IsValid(self) then return end
            local pendingKey = self.itemType .. "_" .. self.itemID
            if PS_PendingCustomizationData[pendingKey] then
                if PS and PS.Config and PS.Config.Debug then
                    print("[PS PANEL DEBUG] Applying global pending data to accessory sliders")
                end
                
                local mods = PS_PendingCustomizationData[pendingKey]
                PS_PendingCustomizationData[pendingKey] = nil
                
                -- Apply to sliders
                if mods.offset then
                    if self.offsetXSlider then self.offsetXSlider:SetValue(mods.offset.x or mods.offset[1] or 0) end
                    if self.offsetYSlider then self.offsetYSlider:SetValue(mods.offset.y or mods.offset[2] or 0) end
                    if self.offsetZSlider then self.offsetZSlider:SetValue(mods.offset.z or mods.offset[3] or 0) end
                end
                
                -- Handle rotation/angle data
                if mods.axis and mods.axisDeg and self.rotateAxisCombo and self.axisDegSlider then
                    self.rotateAxisCombo:SetValue(mods.axis)
                    self.axisDegSlider:SetValue(mods.axisDeg)
                elseif mods.ang and self.rotateAxisCombo and self.axisDegSlider then
                    local rotX = mods.ang[1] or 0
                    local rotY = mods.ang[2] or 0
                    local rotZ = mods.ang[3] or 0
                    
                    local maxRot, axis = math.abs(rotX), "Right"
                    if math.abs(rotY) > maxRot then maxRot, axis = math.abs(rotY), "Up" end
                    if math.abs(rotZ) > maxRot then maxRot, axis = math.abs(rotZ), "Forward" end
                    
                    self.rotateAxisCombo:SetValue(axis)
                    local deg = (axis == "Right" and rotX) or (axis == "Up" and rotY) or rotZ
                    self.axisDegSlider:SetValue(deg)
                end
                
                if mods.scale and self.scaleSlider then
                    self.scaleSlider:SetValue(mods.scale or 1)
                end
                
                -- Load color if present
                if mods.color and self.accessoryColorMixer then
                    local col = mods.color
                    local r = col.r or col[1] or 255
                    local g = col.g or col[2] or 255
                    local b = col.b or col[3] or 255
                    local a = col.a or col[4] or 255
                    self.accessoryColorMixer:SetColor(Color(r, g, b, a))
                end
                
                -- Apply data to PS_AccessoryCustomizations table immediately
                timer.Simple(0.05, function()
                    if IsValid(self) and self.previewEnabled then
                        self:ApplyLivePreview()
                    end
                end)
            end
        end)
    end
    
    -- Store panel reference globally for net receiver to find
    PS_ActiveCustomizationPanels = PS_ActiveCustomizationPanels or {}
    table.insert(PS_ActiveCustomizationPanels, self)
    
    -- Request customization from server
    timer.Simple(0, function()
        if not IsValid(self) then return end
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS PANEL DEBUG] Requesting customization: itemID='%s' itemType='%s'", 
                tostring(self.itemID), tostring(self.itemType)))
        end
        
        if PS_RequestItemCustomization then
            PS_RequestItemCustomization(self.itemID, self.itemType)
        end
    end)
    
    -- Timeout fallback: enable controls after 2 seconds if no server response
    timer.Simple(2, function()
        if not IsValid(self) then return end
        if not self._dataReceived then
            if PS and PS.Config and PS.Config.Debug then
                print("[PS PANEL DEBUG] Server response timeout - enabling controls with defaults")
            end
            self:SetControlsEnabled(true)
        end
    end)
    
    -- Enable preview after brief delay
    timer.Simple(0.2, function()
        if not IsValid(self) then return end
        self:EnablePreview()
        
        -- For playermodels, create bodygroup buttons after preview model exists
        if self.itemType == "playermodel" then
            timer.Simple(0.1, function()
                if IsValid(self) then
                    self:CreateBodygroupButtons()
                end
            end)
        end
    end)
end

function PANEL:GetBoneName()
    return self.itemBone or "ValveBiped.Bip01_Head1"
end

-- ============================================================================
-- TRAIL CONTROLS
-- ============================================================================

function PANEL:CreateTrailControls()
    local baseX, y = 20, 50
    local w = math.max(150, self:GetWide() - 90)

    local label = self:Add("DLabel")
    label:SetText("Trail Color")
    label:SetFont("DermaDefaultBold")
    label:SetTextColor(Color(200, 220, 255))
    label:SetPos(baseX, y)
    label:SizeToContents()
    y = y + 24

    self.trailColorMixer = self:Add("DColorMixer")
    self.trailColorMixer:SetPos(baseX, y)
    self.trailColorMixer:SetSize(w, 150)
    self.trailColorMixer:SetPalette(true)
    self.trailColorMixer:SetAlphaBar(false)
    self.trailColorMixer:SetColor(Color(255, 255, 255))
    y = y + 160

    self._controlsEndY = y
end

-- ============================================================================
-- LOADING STATE MANAGEMENT
-- ============================================================================

function PANEL:SetControlsEnabled(enabled)
    if enabled then
        self._dataReceived = true
    end
    
    -- Store all controls that need enabling/disabling
    local controls = {}
    
    -- Accessory controls
    if self.offsetXSlider then table.insert(controls, self.offsetXSlider) end
    if self.offsetYSlider then table.insert(controls, self.offsetYSlider) end
    if self.offsetZSlider then table.insert(controls, self.offsetZSlider) end
    if self.rotateAxisCombo then table.insert(controls, self.rotateAxisCombo) end
    if self.axisDegSlider then table.insert(controls, self.axisDegSlider) end
    if self.scaleSlider then table.insert(controls, self.scaleSlider) end
    if self.rotationSlider then table.insert(controls, self.rotationSlider) end
    if self.accessoryColorMixer then table.insert(controls, self.accessoryColorMixer) end
    if self.offsetXBox then table.insert(controls, self.offsetXBox) end
    if self.offsetYBox then table.insert(controls, self.offsetYBox) end
    if self.offsetZBox then table.insert(controls, self.offsetZBox) end
    if self.axisDegBox then table.insert(controls, self.axisDegBox) end
    if self.scaleBox then table.insert(controls, self.scaleBox) end
    if self.rotationBox then table.insert(controls, self.rotationBox) end
    
    -- Playermodel controls
    if self.colorMixer then table.insert(controls, self.colorMixer) end
    if self.skinSlider then table.insert(controls, self.skinSlider) end
    if self.bodygroupButtons then
        for _, buttonGroup in pairs(self.bodygroupButtons) do
            for _, btn in pairs(buttonGroup) do
                if IsValid(btn) then table.insert(controls, btn) end
            end
        end
    end
    
    -- Trail controls
    if self.trailColorMixer then table.insert(controls, self.trailColorMixer) end
    
    -- Camera controls (always enabled)
    local cameraControls = {
        self.cameraRotationSlider,
        self.cameraYSlider,
        self.cameraZoomSlider,
        self.cameraRotationBox,
        self.cameraYBox,
        self.cameraZoomBox
    }
    
    -- Apply enabled state
    for _, ctrl in ipairs(controls) do
        if IsValid(ctrl) then
            if enabled then
                ctrl:SetEnabled(true)
                ctrl:SetMouseInputEnabled(true)
                ctrl:SetAlpha(255)
            else
                ctrl:SetEnabled(false)
                ctrl:SetMouseInputEnabled(false)
                ctrl:SetAlpha(100)
            end
        end
    end
    
    -- Show/hide loading label
    if IsValid(self.loadingLabel) then
        self.loadingLabel:SetVisible(not enabled)
    end
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function PANEL:OnRemove()
    gui.EnableScreenClicker(false)
    
    -- Remove from global panel list
    if PS_ActiveCustomizationPanels then
        for i, panel in ipairs(PS_ActiveCustomizationPanels) do
            if panel == self then
                table.remove(PS_ActiveCustomizationPanels, i)
                break
            end
        end
    end
    
    -- Remove hooks
    hook.Remove("ShouldDrawLocalPlayer", "PSItemCustomizationPanel_ShouldDrawLocalPlayer")
    hook.Remove("CalcView", "PSItemCustomizationPanel_CalcView")
    
    -- Cleanup preview
    self:DisablePreview(true)
    
    -- Reopen shop menu and restore cursor
    if PS and PS.ShopMenu and IsValid(PS.ShopMenu) then
        PS.ShopMenu:Show()
        gui.EnableScreenClicker(true)
    end
end

function PANEL:Close()
    if self.BaseClass and self.BaseClass.Close then
        self.BaseClass.Close(self)
    else
        DFrame.Close(self)
    end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

function PANEL:Paint(w, h)
    -- Rounded background base
    draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 45, 255))
    
    -- Gradient overlay (drawn inside rounded area)
    for i = 8, h - 8 do
        local alpha = math.min(100, i * 0.15)
        surface.SetDrawColor(0, 0, 0, alpha)
        surface.DrawRect(8, i, w - 16, 1)
    end
    
    -- Outer border glow with rounded corners
    surface.SetDrawColor(60, 120, 180, 100)
    surface.DrawOutlinedRect(0, 0, w, h)
    surface.SetDrawColor(60, 120, 180, 50)
    surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
end

function PANEL:PaintOver(w, h)
    -- Styled status bar at top
    local barHeight = 35
    
    -- Status bar gradient background
    for i = 0, barHeight do
        local alpha = 150 - (i * 1.5)
        surface.SetDrawColor(20, 40, 60, math.max(0, alpha))
        surface.DrawRect(0, i, w, 1)
    end
    
    -- Bottom border of status bar
    surface.SetDrawColor(60, 120, 180, 150)
    surface.DrawRect(10, barHeight, w - 20, 2)
    
    -- Status text with shadow
    local statusText = "Preview enabled. Use controls to customize."
    draw.SimpleText(statusText, "DermaDefault", w/2 + 1, 16, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    draw.SimpleText(statusText, "DermaDefault", w/2, 15, Color(200, 220, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

vgui.Register("PSItemCustomizationPanel", PANEL, "DFrame")

-- ============================================================================
-- NET RECEIVER FOR LOADING SAVED DATA
-- ============================================================================

if CLIENT then
    net.Receive("PS_ItemCustomization_Update", function()
        local itemID = net.ReadString()
        local itemType = net.ReadString()
        local mods = net.ReadTable()
        
        if PS and PS.Config and PS.Config.Debug then
            print("[PS Unified Panel] Received saved data:", itemID, itemType)
            PrintTable(mods)
        end
        
        -- Find the panel instance that matches this item
        local foundPanel = false
        
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS PANEL DEBUG] Looking for panel: itemID='%s' itemType='%s'", itemID, itemType))
            print("[PS PANEL DEBUG] Active panels:", PS_ActiveCustomizationPanels and #PS_ActiveCustomizationPanels or 0)
        end
        
        -- Check our tracked panels first
        if PS_ActiveCustomizationPanels then
            for _, v in ipairs(PS_ActiveCustomizationPanels) do
                if IsValid(v) and v.itemID == itemID and v.itemType == itemType then
                    foundPanel = true
                    -- Apply data to controls based on type
                    if itemType == "accessory" then
                        -- Apply accessory slider values
                        if mods then
                            if mods.offset then
                                if v.offsetXSlider then v.offsetXSlider:SetValue(mods.offset.x or mods.offset[1] or 0) end
                                if v.offsetYSlider then v.offsetYSlider:SetValue(mods.offset.y or mods.offset[2] or 0) end
                                if v.offsetZSlider then v.offsetZSlider:SetValue(mods.offset.z or mods.offset[3] or 0) end
                            end
                            
                            -- Handle rotation/angle data
                            -- Check for axis/axisDeg first (most direct)
                            if mods.axis and mods.axisDeg and v.rotateAxisCombo and v.axisDegSlider then
                                v.rotateAxisCombo:SetValue(mods.axis)
                                v.axisDegSlider:SetValue(mods.axisDeg)
                            -- Otherwise check for ang table
                            elseif mods.ang and v.rotateAxisCombo and v.axisDegSlider then
                                local rotX = mods.ang[1] or 0
                                local rotY = mods.ang[2] or 0
                                local rotZ = mods.ang[3] or 0
                                
                                -- Determine which axis has the largest rotation
                                local maxRot, axis = math.abs(rotX), "Right"
                                if math.abs(rotY) > maxRot then maxRot, axis = math.abs(rotY), "Up" end
                                if math.abs(rotZ) > maxRot then maxRot, axis = math.abs(rotZ), "Forward" end
                                
                                v.rotateAxisCombo:SetValue(axis)
                                local deg = (axis == "Right" and rotX) or (axis == "Up" and rotY) or rotZ
                                v.axisDegSlider:SetValue(deg)
                            -- Legacy: rotation field as table {x,y,z}
                            elseif mods.rotation and type(mods.rotation) == "table" then
                                local rotX = mods.rotation.x or mods.rotation[1] or 0
                                local rotY = mods.rotation.y or mods.rotation[2] or 0
                                local rotZ = mods.rotation.z or mods.rotation[3] or 0
                                
                                if v.rotateAxisCombo and v.axisDegSlider then
                                    local maxRot, axis = math.abs(rotX), "Right"
                                    if math.abs(rotY) > maxRot then maxRot, axis = math.abs(rotY), "Up" end
                                    if math.abs(rotZ) > maxRot then maxRot, axis = math.abs(rotZ), "Forward" end
                                    
                                    v.rotateAxisCombo:SetValue(axis)
                                    local deg = (axis == "Right" and rotX) or (axis == "Up" and rotY) or rotZ
                                    v.axisDegSlider:SetValue(deg)
                                end
                            end
                            
                            -- Legacy Yaw: rotation as a scalar number (separate from axis/axisDeg)
                            if mods.rotation and type(mods.rotation) == "number" and v.rotationSlider then
                                v.rotationSlider:SetValue(mods.rotation)
                            end
                            
                            if mods.scale and v.scaleSlider then
                                v.scaleSlider:SetValue(mods.scale or 1)
                            end
                            
                            -- Load color if present
                            if mods.color and v.accessoryColorMixer then
                                local col = mods.color
                                local r = col.r or col[1] or 255
                                local g = col.g or col[2] or 255
                                local b = col.b or col[3] or 255
                                local a = col.a or col[4] or 255
                                v.accessoryColorMixer:SetColor(Color(r, g, b, a))
                            end
                            
                            if PS and PS.Config and PS.Config.Debug then
                                print("[PS PANEL DEBUG] Applied accessory saved data to sliders")
                            end
                        end
                        
                        -- Update _originalModifiers to match server-confirmed state
                        -- so closing without applying reverts to server data, not pre-panel state
                        timer.Simple(0, function()
                            if IsValid(v) then
                                v._originalModifiers = v:GetSliderValues()
                                if PS and PS.Config and PS.Config.Debug then
                                    print("[PS PANEL DEBUG] Updated _originalModifiers to server-saved state")
                                end
                            end
                        end)
                        
                        -- Enable controls now that data has arrived
                        v:SetControlsEnabled(true)
                    elseif itemType == "playermodel" then
                        -- Apply playermodel values
                        if mods then
                            if PS and PS.Config and PS.Config.Debug then
                                print("[PS PANEL DEBUG] Applying playermodel saved data...")
                                print("  skinSlider exists:", v.skinSlider ~= nil)
                                print("  colorMixer exists:", v.colorMixer ~= nil)
                                print("  _bodygroupValues exists:", v._bodygroupValues ~= nil)
                                print("  bodygroupButtons exists:", v.bodygroupButtons ~= nil)
                                print("  bodygroupButtons count:", v.bodygroupButtons and table.Count(v.bodygroupButtons) or 0)
                            end
                            
                            -- Update skin slider max before applying saved value
                            if v.skinSlider then
                                local ply = LocalPlayer()
                                local skinMax = 0
                                if IsValid(ply) then
                                    skinMax = ply:SkinCount() - 1
                                end
                                if v._itemSkinCount and v._itemSkinCount > 0 then
                                    skinMax = math.max(skinMax, v._itemSkinCount - 1)
                                end
                                if skinMax < 0 then skinMax = 0 end
                                v.skinSlider:SetMax(skinMax)
                            end
                            
                            -- Apply skin
                            if mods.skin and v.skinSlider then
                                v.skinSlider:SetValue(mods.skin)
                                local ply = LocalPlayer()
                                if IsValid(ply) then
                                    ply:SetSkin(mods.skin)
                                    if PS_SendPreviewUpdate then
                                        PS_SendPreviewUpdate(itemType, "skin", mods.skin)
                                    end
                                end
                                if PS and PS.Config and PS.Config.Debug then
                                    print("[PS PANEL DEBUG] Applied skin:", mods.skin)
                                end
                            end
                            
                            -- Apply bodygroups (or store as pending if buttons don't exist yet)
                            if mods.bodygroups then
                                if v._bodygroupValues and v.bodygroupButtons and table.Count(v.bodygroupButtons) > 0 then
                                    -- Buttons exist, apply now
                                    for bgID, bgValue in pairs(mods.bodygroups) do
                                        v._bodygroupValues[bgID] = bgValue
                                        local ply = LocalPlayer()
                                        if IsValid(ply) then
                                            ply:SetBodygroup(bgID, bgValue)
                                            
                                            -- Force visual refresh
                                            ply:InvalidateBoneCache()
                                            ply:SetupBones()
                                            
                                            if PS_SendPreviewUpdate then
                                                PS_SendPreviewUpdate(itemType, "bodygroup", bgID, bgValue)
                                            end
                                        end
                                        v:UpdateBodygroupButtonVisuals(bgID)
                                    end
                                    
                                    if PS and PS.Config and PS.Config.Debug then
                                        print("[PS PANEL DEBUG] Applied bodygroups to existing buttons")
                                    end
                                else
                                    -- Buttons don't exist yet, store for later
                                    v._pendingSavedData = mods
                                    if PS and PS.Config and PS.Config.Debug then
                                        print("[PS PANEL DEBUG] Buttons not ready yet, storing saved data as pending")
                                    end
                                end
                            end
                            
                            -- Apply player color
                            if mods.playercolor and v.colorMixer then
                                local pc = mods.playercolor
                                v.colorMixer:SetColor(Color(
                                    pc[1] or pc.r or 255,
                                    pc[2] or pc.g or 255,
                                    pc[3] or pc.b or 255
                                ))
                                local ply = LocalPlayer()
                                if IsValid(ply) then
                                    ply:SetPlayerColor(Vector(
                                        (pc[1] or pc.r or 255) / 255,
                                        (pc[2] or pc.g or 255) / 255,
                                        (pc[3] or pc.b or 255) / 255
                                    ))
                                    if PS_SendPreviewUpdate then
                                        PS_SendPreviewUpdate(itemType, "playercolor",
                                            pc[1] or pc.r or 255,
                                            pc[2] or pc.g or 255,
                                            pc[3] or pc.b or 255
                                        )
                                    end
                                    if PS and PS.Config and PS.Config.Debug then
                                        print("[PS PANEL DEBUG] Applied playercolor:", pc[1], pc[2], pc[3])
                                    end
                                end
                            end
                        end
                        
                        -- Enable controls now that data has arrived
                        v:SetControlsEnabled(true)
                    elseif itemType == "trail" then
                        -- Apply saved trail color to mixer
                        if mods and mods.color and v.trailColorMixer then
                            local col = mods.color
                            v.trailColorMixer:SetColor(Color(
                                col.r or col[1] or 255,
                                col.g or col[2] or 255,
                                col.b or col[3] or 255
                            ))
                        end
                        -- Enable controls now that data has arrived
                        v:SetControlsEnabled(true)
                    end
                    
                    -- Apply live preview after loading data
                    timer.Simple(0.1, function()
                        if IsValid(v) then
                            v:ApplyLivePreview()
                        end
                    end)
                    
                    break
                end
            end
        end
        
        if not foundPanel then
            -- Store globally so panel can pick it up when it's created
            local key = itemType .. "_" .. itemID
            PS_PendingCustomizationData[key] = mods
            
            if PS and PS.Config and PS.Config.Debug then
                print("[PS PANEL DEBUG] Panel not found yet - storing data globally for:", itemID, itemType)
            end
        end
    end)
end

if PS and PS.Config and PS.Config.Debug then
    print("[PointShop] Unified item customization panel loaded")
end
