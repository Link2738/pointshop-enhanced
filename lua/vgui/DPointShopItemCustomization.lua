-- Unified Item Customization Panel
-- Handles both accessories and playermodels with type detection
-- Uses in-world dummy preview for both types

local PANEL = {}

-- The skin and bodygroup pickers are the same control as the shop's category strip: a row
-- of buttons, one of which is selected. All three now paint through PS.Theme.PaintSelectable
-- (pointshop/cl_theme.lua), which is also what the theme editor's mockup calls - so the
-- preview cannot drift from the real thing.

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
        
        -- Offset: -30 to 30 for each axis
        if mods.offset and type(mods.offset) == "table" then
            sanitized.offset = {
                math.Clamp(tonumber(mods.offset[1] or mods.offset.x) or 0, -30, 30),
                math.Clamp(tonumber(mods.offset[2] or mods.offset.y) or 0, -30, 30),
                math.Clamp(tonumber(mods.offset[3] or mods.offset.z) or 0, -30, 30)
            }
        end

        -- Legacy `rotation`, `axis` and `axisDeg` are intentionally dropped rather than
        -- sanitized through — nothing reads them any more, so passing them along would
        -- only persist dead keys.

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
        local result = {
            scale = math.Clamp(self.scaleSlider and self.scaleSlider:GetValue() or 1, 0.1, 2),
            offset = {
                math.Clamp(self.offsetXSlider and self.offsetXSlider:GetValue() or 0, -30, 30),
                math.Clamp(self.offsetYSlider and self.offsetYSlider:GetValue() or 0, -30, 30),
                math.Clamp(self.offsetZSlider and self.offsetZSlider:GetValue() or 0, -30, 30)
            },
            ang = {
                math.Clamp(self.pitchSlider and self.pitchSlider:GetValue() or 0, -180, 180),
                math.Clamp(self.yawSlider and self.yawSlider:GetValue() or 0, -180, 180),
                math.Clamp(self.rollSlider and self.rollSlider:GetValue() or 0, -180, 180)
            }
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
            skin = self._skinValue or 0,
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
    self:SetTitle("")
    self:SetSize(450, 400)
    self:SetMinWidth(340)
    self:SetMinHeight(350)
    self:SetPos(10, ScrH() / 2 - 200)
    self:MakePopup()
    self:SetMouseInputEnabled(true)
    self:SetKeyBoardInputEnabled(true)

    -- Derma's own titlebar buttons, replaced with ours.
    --
    -- A DFrame builds a minimise, a maximise and a close and paints them with the game's skin,
    -- so this panel wore stock chrome above a themed body.
    self:ShowCloseButton(false)
    if IsValid(self.btnMaxim) then self.btnMaxim:SetVisible(false) end
    if IsValid(self.btnMinim) then self.btnMinim:SetVisible(false) end

    -- Sized around the button rather than the button squeezed into it, so there is a gap
    -- above and below at any scale. The strip was a flat 35, which is exactly IconBtn.
    self.StripH = PS.Theme.Metrics.IconBtn + PS.Theme.Metrics.Gap * 2

    -- Where content starts, measured off the strip rather than guessed.
    --
    -- The three control sections began at a hardcoded 40 or 50, which cleared a 35px strip and
    -- nothing else. Growing the strip put it straight through the first caption of each --
    -- "Player Color" came out with its top sliced off.
    self.ContentY = self.StripH + PS.Theme.Metrics.Gap

    -- And the window grows by what the strip gained, so nothing below is pushed off the end.
    self:SetTall(self:GetTall() + (self.StripH - 35))

    local close = PS.UI.IconButton(self, PS.UI.GlyphIcon("close"), "Danger", function()
        self:Close()
    end)

    close.PerformLayout = function(s)
        local M = PS.Theme.Metrics
        s:SetSize(M.IconBtn, M.IconBtn)
        s:SetPos(self:GetWide() - M.IconBtn - M.IconInset,
            math.floor((self.StripH - M.IconBtn) / 2))
    end

    self.orbitRadius = 60
    self.orbitPhi = math.pi / 2
    self.previewEnabled = false

    -- Type-specific controls will be created in SetItem()
    self:SetupHooks()
end


-- Horizontal content column that every control group lays out inside, so the margins are
-- symmetric and all the groups share one left and one right edge.
--
-- The groups had drifted to four different right edges on a 450px panel:
--   slider rows        x=20 .. 380   (width GetWide() - 90)
--   colour mixers      x=20 .. 320   (width GetWide() - 150)
--   buttons            x=20 .. 320   (width GetWide() - 150)
--   playermodel block  x=20 .. 430   (width GetWide() - 40)
--
-- Only the last was symmetric. Everything now uses this, which is that same 20/20 margin.
local CONTENT_MARGIN = 20

function PANEL:GetContentColumn()
	local panelW = self:GetWide()
	local w = math.max(150, panelW - CONTENT_MARGIN * 2)
	return math.floor((panelW - w) / 2), w
end

-- An empty PANEL:Think() used to sit here. It wasn't inert: this panel is registered on
-- DFrame, and DFrame:Think is what moves the frame while the mouse is held, so an override
-- that doesn't chain up silently disables dragging. Removed rather than stubbed — if
-- per-frame work is needed here later it has to call self.BaseClass.Think(self) first.

function PANEL:SetupHooks()
    local panelRef = self

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
        
        -- CalcView runs every frame while the panel is open. The original built two
        -- Vectors, a third from the addition, an Angle and a fresh `view` table on each
        -- one. The table and the origin Vector are reused here and the intermediate
        -- Vectors dropped in favour of plain components; the Angle stays as a `:Angle()`
        -- call rather than hand-rolled trig, since getting Source's pitch convention
        -- subtly wrong would break the camera for a single allocation.
        self._viewTbl = self._viewTbl or {}
        self._viewOrigin = self._viewOrigin or Vector()
        self._viewDelta = self._viewDelta or Vector()

        local theta = math.rad(rotDeg)
        local sinPhi = math.sin(self.orbitPhi)

        local p = ply:GetPos()
        local tx, ty, tz = p.x, p.y, p.z + 64 + yOffset

        local dx = radius * sinPhi * math.cos(theta)
        local dy = radius * sinPhi * math.sin(theta)
        local dz = radius * math.cos(self.orbitPhi)

        local origin = self._viewOrigin
        origin.x, origin.y, origin.z = tx + dx, ty + dy, tz + dz

        -- target - origin, i.e. the direction from the camera back to the player.
        local delta = self._viewDelta
        delta.x, delta.y, delta.z = -dx, -dy, -dz

        local view = self._viewTbl
        view.origin = origin
        view.angles = delta:Angle()
        view.fov = fov
        view.drawviewer = true
        return view
    end)
end

-- ============================================================================
-- ACCESSORY-SPECIFIC UI
-- ============================================================================

function PANEL:CreateAccessorySliders()
    local baseX, sliderW = self:GetContentColumn()
    local sliderH = 24
    local y = self.ContentY
    
    -- Helper function to create slider+box pair
    local function CreateSliderPair(label, min, max, default, decimals)
        if PS and PS.Config and PS.Config.Debug then
            print(string.format("[PS PANEL DEBUG] CreateSliderPair: %s | min=%s max=%s default=%s",
                label, tostring(min), tostring(max), tostring(default)))
        end

        local slider = self:Add("DNumSlider")
        slider:SetText(label)

        -- DNumSlider's caption is a DLabel with the skin's default colour, same problem as
        -- every other label here.
        slider.Label:SetTextColor(PS.Theme.Text)

        slider:SetDecimals(decimals or 2)
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetValue(default)
        slider:SetPos(baseX, y)
        slider:SetSize(sliderW - 60, sliderH)

        local box = self:Add("DNumberWang")
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
            if not IsValid(self) then return end
            if self._resetting or self._syncing then return end
            self._syncing = true
            local ok, err = pcall(function()
                local v = tonumber(val) or 0
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS SYNC] %s box->slider: val=%s parsed=%s", label, tostring(val), tostring(v)))
                end
                slider:SetValue(v)
                if self.previewEnabled then self:ApplyLivePreview() end
            end)
            self._syncing = false
            if not ok then print("[PS SYNC ERROR] " .. label .. " box->slider: " .. tostring(err)) end
        end

        -- Sync slider to box
        slider.OnValueChanged = function(_, val)
            if not IsValid(self) then return end
            if self._resetting or self._syncing then return end
            self._syncing = true
            local ok, err = pcall(function()
                local v = tonumber(val) or 0
                if PS and PS.Config and PS.Config.Debug then
                    print(string.format("[PS SYNC] %s slider->box: val=%s parsed=%s", label, tostring(val), tostring(v)))
                end
                if box and IsValid(box) and box.SetValue then box:SetValue(v) end
                if self.previewEnabled then self:ApplyLivePreview() end
            end)
            self._syncing = false
            if not ok then print("[PS SYNC ERROR] " .. label .. " slider->box: " .. tostring(err)) end
        end

        -- Enable preview on interaction
        slider.OnMousePressed = function()
            if IsValid(self) then
                self.previewEnabled = true
                self:ApplyLivePreview()
            end
        end

        y = y + sliderH
        return slider, box
    end
    
    -- Create offset sliders
    self.offsetXSlider, self.offsetXBox = CreateSliderPair("Offset X", -30, 30, 0, 2)
    self.offsetYSlider, self.offsetYBox = CreateSliderPair("Offset Y", -30, 30, 0, 2)
    self.offsetZSlider, self.offsetZBox = CreateSliderPair("Offset Z", -30, 30, 0, 2)

    y = y + 8

    -- Rotation sliders: Pitch, Yaw, Roll
    self.pitchSlider, self.pitchBox = CreateSliderPair("Pitch", -180, 180, 0, 1)
    self.yawSlider, self.yawBox = CreateSliderPair("Yaw", -180, 180, 0, 1)
    self.rollSlider, self.rollBox = CreateSliderPair("Roll", -180, 180, 0, 1)

    y = y + 8

    -- Scale slider
    self.scaleSlider, self.scaleBox = CreateSliderPair("Scale", 0.1, 2, 1, 2)

    y = y + 8

    -- Color picker for accessories
    local colorLabel = self:AddLabel(self, "Model Color:")
    colorLabel:SetPos(baseX, y)
    colorLabel:SetSize(sliderW, 20)
    y = y + 22

    self.accessoryColorMixer = self:Add("DColorMixer")
    self.accessoryColorMixer:SetPos(baseX, y)
    self.accessoryColorMixer:SetSize(sliderW, 150)
    self.accessoryColorMixer:SetPalette(true)
    self.accessoryColorMixer:SetAlphaBar(true)
    self.accessoryColorMixer:SetWangs(true)
    self.accessoryColorMixer:SetColor(Color(255, 255, 255, 255))
    self.accessoryColorMixer.ValueChanged = function(_, col)
        if not IsValid(self) then return end

        -- Same repeat-fire as the playermodel mixer: DColorMixer keeps calling this
        -- while the mouse is held regardless of movement. Skip identical values so the
        -- debug log stays readable and ApplyLivePreview isn't redone for nothing.
        local c = self.accessoryColorMixer:GetColor()
        local last = self._lastAccessoryColor
        if last and last.r == c.r and last.g == c.g and last.b == c.b and last.a == c.a then
            return
        end
        self._lastAccessoryColor = { r = c.r, g = c.g, b = c.b, a = c.a }

        self.previewEnabled = true
        self:ApplyLivePreview()
    end
    y = y + 155
    
    y = y + 8

    -- Camera controls (don't trigger preview)
    self.cameraRotationSlider, self.cameraRotationBox = CreateSliderPair("Camera Rotation", 0, 360, 0, 1)
    self.cameraRotationSlider.OnMousePressed = nil
    self.cameraRotationBox.OnValueChanged = function(_, val)
        if not IsValid(self) then return end
        val = tonumber(val) or 0
        if math.abs((tonumber(self.cameraRotationSlider:GetValue()) or 0) - val) > 1e-6 then
            self.cameraRotationSlider:SetValue(val)
        end
    end

    self.cameraYSlider, self.cameraYBox = CreateSliderPair("Camera Y", -100, 100, 0, 1)
    self.cameraYSlider.OnMousePressed = nil
    self.cameraYBox.OnValueChanged = function(_, val)
        if not IsValid(self) then return end
        val = tonumber(val) or 0
        if math.abs((tonumber(self.cameraYSlider:GetValue()) or 0) - val) > 1e-6 then
            self.cameraYSlider:SetValue(val)
        end
    end

    y = y + 8

    self.cameraZoomSlider, self.cameraZoomBox = CreateSliderPair("Camera Zoom", 20, 300, self.orbitRadius, 0)
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
    local baseX, w = self:GetContentColumn()
    local y = self.ContentY

    -- Color mixer
    local colorLabel = self:AddLabel(self, "Player Color")
    colorLabel:SetPos(baseX, y)
    colorLabel:SetSize(w, 20)
    y = y + 20

    self.colorMixer = self:Add("DColorMixer")
    self.colorMixer:SetPos(baseX, y)
    self.colorMixer:SetSize(w, 120)
    self.colorMixer:SetPalette(true)
    self.colorMixer:SetAlphaBar(false)
    self.colorMixer:SetWangs(true)

    -- Opened before ValueChanged is assigned below, so this SetColor itself cannot apply —
    -- but the cube's delayed re-fire lands a frame or two later, by which time the callback
    -- exists. Held open until the panel has settled, and every later seed reopens it.
    self._colorSeeding = true
    self.colorMixer:SetColor(Color(255, 255, 255))
    timer.Simple(0.2, function()
        -- Must close on its own. A panel whose saved data never arrives is never seeded
        -- again, and leaving the window open would swallow the user's own input.
        if IsValid(self) then self._colorSeeding = false end
    end)

    self.colorMixer.ValueChanged = function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            -- Seeding the mixer programmatically also fires this, and not only once: the
            -- colour cube re-fires a frame or two later with a value taken from its knob
            -- position rather than from what was set. Applying that would overwrite the
            -- player's real colour with one nobody picked. See SetMixerColorQuiet.
            if self._colorSeeding then return end

            local col = self.colorMixer:GetColor()

            -- DColorMixer fires ValueChanged continuously while the mouse is held, even
            -- when the cursor hasn't moved. A single drag produced ~90 of these, the last
            -- ~25 all carrying the identical colour — each one redoing SetColor,
            -- SetPlayerColor and a net send for no visible change. Bail if nothing moved.
            local last = self._lastPreviewColor
            if last and last.r == col.r and last.g == col.g and last.b == col.b then
                return
            end
            self._lastPreviewColor = { r = col.r, g = col.g, b = col.b }

            -- Check if this item uses Color2Proxy
            local useColor2 = self:UsesColor2()

            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS COLOR DEBUG] PREVIEW colorMixer -> R=%d G=%d B=%d useColor2=%s itemID=%s", col.r, col.g, col.b, tostring(useColor2), tostring(self.itemID)))
            end

            -- Both channels written in one place. This block used to carry its own copy of
            -- the branch, which is how the preview could disagree with what Apply produced.
            PS:ApplyColorToPlayer(ply, col, useColor2)


            if PS and PS.Config and PS.Config.Debug then
                print(string.format("[PS PREVIEW] Color changed: R=%d G=%d B=%d UseColor2=%s", 
                    col.r, col.g, col.b, tostring(useColor2)))
            end
            
            -- Send to server for authoritative update
            if PS_SendPreviewUpdate then
                PS_SendPreviewUpdate(self.itemType, self.itemID, "playercolor", col.r, col.g, col.b)
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
    local skinLabel = self:AddLabel(scrollPanel, "Skin")
    skinLabel:SetPos(5, scrollY)
    skinLabel:SetSize(w - 10, 20)
    scrollY = scrollY + 20

    -- Skin buttons will be created dynamically in SetItem()
    self.skinButtons = {}
    self._skinValue = 0

    -- Bodygroup buttons will be created dynamically in SetItem()
    self.bodygroupButtons = {}
    self._bodygroupValues = {}
    self._bodygroupScrollY = scrollY
    
    y = y + 210

    -- Camera controls
    self.cameraRotationSlider = self:Add("DNumSlider")
    self.cameraRotationSlider:SetText("Camera Rotation")
    self.cameraRotationSlider.Label:SetTextColor(PS.Theme.Text)
    self.cameraRotationSlider:SetPos(baseX, y)
    self.cameraRotationSlider:SetSize(w, 24)
    self.cameraRotationSlider:SetMin(0)
    self.cameraRotationSlider:SetMax(360)
    self.cameraRotationSlider:SetDecimals(1)
    self.cameraRotationSlider:SetValue(0)
    y = y + 30

    self.cameraYSlider = self:Add("DNumSlider")
    self.cameraYSlider:SetText("Camera Y")
    self.cameraYSlider.Label:SetTextColor(PS.Theme.Text)
    self.cameraYSlider:SetPos(baseX, y)
    self.cameraYSlider:SetSize(w, 24)
    self.cameraYSlider:SetMin(-100)
    self.cameraYSlider:SetMax(100)
    self.cameraYSlider:SetDecimals(1)
    self.cameraYSlider:SetValue(0)
    y = y + 30

    self.cameraZoomSlider = self:Add("DNumSlider")
    self.cameraZoomSlider:SetText("Camera Zoom")
    self.cameraZoomSlider.Label:SetTextColor(PS.Theme.Text)
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

-- The entity whose bodygroups and skins this panel is describing.
--
-- The ITEM's model, not the player's. Reading them off LocalPlayer() only ever worked when
-- the item was already equipped AND the model had finished applying, and the caller was
-- guessing at that second part with a 0.1s timer. Open Modify on a playermodel you are not
-- currently wearing and it found nothing, so the buttons never appeared.
--
-- A no-draw ClientsideModel is the cheapest way to ask a model about itself. It exists only
-- for the length of this function.
function PANEL:WithItemModel(fn)
    local path = self.itemModelPath

    -- Accessories and anything without its own model still describe the player.
    if self.itemType ~= "playermodel" or not path or path == "" then
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        return fn(ply)
    end

    local probe = ClientsideModel(path, RENDERGROUP_OTHER)
    if not IsValid(probe) then
        -- Bad or unmounted model path. Fall back rather than showing nothing.
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        return fn(ply)
    end

    probe:SetNoDraw(true)

    local ok, err = pcall(fn, probe)
    probe:Remove()

    if not ok then error(err) end
end

function PANEL:CreateBodygroupButtons()
    if not self.bodygroupScroll then return end

    self:WithItemModel(function(ent) self:_BuildBodygroupButtons(ent) end)
end

function PANEL:_BuildBodygroupButtons(ent)
    if not IsValid(ent) then return end

    -- Clear existing skin buttons
    if self.skinButtons then
        for _, btn in pairs(self.skinButtons) do
            if IsValid(btn) then btn:Remove() end
        end
    end
    self.skinButtons = {}

    -- COUNTS come from `ent`, which is the item's model. The current VALUE comes from the
    -- player, and only when they are actually wearing this model — a probe model's skin is
    -- always 0, so taking it from there would silently reset the selection to 0 every time
    -- the panel opened.
    --
    -- Pending saved data overwrites this a moment later where it exists; this is the value
    -- shown until then.
    local ply = LocalPlayer()
    if IsValid(ply) and ply:GetModel() == ent:GetModel() then
        self._skinValue = ply:GetSkin() or 0
    else
        self._skinValue = self._skinValue or 0
    end

    -- Create skin buttons
    local skinMax = ent:SkinCount() - 1
    if self._itemSkinCount and self._itemSkinCount > 0 then
        skinMax = math.max(skinMax, self._itemSkinCount - 1)
    end
    if skinMax < 0 then skinMax = 0 end

    if skinMax > 0 then
        local skinLabel = self:AddLabel(self.bodygroupScroll, "Skin")
        skinLabel:SetPos(5, 0)
        skinLabel:SetSize(self.bodygroupScroll:GetWide() - 30, 20)

        local w = self.bodygroupScroll:GetWide() - 30
        local count = skinMax + 1
        local buttonWidth = (w - 5 * (count - 1)) / count

        for val = 0, skinMax do
            local btn = self.bodygroupScroll:Add("DButton")
            btn:SetText(tostring(val))
            btn:SetPos(5 + (buttonWidth + 5) * val, 20)
            btn:SetSize(buttonWidth, 25)

            btn.DoClick = function()
                self._skinValue = val
                local ply = LocalPlayer()
                if IsValid(ply) then
                    ply:SetSkin(val)
                    if PS_SendPreviewUpdate then
                        PS_SendPreviewUpdate(self.itemType, self.itemID, "skin", val)
                    end
                end
                self:UpdateSkinButtonVisuals()
            end

            btn.Paint = function(panel, pw, ph)
                PS.Theme.PaintSelectable(panel, pw, ph, self._skinValue == val, PS.Theme.Selectable.Value)
            end

            self.skinButtons[val] = btn
        end
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

    local scrollY = skinMax > 0 and 50 + ((math.floor(skinMax / 4) + 1) * 30) or self._bodygroupScrollY or 60
    local w = self.bodygroupScroll:GetWide() - 30
    
    -- Create buttons for each bodygroup
    for bgID = 0, ent:GetNumBodyGroups() - 1 do
        local count = ent:GetBodygroupCount(bgID)
        if count > 1 then
            local name = ent:GetBodygroupName(bgID)
            
            local label = self:AddLabel(self.bodygroupScroll, name)
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
                        PS_SendPreviewUpdate(self.itemType, self.itemID, "bodygroup", bgID, val)
                    end
                    
                    -- Update button visuals
                    self:UpdateBodygroupButtonVisuals(bgID)
                    
                    if PS and PS.Config and PS.Config.Debug then
                        print(string.format("[PS PANEL DEBUG] Button click: Set bodygroup %d to %d (result: %d)", 
                            bgID, val, ply:GetBodygroup(bgID)))
                    end
                end
                
                btn.Paint = function(panel, w, h)
                    PS.Theme.PaintSelectable(panel, w, h, self._bodygroupValues[bgID] == val, PS.Theme.Selectable.Value)
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
        if mods.skin then
            self._skinValue = mods.skin
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:SetSkin(mods.skin)
                if PS_SendPreviewUpdate then
                    PS_SendPreviewUpdate(self.itemType, self.itemID, "skin", mods.skin)
                end
            end
            self:UpdateSkinButtonVisuals()
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
                        PS_SendPreviewUpdate(self.itemType, self.itemID, "bodygroup", bgID, bgValue)
                    end
                end
                self:UpdateBodygroupButtonVisuals(bgID)
            end
        end
        
        -- Apply player color
        if mods.playercolor and self.colorMixer then
            local pc = mods.playercolor
            self:SetMixerColorQuiet(Color(
                pc[1] or pc.r or 255,
                pc[2] or pc.g or 255,
                pc[3] or pc.b or 255
            ))
            local ply = LocalPlayer()
            if IsValid(ply) then
                -- Was an unconditional SetPlayerColor with no path branch at all, so
                -- loading saved data pushed the colour into the proxy channel even for a
                -- modulation item — landing it where that model does not render it while
                -- leaving modulation untouched.
                PS:ApplyColorToPlayer(ply, pc, self:UsesColor2())
                if PS_SendPreviewUpdate then
                    PS_SendPreviewUpdate(self.itemType, self.itemID, "playercolor",
                        pc[1] or pc.r or 255,
                        pc[2] or pc.g or 255,
                        pc[3] or pc.b or 255
                    )
                end
            end
        else
            -- No saved colour for this item. Show what the player is actually wearing
            -- rather than the white the mixer was constructed with.
            self:SeedColorMixerFromPlayer()
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

function PANEL:UpdateSkinButtonVisuals()
    if not self.skinButtons then return end

    -- Just trigger a repaint - the Paint function checks _skinValue
    for _, btn in pairs(self.skinButtons) do
        if IsValid(btn) then
            btn:InvalidateLayout(true)
        end
    end
end

-- ============================================================================
-- BUTTONS
-- ============================================================================

function PANEL:CreateButtons()
    local baseX, contentW = self:GetContentColumn()
    local y = self._controlsEndY or 450

    -- Apply button
    self.applyButton = self:Add("DButton")
    self.applyButton:SetText("")
    self.applyButton:SetSize(contentW, 28)
    self.applyButton:SetPos(baseX, y)
    self.applyButton.DoClick = function()
        self:ApplyCustomization()
    end
    self.applyButton.Paint = function(panel, w, h)
        PS.Theme.PaintAction(panel, w, h, PS.Theme.Action.Positive, "Save & Close")
    end
    
    y = y + 32

    -- Reset button (accessories and playermodels)
    if self.itemType == "accessory" or self.itemType == "playermodel" then
        self.resetButton = self:Add("DButton")
        self.resetButton:SetText("")
        self.resetButton:SetSize(contentW, 24)
        self.resetButton:SetPos(baseX, y)
        self.resetButton.DoClick = function()
            if self.itemType == "playermodel" then
                self:ResetPlayermodel()
            else
                self:ResetSliders()
            end
        end
        self.resetButton.Paint = function(panel, w, h)
            PS.Theme.PaintAction(panel, w, h, PS.Theme.Action.Warning, "Reset Values")
        end
        y = y + 28
    end

    -- Owner default sub-panel. Always visible — server gate rejects non-owners.
    y = y + 6
    self._ownerDivider = self:Add("DPanel")
    self._ownerDivider:SetPos(baseX, y)
    self._ownerDivider:SetSize(contentW, 1)
    self._ownerDivider.Paint = function(s, w, h)
        surface.SetDrawColor(PS.Theme.GoldDivider)
        surface.DrawRect(0, 0, w, h)
    end
    y = y + 8

    self._ownerLabel = self:Add("DLabel")
    self._ownerLabel:SetPos(baseX, y)
    self._ownerLabel:SetSize(contentW, 16)
    self._ownerLabel:SetFont("PS_Default")
    self._ownerLabel:SetTextColor(PS.Theme.GoldLabel)
    self._ownerLabel:SetText("Server Default")
    y = y + 20

    self._saveDefaultBtn = self:Add("DButton")
    self._saveDefaultBtn:SetText("")
    self._saveDefaultBtn:SetSize(contentW, 24)
    self._saveDefaultBtn:SetPos(baseX, y)
    self._saveDefaultBtn.DoClick = function()
        local mods = self:GetSliderValues()
        net.Start("PS_ItemDefault_Set")
            net.WriteString(self.itemID)
            net.WriteTable(mods)
            net.WriteBool(false)
        net.SendToServer()
        notification.AddLegacy("Saved as item default.", NOTIFY_GENERIC, 3)
    end
    self._saveDefaultBtn.Paint = function(s, w, h)
        PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Gold, "Save as Default")
    end
    y = y + 28

    self._clearDefaultBtn = self:Add("DButton")
    self._clearDefaultBtn:SetText("")
    self._clearDefaultBtn:SetSize(contentW, 24)
    self._clearDefaultBtn:SetPos(baseX, y)
    self._clearDefaultBtn.DoClick = function()
        net.Start("PS_ItemDefault_Set")
            net.WriteString(self.itemID)
            net.WriteTable({})
            net.WriteBool(true)
        net.SendToServer()
        notification.AddLegacy("Default cleared.", NOTIFY_GENERIC, 3)
    end
    self._clearDefaultBtn.Paint = function(s, w, h)
        PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Danger, "Clear Default")
    end
    y = y + 28

    -- Discard button: closes without saving and restores the live preview
    self.discardButton = self:Add("DButton")
    self.discardButton:SetText("")
    self.discardButton:SetSize(contentW, 24)
    self.discardButton:SetPos(baseX, y)
    self.discardButton.DoClick = function()
        self:Close()
    end
    self.discardButton.Paint = function(panel, w, h)
        PS.Theme.PaintAction(panel, w, h, PS.Theme.Action.Neutral, "Discard Changes")
    end
    y = y + 28

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
        pitch = 0,
        yaw = 0,
        roll = 0,
        color = Color(255, 255, 255, 255)
    }

    -- Resolve via owner overrides → ITEM.DefaultModifications.
    -- offsetX/Y/Z here are slider names, not a data format — the source is always
    -- dm.offset, the {x,y,z} table.
    local dm = PS_GetItemDefault and PS_GetItemDefault(self.itemID)
    if dm then
        if PS and PS.Config and PS.Config.Debug then
            print("[PS RESET] Found defaults for " .. tostring(self.itemID))
        end
        defaults.scale = dm.scale or defaults.scale
        defaults.color = dm.color or defaults.color
        if dm.offset then
            defaults.offsetX = dm.offset[1] or dm.offset.x or defaults.offsetX
            defaults.offsetY = dm.offset[2] or dm.offset.y or defaults.offsetY
            defaults.offsetZ = dm.offset[3] or dm.offset.z or defaults.offsetZ
        end
        if dm.ang then
            defaults.pitch = dm.ang[1] or 0
            defaults.yaw   = dm.ang[2] or 0
            defaults.roll  = dm.ang[3] or 0
        end
    end

    if PS and PS.Config and PS.Config.Debug then
        print(string.format("[PS RESET] Final defaults: scale=%s offset=%s,%s,%s ang=%s,%s,%s",
            tostring(defaults.scale), tostring(defaults.offsetX), tostring(defaults.offsetY),
            tostring(defaults.offsetZ), tostring(defaults.pitch), tostring(defaults.yaw),
            tostring(defaults.roll)))
    end
    
    -- Apply default values to controls (also sync number boxes directly to avoid missed updates)
    if self.scaleSlider then self.scaleSlider:SetValue(defaults.scale) end
    if self.scaleBox then self.scaleBox:SetValue(defaults.scale) end
    if self.offsetXSlider then self.offsetXSlider:SetValue(defaults.offsetX) end
    if self.offsetXBox then self.offsetXBox:SetValue(defaults.offsetX) end
    if self.offsetYSlider then self.offsetYSlider:SetValue(defaults.offsetY) end
    if self.offsetYBox then self.offsetYBox:SetValue(defaults.offsetY) end
    if self.offsetZSlider then self.offsetZSlider:SetValue(defaults.offsetZ) end
    if self.offsetZBox then self.offsetZBox:SetValue(defaults.offsetZ) end
    if self.pitchSlider then self.pitchSlider:SetValue(defaults.pitch or 0) end
    if self.pitchBox then self.pitchBox:SetValue(defaults.pitch or 0) end
    if self.yawSlider then self.yawSlider:SetValue(defaults.yaw or 0) end
    if self.yawBox then self.yawBox:SetValue(defaults.yaw or 0) end
    if self.rollSlider then self.rollSlider:SetValue(defaults.roll or 0) end
    if self.rollBox then self.rollBox:SetValue(defaults.roll or 0) end
    if self.accessoryColorMixer then self.accessoryColorMixer:SetColor(defaults.color) end
    
    -- Re-enable callbacks
    self._resetting = false
    
    -- Verify values after setting
    if PS and PS.Config and PS.Config.Debug then
        print("[PS RESET] After set: pitch=" .. tostring(self.pitchSlider and self.pitchSlider:GetValue()) .. " yaw=" .. tostring(self.yawSlider and self.yawSlider:GetValue()) .. " roll=" .. tostring(self.rollSlider and self.rollSlider:GetValue()))
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

    -- Start from owner overrides → Lua DefaultModifications, fall back to engine baseline.
    local defaults = { skin = 0, bodygroups = {}, playercolor = {255, 255, 255} }
    local dm = PS_GetItemDefault and PS_GetItemDefault(self.itemID)
    if dm then
        if dm.skin       then defaults.skin        = dm.skin        end
        if dm.bodygroups then defaults.bodygroups  = dm.bodygroups  end
        if dm.playercolor then defaults.playercolor = dm.playercolor end
    end

    local ply = LocalPlayer()

    -- Skin
    self._skinValue = defaults.skin
    if IsValid(ply) then ply:SetSkin(defaults.skin) end
    if PS_SendPreviewUpdate then PS_SendPreviewUpdate(self.itemType, self.itemID, "skin", defaults.skin) end
    self:UpdateSkinButtonVisuals()

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
            if PS_SendPreviewUpdate then PS_SendPreviewUpdate(self.itemType, self.itemID, "bodygroup", bgID, val) end
            self:UpdateBodygroupButtonVisuals(bgID)
        end
    end

    -- Player color (apply with the same color2-proxy awareness as the live mixer).
    local r, g, b = defaults.playercolor[1], defaults.playercolor[2], defaults.playercolor[3]
    if self.colorMixer then self:SetMixerColorQuiet(Color(r, g, b)) end
    if IsValid(ply) then
        PS:ApplyColorToPlayer(ply, Color(r, g, b, 255), self:UsesColor2())
    end
    if PS_SendPreviewUpdate then PS_SendPreviewUpdate(self.itemType, self.itemID, "playercolor", r, g, b) end
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
        if self.itemID then
            self._originalModifiers = table.Copy(PS_AccessoryCustomizations[ply][self.itemID] or {})
        end
    elseif self.itemType == "playermodel" then
        -- For playermodels: store original values
        self._originalSkin = ply:GetSkin()
        self._originalBodygroups = {}
        for i = 0, ply:GetNumBodyGroups() - 1 do
            self._originalBodygroups[i] = ply:GetBodygroup(i)
        end
        -- Both channels are captured, because which one holds the player's actual colour
        -- depends on the item. Only the proxy was saved before, so cancelling a preview on
        -- a modulation item restored the proxy's value *as* modulation — a colour the
        -- player had never had.
        self._originalPlayerColor = ply:GetPlayerColor()   -- proxy, normalised Vector
        self._originalRenderColor = ply:GetColor()         -- modulation, Color
    elseif self.itemType == "trail" then
        -- Trails are server-side entities; nothing to preview locally
    end
    
    -- Apply initial preview state
    timer.Simple(0.05, function()
        if IsValid(self) then self:ApplyLivePreview() end
    end)
end

-- Gizmo rendering disabled — using sliders instead
function PANEL:RenderGizmo()
    -- Gizmos removed in favor of intuitive pitch/yaw/roll sliders
end


-- Removed: No longer using dummy models, preview applies directly to real clientside models

function PANEL:ApplyLivePreview()
    if not self.previewEnabled then return end

    -- Don't push preview state out before the server's saved data has landed.
    --
    -- EnablePreview schedules this ~0.25s after the panel opens. If the round trip hasn't
    -- finished by then the controls still hold the values they were constructed with, and
    -- the accessory branch below writes them straight into PS_AccessoryCustomizations and
    -- onto the clientside model — replacing the player's real colour and offsets with the
    -- defaults. _dataReceived is set by SetControlsEnabled, which runs both when the
    -- response arrives and on the 2s timeout, so a silent server still unblocks.
    if not self._dataReceived then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if self.itemType == "accessory" then
        -- Accessories: update real accessory modifiers in the customization table (real-time preview)
        local mods = self:GetSliderValues()

        -- Bail if nothing actually changed. Setting a DNumSlider's value makes it and its
        -- DSlider child settle over several frames, and each settle step re-fires
        -- OnValueChanged — loading saved data produced ~65 identical ApplyLivePreview
        -- calls in one second. Deduping here covers every caller rather than trying to
        -- suppress each one individually.
        local sig = string.format("%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%s",
            mods.scale or 1,
            mods.offset[1] or 0, mods.offset[2] or 0, mods.offset[3] or 0,
            mods.ang[1] or 0, mods.ang[2] or 0, mods.ang[3] or 0,
            mods.color and string.format("%d,%d,%d,%d", mods.color.r, mods.color.g, mods.color.b, mods.color.a) or "-")

        if self._lastPreviewSig == sig then return end
        self._lastPreviewSig = sig

        if PS and PS.Config and PS.Config.Debug then
            print("[PS PREVIEW] ApplyLivePreview: ang=" .. tostring(mods.ang[1]) .. "/" .. tostring(mods.ang[2]) .. "/" .. tostring(mods.ang[3]) .. " scale=" .. tostring(mods.scale))
        end
        PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
        PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
        if self.itemID then
            PS_AccessoryCustomizations[ply][self.itemID] = mods
            
            -- Apply color to the clientside model immediately if it exists
            if mods.color and PS and PS.ClientsideModels and PS.ClientsideModels[ply] then
                local useColor2 = self:UsesColor2()
                
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
        if not self._applyingChanges and self.itemID and self._originalModifiers then
            PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
            PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
            PS_AccessoryCustomizations[ply][self.itemID] = self._originalModifiers
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
            
            -- Restore from whichever channel actually held this item's colour, through the
            -- same entry point that applied the preview — so the channel that is not being
            -- restored gets cleared rather than being left as the preview left it.
            local useColor2 = self:UsesColor2()
            local original = useColor2 and self._originalPlayerColor or self._originalRenderColor
            if original then
                PS:ApplyColorToPlayer(ply, original, useColor2)
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

-- Apply a mods table directly into the panel's sliders/controls.
-- Works for both accessory and playermodel types based on self.itemType.
function PANEL:LoadModsIntoSliders(mods)
    if not mods then return end
    if self.itemType == "accessory" then
        if mods.offset then
            if self.offsetXSlider then self.offsetXSlider:SetValue(mods.offset.x or mods.offset[1] or 0) end
            if self.offsetYSlider then self.offsetYSlider:SetValue(mods.offset.y or mods.offset[2] or 0) end
            if self.offsetZSlider then self.offsetZSlider:SetValue(mods.offset.z or mods.offset[3] or 0) end
        end
        if mods.ang then
            if self.pitchSlider then self.pitchSlider:SetValue(mods.ang[1] or 0) end
            if self.yawSlider   then self.yawSlider:SetValue(mods.ang[2] or 0) end
            if self.rollSlider  then self.rollSlider:SetValue(mods.ang[3] or 0) end
        end
        if mods.scale and self.scaleSlider then self.scaleSlider:SetValue(mods.scale) end
        if mods.color and self.accessoryColorMixer then
            local col = mods.color
            self.accessoryColorMixer:SetColor(Color(
                col.r or col[1] or 255, col.g or col[2] or 255,
                col.b or col[3] or 255, col.a or col[4] or 255))
        end
    elseif self.itemType == "playermodel" then
        if mods.skin ~= nil then
            self._skinValue = mods.skin
            self:UpdateSkinButtonVisuals()
            local ply = LocalPlayer()
            if IsValid(ply) then ply:SetSkin(mods.skin) end
        end
        if mods.bodygroups and self.bodygroupButtons then
            self._bodygroupValues = self._bodygroupValues or {}
            for bgID, val in pairs(mods.bodygroups) do
                local id = tonumber(bgID) or bgID
                self._bodygroupValues[id] = val
                self:UpdateBodygroupButtonVisuals(id)
                local ply = LocalPlayer()
                if IsValid(ply) then ply:SetBodygroup(id, val) end
            end
        end
        if mods.playercolor and self.colorMixer then
            local pc = mods.playercolor
            self:SetMixerColorQuiet(Color(pc[1] or pc.r or 255, pc[2] or pc.g or 255, pc[3] or pc.b or 255))
        end
    end
    timer.Simple(0.05, function()
        if IsValid(self) and self.previewEnabled then self:ApplyLivePreview() end
    end)
end

function PANEL:SetItem(item)
    if not item then return end

    self.itemID = item.ID or item.Model or ""
    self.itemType = item.TYPE or "accessory"
    self.itemModelPath = item.Model
    self.itemBone = item.Bone
    self._itemSkinCount = item.SkinCount or 0

    -- Captured from the item table we were handed, not re-derived later. See UsesColor2.
    self.useColor2 = item.UseColor2Proxy or false

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
    self.loadingLabel:SetFont("PS_DefaultBold")
    self.loadingLabel:SetTextColor(PS.Theme.Accent)
    self.loadingLabel:SizeToContents()
    self.loadingLabel:SetPos((self:GetWide() - self.loadingLabel:GetWide()) / 2, self:GetTall() / 2)

    -- Scratch owned by this label rather than one of the file-scope ones: SetTextColor keeps
    -- the table it is given, so the label reads it again on every draw and a shared scratch
    -- would be repainted out from under it by whatever painted next.
    self.loadingLabel._pulseCol = Color(0, 0, 0)
    self.loadingLabel.Think = function(lbl)
        if not IsValid(lbl) then return end
        local time = CurTime() * 2
        local alpha = math.abs(math.sin(time)) * 155 + 100
        lbl:SetTextColor(PS.Theme.Alpha(lbl._pulseCol, PS.Theme.Accent, alpha))
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
                self:LoadModsIntoSliders(mods)
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
        
        -- No longer waits on anything. This used to sleep 0.1s hoping the preview model had
        -- finished applying to the player, because the buttons were read off the player.
        -- They are read off the item's own model now, which is available immediately and does
        -- not depend on what the player happens to be wearing.
        if self.itemType == "playermodel" then
            self:CreateBodygroupButtons()
        end
    end)
end

-- Whether this item colours through the $color2 proxy (the player colour channel) or
-- through render modulation. The two paths are mutually exclusive and each one explicitly
-- clears the other, so picking the wrong one does not merely fail to apply a colour — it
-- actively wipes the channel the model was actually using.
--
-- Five call sites each re-derived this as `PS.Items[self.itemID].UseColor2Proxy or false`.
-- That lookup yields false on a miss, and it can miss: itemID falls back to item.Model
-- when the item table has no ID, and a model path is not a PS.Items key. A miss sends a
-- Color2Proxy model down the modulation branch, which ends in SetPlayerColor(1, 1, 1) —
-- the model turns white while the mixer still shows the correct colour, because the mixer
-- was seeded from the saved data and never touched the channel that got cleared.
--
-- The panel is handed the item table in SetItem, so it reads the flag from there and
-- treats the global lookup as a fallback rather than the source of truth.
function PANEL:UsesColor2()
    if self.useColor2 ~= nil then return self.useColor2 end
    local ITEM = PS and PS.Items and PS.Items[self.itemID]
    return (ITEM and ITEM.UseColor2Proxy) or false
end

-- Seeds the colour mixer from the player's live colour, applying nothing back.
--
-- Used when the server has no saved colour for this item. Previously the mixer just sat
-- at the white it was constructed with, so the panel claimed you were wearing white when
-- you weren't — and hitting Save wrote that white back as if you had chosen it.
--
-- Reads whichever channel the item actually uses, mirroring the split in the mixer's own
-- ValueChanged: Color2Proxy items carry their colour in the player colour, everything
-- else in render modulation.
-- Sets the mixer's displayed colour WITHOUT letting it write back to the player.
--
-- Every programmatic SetColor on a DColorMixer fires ValueChanged, and it does not stop
-- at one: the mixer's colour cube re-fires on a later frame once it has laid out, with a
-- value derived from its knob position rather than from what was set. That late fire
-- carries a different colour, so a dedupe on the last applied value does not catch it, and
-- the panel ends up pushing a colour nobody chose onto the player — which is why opening
-- the panel used to strip the model's colour while still displaying the correct numbers.
--
-- The window suppresses applies until the mixer has settled. Same idea as the _syncing and
-- _resetting flags the sliders in this file already use; genuine user input arrives well
-- after it closes.
function PANEL:SetMixerColorQuiet(col)
    if not self.colorMixer then return end

    self._colorSeeding = true
    self._lastPreviewColor = { r = col.r, g = col.g, b = col.b }
    self.colorMixer:SetColor(col)

    timer.Simple(0.2, function()
        if IsValid(self) then self._colorSeeding = false end
    end)
end

function PANEL:SeedColorMixerFromPlayer()
    if not self.colorMixer then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local col
    if self:UsesColor2() then
        local v = ply:GetPlayerColor()   -- normalized 0-1 Vector
        col = Color(
            math.Clamp(math.floor((v.x or 1) * 255), 0, 255),
            math.Clamp(math.floor((v.y or 1) * 255), 0, 255),
            math.Clamp(math.floor((v.z or 1) * 255), 0, 255)
        )
    else
        local c = ply:GetColor()
        col = Color(c.r, c.g, c.b)
    end

    self:SetMixerColorQuiet(col)
end

function PANEL:GetBoneName()
    return self.itemBone or "ValveBiped.Bip01_Head1"
end

-- ============================================================================
-- TRAIL CONTROLS
-- ============================================================================

-- A label that follows the theme.
--
-- DLabel with no SetTextColor takes its colour from the game's skin, which is a light grey
-- chosen to sit on a dark panel. That was invisible the moment a light look existed: every
-- caption in this panel -- Player Color, Skin, the bodygroup names, the camera sliders --
-- was near-white text on a near-white body.
--
-- `parent` because these go into three different containers: the panel, the scroll panel and
-- the bodygroup scroll.
function PANEL:AddLabel(parent, text, font)
    local label = parent:Add("DLabel")
    label:SetText(text)
    label:SetFont(font or "PS_Default")
    label:SetTextColor(PS.Theme.Text)
    return label
end

function PANEL:CreateTrailControls()
    local baseX, w = self:GetContentColumn()
    local y = self.ContentY

    local label = self:Add("DLabel")
    label:SetText("Trail Color")
    label:SetFont("PS_DefaultBold")
    label:SetTextColor(PS.Theme.TextDim)
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
    if self.pitchSlider then table.insert(controls, self.pitchSlider) end
    if self.yawSlider then table.insert(controls, self.yawSlider) end
    if self.rollSlider then table.insert(controls, self.rollSlider) end
    if self.scaleSlider then table.insert(controls, self.scaleSlider) end
    if self.accessoryColorMixer then table.insert(controls, self.accessoryColorMixer) end
    if self.offsetXBox then table.insert(controls, self.offsetXBox) end
    if self.offsetYBox then table.insert(controls, self.offsetYBox) end
    if self.offsetZBox then table.insert(controls, self.offsetZBox) end
    if self.pitchBox then table.insert(controls, self.pitchBox) end
    if self.yawBox then table.insert(controls, self.yawBox) end
    if self.rollBox then table.insert(controls, self.rollBox) end
    if self.scaleBox then table.insert(controls, self.scaleBox) end
    
    -- Playermodel controls
    if self.colorMixer then table.insert(controls, self.colorMixer) end
    if self.skinButtons then
        for _, btn in pairs(self.skinButtons) do
            if IsValid(btn) then table.insert(controls, btn) end
        end
    end
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
    self:Remove()
end

-- ============================================================================
-- RENDERING
-- ============================================================================

function PANEL:Paint(w, h)
    PS.Theme.PaintPanelBody(w, h)
end

function PANEL:PaintOver(w, h)
    PS.Theme.PaintStatusStrip(w, self.StripH or 35, "Preview enabled. Use controls to customize.")
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
                            
                            -- Handle rotation/angle data — load all three independently
                            if mods.ang then
                                if v.pitchSlider then v.pitchSlider:SetValue(mods.ang[1] or 0) end
                                if v.yawSlider then v.yawSlider:SetValue(mods.ang[2] or 0) end
                                if v.rollSlider then v.rollSlider:SetValue(mods.ang[3] or 0) end
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
                                        PS_SendPreviewUpdate(itemType, itemID, "skin", mods.skin)
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
                                                PS_SendPreviewUpdate(itemType, itemID, "bodygroup", bgID, bgValue)
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
                                v:SetMixerColorQuiet(Color(
                                    pc[1] or pc.r or 255,
                                    pc[2] or pc.g or 255,
                                    pc[3] or pc.b or 255
                                ))
                                local ply = LocalPlayer()
                                if IsValid(ply) then
                                    -- Same fix as the pending-data path above: this was an
                                    -- unconditional SetPlayerColor with no path branch.
                                    PS:ApplyColorToPlayer(ply, pc, v:UsesColor2())
                                    if PS_SendPreviewUpdate then
                                        PS_SendPreviewUpdate(itemType, itemID, "playercolor",
                                            pc[1] or pc.r or 255,
                                            pc[2] or pc.g or 255,
                                            pc[3] or pc.b or 255
                                        )
                                    end
                                    if PS and PS.Config and PS.Config.Debug then
                                        print("[PS PANEL DEBUG] Applied playercolor:", pc[1], pc[2], pc[3])
                                    end
                                end
                            else
                                -- No saved colour for this item. Show what the player is
                                -- actually wearing rather than the mixer's default white.
                                v:SeedColorMixerFromPlayer()
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
