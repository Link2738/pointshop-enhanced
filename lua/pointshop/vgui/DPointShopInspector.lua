if SERVER then return end

local function ps_dbg(...)
	if ConVarExists("ps_debug") and GetConVar("ps_debug"):GetBool() then
		print(...)
	end
end

local PANEL = {}

-- Confirmation dialog. Third verbatim copy of the same ~90 lines, which is why its Yes and
-- No had drifted into their own green and grey.
local function CreateStyledConfirmation(title, message, yesCallback, noCallback)
	return PS.UI.Confirm({
		title = title,
		text  = message,
		onYes = yesCallback,
		onNo  = noCallback,
	})
end

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(true)  -- Ensure mouse input works
	
	self.ClassName = "DPointShopInspector"
	
	self.OldPlayerModel = LocalPlayer():GetModel()
	self.OldSkin = LocalPlayer():GetSkin()
	self.OldBodygroups = {}
	for i = 0, LocalPlayer():GetNumBodyGroups() - 1 do
		self.OldBodygroups[i] = LocalPlayer():GetBodygroup(i)
	end
	
	-- Close PointShop menu when inspector opens
	if PS and PS.ShopMenu and IsValid(PS.ShopMenu) and PS.ShopMenu:IsVisible() then
		PS.ShopMenu:Hide()
	end
	
	-- Control panel on the left
	self.ControlPanel = vgui.Create("DPanel", self)
	self.ControlPanel:SetSize(300, 450)
	self.ControlPanel:SetPos(20, ScrH() / 2 - 225)
	self.ControlPanel:SetMouseInputEnabled(true)  -- Panel captures mouse
	-- Body, border and the accent bar along the top, all from the shared painter. The scrim
	-- that used to sit between them is gone with every other copy of it.
	self.ControlPanel.Paint = function(s, w, h)
		PS.Theme.PaintFrame(w, h)
		draw.RoundedBoxEx(PS.Theme.Metrics.Radius, 0, 0, w, 3, PS.Theme.Accent, true, true, false, false)
	end
	
	-- Item Info Section
	self.ItemName = vgui.Create("DLabel", self.ControlPanel)
	self.ItemName:SetPos(10, 10)
	self.ItemName:SetSize(280, 30)
	self.ItemName:SetFont("DermaLarge")
	self.ItemName:SetTextColor(PS.Theme.Text)
	self.ItemName:SetText("")
	
	self.ItemDesc = vgui.Create("DLabel", self.ControlPanel)
	self.ItemDesc:SetPos(10, 45)
	self.ItemDesc:SetSize(280, 60)
	self.ItemDesc:SetFont("DermaDefault")
	self.ItemDesc:SetTextColor(PS.Theme.MenuRowText)
	self.ItemDesc:SetText("")
	self.ItemDesc:SetWrap(true)
	self.ItemDesc:SetAutoStretchVertical(true)
	
	self.ItemPrice = vgui.Create("DLabel", self.ControlPanel)
	self.ItemPrice:SetPos(10, 115)
	self.ItemPrice:SetSize(280, 30)
	self.ItemPrice:SetFont("DermaLarge")
	self.ItemPrice:SetTextColor(PS.Theme.PriceAfford)
	self.ItemPrice:SetText("")
	
	-- Camera Controls Section
	local cameraLabel = vgui.Create("DLabel", self.ControlPanel)
	cameraLabel:SetPos(10, 160)
	cameraLabel:SetSize(280, 20)
	cameraLabel:SetFont("DermaDefaultBold")
	cameraLabel:SetTextColor(PS.Theme.Text)
	cameraLabel:SetText("Camera Controls")
	
	-- Horizontal Rotation Slider
	local rotHLabel = vgui.Create("DLabel", self.ControlPanel)
	rotHLabel:SetPos(10, 185)
	rotHLabel:SetSize(100, 20)
	rotHLabel:SetFont("DermaDefault")
	rotHLabel:SetTextColor(PS.Theme.MenuRowText)
	rotHLabel:SetText("Rotation")
	
	self.RotationSlider = vgui.Create("DNumSlider", self.ControlPanel)
	self.RotationSlider:SetPos(10, 200)
	self.RotationSlider:SetSize(280, 20)
	self.RotationSlider:SetMin(0)
	self.RotationSlider:SetMax(360)
	self.RotationSlider:SetDecimals(0)
	self.RotationSlider:SetValue(180)
	self.RotationSlider.OnMousePressed = nil  -- Don't capture mouse input
	
	-- Vertical Pitch Slider
	local pitchLabel = vgui.Create("DLabel", self.ControlPanel)
	pitchLabel:SetPos(10, 225)
	pitchLabel:SetSize(100, 20)
	pitchLabel:SetFont("DermaDefault")
	pitchLabel:SetTextColor(PS.Theme.MenuRowText)
	pitchLabel:SetText("Height")
	
	self.PitchSlider = vgui.Create("DNumSlider", self.ControlPanel)
	self.PitchSlider:SetPos(10, 240)
	self.PitchSlider:SetSize(280, 20)
	self.PitchSlider:SetMin(-100)
	self.PitchSlider:SetMax(100)
	self.PitchSlider:SetDecimals(0)
	self.PitchSlider:SetValue(0)
	self.PitchSlider.OnMousePressed = nil  -- Don't capture mouse input
	
	-- Zoom/Distance Slider
	local zoomLabel = vgui.Create("DLabel", self.ControlPanel)
	zoomLabel:SetPos(10, 265)
	zoomLabel:SetSize(100, 20)
	zoomLabel:SetFont("DermaDefault")
	zoomLabel:SetTextColor(PS.Theme.MenuRowText)
	zoomLabel:SetText("Distance")
	
	self.ZoomSlider = vgui.Create("DNumSlider", self.ControlPanel)
	self.ZoomSlider:SetPos(10, 280)
	self.ZoomSlider:SetSize(280, 20)
	self.ZoomSlider:SetMin(30)
	self.ZoomSlider:SetMax(200)
	self.ZoomSlider:SetDecimals(0)
	self.ZoomSlider:SetValue(80)
	self.ZoomSlider.OnMousePressed = nil  -- Don't capture mouse input
	
	-- Buy Button
	self.BuyButton = vgui.Create("DButton", self.ControlPanel)
	self.BuyButton:SetPos(10, 310)
	self.BuyButton:SetSize(280, 40)
	self.BuyButton:SetText("")
	self.BuyButton:SetFont("DermaLarge")
	self.BuyButton.DoClick = function()
		if self.ItemData then
			CreateStyledConfirmation('Buy Item',
				'Are you sure you want to buy ' .. self.ItemData.Name .. '?',
				function()
					-- Stage inline customization so PS_BuyItem sends it along
					if self.StagedMods and self.StagedItemID then
						PS_PendingCustomizationData = PS_PendingCustomizationData or {}
						local key = (self.ItemData.TYPE or "accessory") .. "_" .. self.ItemData.ID
						PS_PendingCustomizationData[key] = self.StagedMods
						self._purchased = true
					end
					LocalPlayer():PS_BuyItem(self.ItemData.ID)
					self:Close()
				end,
				nil
			)
		end
	end
	self.BuyButton.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Positive, "Purchase Item")
	end
	
	-- Back Button
	self.BackButton = vgui.Create("DButton", self.ControlPanel)
	self.BackButton:SetPos(10, 360)
	self.BackButton:SetSize(280, 40)
	self.BackButton:SetText("")
	self.BackButton:SetFont("DermaLarge")
	self.BackButton.DoClick = function()
		self:Close()
	end
	self.BackButton.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Neutral, "Back to Shop")
	end
	
	-- Close button (X)
	local closeBtn = vgui.Create("DButton", self.ControlPanel)
	closeBtn:SetPos(270, 5)
	closeBtn:SetSize(25, 25)
	closeBtn:SetText("")
	closeBtn:SetFont("DermaDefault")
	closeBtn.DoClick = function()
		self:Close()
	end
	closeBtn.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Danger)
		draw.SimpleText("X", "DermaDefault", w/2 + 1, h/2 + 1, PS.Theme.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("X", "DermaDefault", w/2, h/2, PS.Theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	
	-- Camera control variables
	self.orbitPhi = math.pi / 2  -- Vertical orbit angle (pi/2 = horizon level)
	self.IsDragging = false
	self.PreviewModel = nil
	
	-- Setup camera and rendering hooks
	self:SetupHooks()
end

function PANEL:SetupHooks()
	-- Hook to render the preview model in the world
	hook.Add("PostDrawOpaqueRenderables", "DPointShopInspector_DrawPreview", function()
		if not IsValid(self) then return end
		
		-- Draw preview model if it exists
		if IsValid(self.PreviewModel) then
			self.PreviewModel:DrawModel()
		end
	end)
	
	-- Hook to hide local player when inspector is active
	hook.Add("PrePlayerDraw", "DPointShopInspector_HidePlayer", function(ply)
		if ply ~= LocalPlayer() then return end
		if not IsValid(self) then return end
		
		if IsValid(self.PreviewModel) then
			-- Return true to prevent player from drawing
			return true
		end
	end)
	
	-- Hook into CalcView to render the player model with custom camera
	hook.Add("CalcView", "DPointShopInspector_Camera", function(ply, pos, angles, fov)
		if not IsValid(LocalPlayer()) then return end
		if not IsValid(self) then return end
		
		-- Read slider values directly (if they exist)
		local rotDeg = (self.RotationSlider and self.RotationSlider:GetValue()) or 180
		local yOffset = (self.PitchSlider and self.PitchSlider:GetValue()) or 0
		local radius = (self.ZoomSlider and self.ZoomSlider:GetValue()) or 80
		
		-- Calculate camera position using spherical coordinates
		local theta = math.rad(rotDeg)
		local target = ply:GetPos() + Vector(0, 0, 64 + yOffset)
		
		-- Use spherical coordinates to position camera
		-- orbitPhi controls vertical angle (defaulting to horizon level)
		local orbitPhi = self.orbitPhi or (math.pi / 2)
		local x = radius * math.sin(orbitPhi) * math.cos(theta)
		local y = radius * math.sin(orbitPhi) * math.sin(theta)
		local z = radius * math.cos(orbitPhi)
		
		local view = {}
		view.origin = target + Vector(x, y, z)
		view.angles = (target - view.origin):Angle()
		view.fov = fov
		view.drawviewer = true
		
		return view
	end)
end

function PANEL:SetItem(itemData)
	self.ItemData = itemData
	
	if not itemData then return end
	
	-- Update UI
	self.ItemName:SetText(itemData.Name or "Unknown Item")
	self.ItemDesc:SetText(itemData.Description or "")
	
	local price = PS.Config.CalculateBuyPrice(LocalPlayer(), itemData)
	self.ItemPrice:SetText(tostring(price) .. " " .. PS.Config.PointsName)
	
	-- Check if player can afford
	if LocalPlayer():PS_HasPoints(price) then
		self.ItemPrice:SetTextColor(PS.Theme.PriceAfford)
		self.BuyButton:SetEnabled(true)
	else
		self.ItemPrice:SetTextColor(PS.Theme.PriceCant)
		self.BuyButton:SetEnabled(false)
		self.BuyButton:SetText("Cannot Afford")
	end
	
	-- Try-before-you-buy: accessories get inline customization sliders.
	-- They write directly to PS_AccessoryCustomizations so the inspector's
	-- live preview accessory picks them up per-frame; on Buy the staged mods
	-- are sent with the purchase and applied on first equip.
	local isAccessory = itemData.TYPE == "accessory" or itemData.Bone or itemData.Attachment
	if isAccessory then
		self:CreateCustomizationSliders(itemData)
	end

	-- Debug output
	ps_dbg("[Inspector] Item:", itemData.Name)
	ps_dbg("[Inspector] Model:", itemData.Model)
	ps_dbg("[Inspector] TYPE:", itemData.TYPE)
	ps_dbg("[Inspector] Category:", itemData.Category)
	ps_dbg("[Inspector] Attachment:", itemData.Attachment)
	
	-- Apply temporary preview to player with slight delay
	timer.Simple(0.05, function()
		if IsValid(self) then
			self:ApplyPreview()
		end
	end)
end

-- Build inline accessory customization controls (try-before-you-buy).
-- Values feed PS_AccessoryCustomizations[LocalPlayer()][itemID] so the
-- per-frame draw loop (ModifyClientsideModel) renders them immediately.
function PANEL:CreateCustomizationSliders(itemData)
	if IsValid(self.CustomizeHeading) then return end -- already built

	local itemID = itemData.ID or itemData.Model
	self.StagedItemID = itemID

	-- Seed defaults from owner overrides → Lua DefaultModifications
	local dm = (PS_GetItemDefault and PS_GetItemDefault(itemID)) or itemData.DefaultModifications or {}
	local defScale = dm.scale or 1
	local defOX = (dm.offset and (dm.offset[1] or dm.offset.x)) or 0
	local defOY = (dm.offset and (dm.offset[2] or dm.offset.y)) or 0
	local defOZ = (dm.offset and (dm.offset[3] or dm.offset.z)) or 0
	local defP = (dm.ang and dm.ang[1]) or 0
	local defYaw = (dm.ang and dm.ang[2]) or 0
	local defR = (dm.ang and dm.ang[3]) or 0
	local defColor = Color(255, 255, 255, 255)
	if dm.color then
		defColor = Color(dm.color.r or dm.color[1] or 255, dm.color.g or dm.color[2] or 255,
			dm.color.b or dm.color[3] or 255, dm.color.a or dm.color[4] or 255)
	end

	local y = 310

	self.CustomizeHeading = vgui.Create("DLabel", self.ControlPanel)
	self.CustomizeHeading:SetPos(10, y)
	self.CustomizeHeading:SetSize(280, 18)
	self.CustomizeHeading:SetFont("DermaDefaultBold")
	self.CustomizeHeading:SetTextColor(PS.Theme.TextDim)
	self.CustomizeHeading:SetText("Customize (applies when you buy)")
	y = y + 22

	local function MakeSlider(label, min, max, default, decimals)
		local s = vgui.Create("DNumSlider", self.ControlPanel)
		s:SetPos(10, y)
		s:SetSize(280, 22)
		s:SetText(label)
		s:SetMin(min)
		s:SetMax(max)
		s:SetDecimals(decimals or 1)
		s:SetValue(default)
		s.Label:SetTextColor(PS.Theme.MenuRowText)
		s.OnValueChanged = function() self:UpdateStagedMods() end
		y = y + 26
		return s
	end

	self.CustScale   = MakeSlider("Scale", 0.1, 2, defScale, 2)
	self.CustOffsetX = MakeSlider("Offset X", -30, 30, defOX, 1)
	self.CustOffsetY = MakeSlider("Offset Y", -30, 30, defOY, 1)
	self.CustOffsetZ = MakeSlider("Offset Z", -30, 30, defOZ, 1)
	self.CustPitch   = MakeSlider("Pitch", -180, 180, defP, 0)
	self.CustYaw     = MakeSlider("Yaw", -180, 180, defYaw, 0)
	self.CustRoll    = MakeSlider("Roll", -180, 180, defR, 0)

	self.CustColor = vgui.Create("DColorMixer", self.ControlPanel)
	self.CustColor:SetPos(10, y)
	self.CustColor:SetSize(280, 110)
	self.CustColor:SetPalette(false)
	self.CustColor:SetAlphaBar(false)
	self.CustColor:SetWangs(true)
	self.CustColor:SetColor(defColor)
	self.CustColor.ValueChanged = function() self:UpdateStagedMods() end
	y = y + 120

	-- Move Buy/Back below the new controls and grow the panel to fit
	self.BuyButton:SetPos(10, y)
	self.BackButton:SetPos(10, y + 50)
	local tall = y + 100
	self.ControlPanel:SetTall(tall)
	self.ControlPanel:SetPos(20, math.max(10, (ScrH() - tall) / 2))

	-- Stage the defaults immediately so the preview matches the sliders
	self:UpdateStagedMods()
end

function PANEL:UpdateStagedMods()
	if not self.StagedItemID then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local col = self.CustColor and self.CustColor:GetColor() or Color(255, 255, 255)
	local mods = {
		scale = self.CustScale and self.CustScale:GetValue() or 1,
		offset = {
			self.CustOffsetX and self.CustOffsetX:GetValue() or 0,
			self.CustOffsetY and self.CustOffsetY:GetValue() or 0,
			self.CustOffsetZ and self.CustOffsetZ:GetValue() or 0,
		},
		ang = {
			self.CustPitch and self.CustPitch:GetValue() or 0,
			self.CustYaw and self.CustYaw:GetValue() or 0,
			self.CustRoll and self.CustRoll:GetValue() or 0,
		},
		color = { r = col.r, g = col.g, b = col.b, a = 255 },
	}
	self.StagedMods = mods

	-- Live preview: the draw loop resolves mods from this table each frame
	PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
	PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
	PS_AccessoryCustomizations[ply][self.StagedItemID] = mods
end

function PANEL:ApplyPreview()
	if not self.ItemData then return end
	
	local ply = LocalPlayer()
	local itemData = self.ItemData
	
	if not itemData.Model then
		ps_dbg("[Inspector] No model defined for item")
		return
	end
	
	-- Detect item type using multiple methods
	local isPlayermodel = false
	local isAccessory = false
	
	-- Method 1: Check TYPE field (uppercase)
	if itemData.TYPE then
		local typeStr = string.lower(itemData.TYPE)
		isPlayermodel = typeStr == "playermodel"
		isAccessory = typeStr == "accessory"
	end
	
	-- Method 2: Check Category
	if not isPlayermodel and not isAccessory and itemData.Category then
		local catStr = string.lower(itemData.Category)
		if string.find(catStr, "playermodel") then
			isPlayermodel = true
		elseif string.find(catStr, "accessories") or string.find(catStr, "hats") or string.find(catStr, "accessory") then
			isAccessory = true
		end
	end
	
	-- Method 3: Check for Attachment field (only accessories have this)
	if not isPlayermodel and not isAccessory and itemData.Attachment then
		isAccessory = true
	end
	
	-- Method 4: Check for specific functions
	if not isPlayermodel and not isAccessory then
		if itemData.ApplyModelSettings or itemData.Bodygroups then
			isPlayermodel = true
		elseif itemData.ModifyClientsideModel or itemData.ApplyAccessorySettings then
			isAccessory = true
		end
	end
	
	ps_dbg("[Inspector] Detected type - Playermodel:", isPlayermodel, "Accessory:", isAccessory)
	
	-- Apply based on detected type
	if isPlayermodel then
		ps_dbg("[Inspector] Creating preview model:", itemData.Model)
		
		-- Remove old preview model if exists
		if IsValid(self.PreviewModel) then
			self.PreviewModel:Remove()
		end
		
		-- Create clientside model entity
		self.PreviewModel = ClientsideModel(itemData.Model, RENDERGROUP_OPAQUE)
		if IsValid(self.PreviewModel) then
			self.PreviewModel:SetNoDraw(true)  -- We'll manually draw it
			self.PreviewModel:SetModelScale(1, 0)
			
			-- Set idle animation to prevent T-pose/reference pose
			local idleSeq = self.PreviewModel:LookupSequence("idle_all_01")
			if not idleSeq or idleSeq < 0 then
				idleSeq = self.PreviewModel:LookupSequence("idle_all")
			end
			if not idleSeq or idleSeq < 0 then
				idleSeq = 0
			end
			self.PreviewModel:SetSequence(idleSeq)
			self.PreviewModel:SetCycle(0)
			
			if itemData.Skin then
				self.PreviewModel:SetSkin(itemData.Skin)
			else
				self.PreviewModel:SetSkin(0)
			end
			
			-- Reset bodygroups
			for i = 0, self.PreviewModel:GetNumBodyGroups() - 1 do
				self.PreviewModel:SetBodygroup(i, 0)
			end
			
			ps_dbg("[Inspector] Preview model created successfully")
		else
			ps_dbg("[Inspector] Failed to create preview model")
		end
		
	elseif isAccessory then
		ps_dbg("[Inspector] Applying accessory:", itemData.Model)
		-- Accessory preview - create temporary clientside model
		if ply.PS_AddClientsideModel then
			local itemID = itemData.ID or itemData.Model
			ply:PS_AddClientsideModel(itemID)
			
			-- Mark the model as a preview
			if PS.ClientsideModels and PS.ClientsideModels[ply] and PS.ClientsideModels[ply][itemID] then
				PS.ClientsideModels[ply][itemID].__ps_preview = true
				self.PreviewAccessoryID = itemID
			end
		end
	else
		ps_dbg("[Inspector] Could not determine item type, creating preview model as fallback")
		
		if IsValid(self.PreviewModel) then
			self.PreviewModel:Remove()
		end
		
		self.PreviewModel = ClientsideModel(itemData.Model, RENDERGROUP_OPAQUE)
		if IsValid(self.PreviewModel) then
			self.PreviewModel:SetNoDraw(true)
			self.PreviewModel:SetSkin(0)
			for i = 0, self.PreviewModel:GetNumBodyGroups() - 1 do
				self.PreviewModel:SetBodygroup(i, 0)
			end
		end
	end
end

function PANEL:RestorePlayerAppearance()
	local ply = LocalPlayer()
	
	-- Remove preview model if exists
	if IsValid(self.PreviewModel) then
		self.PreviewModel:Remove()
		self.PreviewModel = nil
	end
	
	-- Remove preview accessory if one was created
	if self.PreviewAccessoryID and ply.PS_RemoveClientsideModel then
		ply:PS_RemoveClientsideModel(self.PreviewAccessoryID)
		self.PreviewAccessoryID = nil
	end

	-- Clear the staged preview mods unless they were just purchased (the
	-- server's equip broadcast will overwrite the entry in that case)
	if self.StagedItemID and not self._purchased then
		if PS_AccessoryCustomizations and PS_AccessoryCustomizations[ply] then
			PS_AccessoryCustomizations[ply][self.StagedItemID] = nil
		end
	end
	
	-- Restore original model
	if self.OldPlayerModel then
		ply:SetModel(self.OldPlayerModel)
	end
	
	-- Restore skin
	if self.OldSkin then
		ply:SetSkin(self.OldSkin)
	end
	
	-- Restore bodygroups
	if self.OldBodygroups then
		for i, v in pairs(self.OldBodygroups) do
			ply:SetBodygroup(i, v)
		end
	end
	
	-- Refresh currently equipped items to restore them properly
	timer.Simple(0.1, function()
		if IsValid(ply) and ply.PS_RefreshEquippedItems then
			ply:PS_RefreshEquippedItems()
		end
	end)
end

function PANEL:Close()
	self:RestorePlayerAppearance()
	
	-- Remove hooks when closing
	hook.Remove("PostDrawOpaqueRenderables", "DPointShopInspector_DrawPreview")
	hook.Remove("PrePlayerDraw", "DPointShopInspector_HidePlayer")
	hook.Remove("CalcView", "DPointShopInspector_Camera")
	
	-- Reopen shop menu
	if PS and PS.ShopMenu and IsValid(PS.ShopMenu) then
		PS.ShopMenu:Show()
		gui.EnableScreenClicker(true)
	end
	
	self:Remove()
end

function PANEL:OnRemove()
	-- Cleanup when panel is removed
	if IsValid(self.PreviewModel) then
		self.PreviewModel:Remove()
		self.PreviewModel = nil
	end
	
	hook.Remove("PostDrawOpaqueRenderables", "DPointShopInspector_DrawPreview")
	hook.Remove("PrePlayerDraw", "DPointShopInspector_HidePlayer")
	hook.Remove("CalcView", "DPointShopInspector_Camera")
end

function PANEL:OnMousePressed(mouseCode)
	if mouseCode == MOUSE_LEFT then
		-- Don't start dragging if clicking on control panel
		local mx, my = gui.MousePos()
		if IsValid(self.ControlPanel) then
			local px, py = self.ControlPanel:GetPos()
			local pw, ph = self.ControlPanel:GetSize()
			if mx >= px and mx <= px + pw and my >= py and my <= py + ph then
				return  -- Clicking on control panel, don't drag
			end
		end
		
		self.IsDragging = true
		self.DragStartX, self.DragStartY = gui.MousePos()
	end
end

function PANEL:OnMouseReleased(mouseCode)
	if mouseCode == MOUSE_LEFT then
		self.IsDragging = false
	end
end

function PANEL:OnMouseWheeled(scrollDelta)
	-- Update zoom slider value
	if IsValid(self.ZoomSlider) then
		local currentZoom = self.ZoomSlider:GetValue()
		local newZoom = math.Clamp(currentZoom - (scrollDelta * 5), 30, 200)
		self.ZoomSlider:SetValue(newZoom)
	end
end

function PANEL:Think()
	if self.IsDragging then
		local mx, my = gui.MousePos()
		local deltaX = mx - (self.DragStartX or mx)
		local deltaY = my - (self.DragStartY or my)
		
		-- Update rotation slider (horizontal drag)
		if IsValid(self.RotationSlider) then
			local currentRot = self.RotationSlider:GetValue()
			local newRot = (currentRot + deltaX * 0.5) % 360
			self.RotationSlider:SetValue(newRot)
		end
		
		-- Update vertical orbit angle (vertical drag affects phi)
		self.orbitPhi = math.Clamp(self.orbitPhi + math.rad(deltaY * 0.5), math.rad(10), math.rad(170))
		
		self.DragStartX, self.DragStartY = mx, my
	end
	
	-- Update preview model position to match player
	if IsValid(self.PreviewModel) then
		local ply = LocalPlayer()
		if IsValid(ply) then
			self.PreviewModel:SetPos(ply:GetPos())
			self.PreviewModel:SetAngles(Angle(0, ply:EyeAngles().y, 0))
			
			-- Don't copy player animations - preview model should stay in idle pose
			-- (animations are already set to idle_all_01 when model is created)
		end
	end
end

function PANEL:Paint(w, h)
	-- Camera view is rendered by the game's CalcView hook
	-- Preview model is rendered by PostDrawOpaqueRenderables hook
	-- Keep transparent to not block 3D view
end

vgui.Register("DPointShopInspector", PANEL, "EditablePanel")
