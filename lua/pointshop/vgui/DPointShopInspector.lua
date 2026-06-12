if SERVER then return end

local function ps_dbg(...)
	if ConVarExists("ps_debug") and GetConVar("ps_debug"):GetBool() then
		print(...)
	end
end

local PANEL = {}

-- Custom styled confirmation dialog
local function CreateStyledConfirmation(title, message, yesCallback, noCallback)
	local frame = vgui.Create("DFrame")
	frame:SetSize(400, 180)
	frame:Center()
	frame:MakePopup()
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(false)
	
	frame.Paint = function(s, w, h)
		draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 45, 255))
		
		for i = 8, h - 8 do
			local alpha = math.min(100, i * 0.15)
			surface.SetDrawColor(0, 0, 0, alpha)
			surface.DrawRect(8, i, w - 16, 1)
		end
		
		surface.SetDrawColor(60, 120, 180, 100)
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.SetDrawColor(60, 120, 180, 50)
		surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
		
		draw.RoundedBoxEx(8, 0, 0, w, 3, Color(60, 140, 200, 255), true, true, false, false)
		
		draw.SimpleText(title, "DermaLarge", w/2 + 1, 21, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(title, "DermaLarge", w/2, 20, Color(200, 220, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	
	local messageLabel = vgui.Create("DLabel", frame)
	messageLabel:SetPos(20, 60)
	messageLabel:SetSize(360, 50)
	messageLabel:SetText(message)
	messageLabel:SetFont("DermaDefault")
	messageLabel:SetTextColor(Color(220, 220, 220))
	messageLabel:SetWrap(true)
	messageLabel:SetContentAlignment(5)
	
	local yesBtn = vgui.Create("DButton", frame)
	yesBtn:SetPos(30, 120)
	yesBtn:SetSize(160, 40)
	yesBtn:SetText("")
	yesBtn.DoClick = function()
		frame:Close()
		if yesCallback then yesCallback() end
	end
	yesBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseGreen = 80 + s._hoverAlpha * 30
		draw.RoundedBox(6, 0, 0, w, h, Color(40, baseGreen, 50, 255))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(60, baseGreen + 40, 70, 100))
		
		if s._hoverAlpha > 0 then
			surface.SetDrawColor(80, 200, 100, s._hoverAlpha * 80)
			surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
		end
		
		surface.SetDrawColor(100, 180, 120, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
		
		draw.SimpleText("Yes", "DermaLarge", w/2 + 1, h/2 + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Yes", "DermaLarge", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	
	local noBtn = vgui.Create("DButton", frame)
	noBtn:SetPos(210, 120)
	noBtn:SetSize(160, 40)
	noBtn:SetText("")
	noBtn.DoClick = function()
		frame:Close()
		if noCallback then noCallback() end
	end
	noBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseGray = 70 + s._hoverAlpha * 20
		draw.RoundedBox(6, 0, 0, w, h, Color(baseGray, baseGray, baseGray + 5, 255))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(baseGray + 20, baseGray + 20, baseGray + 25, 80))
		
		surface.SetDrawColor(110, 110, 115, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
		
		draw.SimpleText("No", "DermaLarge", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("No", "DermaLarge", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	
	return frame
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
	self.ControlPanel.Paint = function(s, w, h)
		-- Rounded background base
		draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 45, 255))
		
		-- Gradient overlay
		for i = 8, h - 8 do
			local alpha = math.min(100, i * 0.15)
			surface.SetDrawColor(0, 0, 0, alpha)
			surface.DrawRect(8, i, w - 16, 1)
		end
		
		-- Outer border glow
		surface.SetDrawColor(60, 120, 180, 100)
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.SetDrawColor(60, 120, 180, 50)
		surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
		
		-- Top accent bar
		draw.RoundedBoxEx(8, 0, 0, w, 3, Color(60, 140, 200, 255), true, true, false, false)
	end
	
	-- Item Info Section
	self.ItemName = vgui.Create("DLabel", self.ControlPanel)
	self.ItemName:SetPos(10, 10)
	self.ItemName:SetSize(280, 30)
	self.ItemName:SetFont("DermaLarge")
	self.ItemName:SetTextColor(Color(255, 255, 255))
	self.ItemName:SetText("")
	
	self.ItemDesc = vgui.Create("DLabel", self.ControlPanel)
	self.ItemDesc:SetPos(10, 45)
	self.ItemDesc:SetSize(280, 60)
	self.ItemDesc:SetFont("DermaDefault")
	self.ItemDesc:SetTextColor(Color(200, 200, 200))
	self.ItemDesc:SetText("")
	self.ItemDesc:SetWrap(true)
	self.ItemDesc:SetAutoStretchVertical(true)
	
	self.ItemPrice = vgui.Create("DLabel", self.ControlPanel)
	self.ItemPrice:SetPos(10, 115)
	self.ItemPrice:SetSize(280, 30)
	self.ItemPrice:SetFont("DermaLarge")
	self.ItemPrice:SetTextColor(Color(100, 255, 100))
	self.ItemPrice:SetText("")
	
	-- Camera Controls Section
	local cameraLabel = vgui.Create("DLabel", self.ControlPanel)
	cameraLabel:SetPos(10, 160)
	cameraLabel:SetSize(280, 20)
	cameraLabel:SetFont("DermaDefaultBold")
	cameraLabel:SetTextColor(Color(255, 255, 255))
	cameraLabel:SetText("Camera Controls")
	
	-- Horizontal Rotation Slider
	local rotHLabel = vgui.Create("DLabel", self.ControlPanel)
	rotHLabel:SetPos(10, 185)
	rotHLabel:SetSize(100, 20)
	rotHLabel:SetFont("DermaDefault")
	rotHLabel:SetTextColor(Color(200, 200, 200))
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
	pitchLabel:SetTextColor(Color(200, 200, 200))
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
	zoomLabel:SetTextColor(Color(200, 200, 200))
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
					LocalPlayer():PS_BuyItem(self.ItemData.ID)
					self:Close()
				end,
				nil
			)
		end
	end
	self.BuyButton.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		-- Green gradient background
		local baseGreen = 80 + s._hoverAlpha * 30
		draw.RoundedBox(6, 0, 0, w, h, Color(40, baseGreen, 50, 255))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(60, baseGreen + 40, 70, 100))
		
		-- Outer glow on hover
		if s._hoverAlpha > 0 then
			surface.SetDrawColor(80, 200, 100, s._hoverAlpha * 80)
			surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
			surface.SetDrawColor(80, 200, 100, s._hoverAlpha * 40)
			surface.DrawOutlinedRect(-2, -2, w + 4, h + 4)
		end
		
		-- Border
		surface.SetDrawColor(100, 180, 120, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
		
		-- Text with shadow
		draw.SimpleText("Purchase Item", "DermaLarge", w/2 + 1, h/2 + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Purchase Item", "DermaLarge", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		-- Gray gradient
		local baseGray = 70 + s._hoverAlpha * 20
		draw.RoundedBox(6, 0, 0, w, h, Color(baseGray, baseGray, baseGray + 5, 255))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(baseGray + 20, baseGray + 20, baseGray + 25, 80))
		
		-- Border
		surface.SetDrawColor(110, 110, 115, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
		
		-- Text with shadow
		draw.SimpleText("Back to Shop", "DermaLarge", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Back to Shop", "DermaLarge", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseRed = 140 + s._hoverAlpha * 40
		draw.RoundedBox(4, 0, 0, w, h, Color(baseRed, 40, 40, 200 + s._hoverAlpha * 55))
		draw.RoundedBox(4, 0, 0, w, h/2, Color(baseRed + 40, 60, 60, 80))
		
		-- Glow on hover
		if s._hoverAlpha > 0 then
			surface.SetDrawColor(200, 80, 80, s._hoverAlpha * 100)
			surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
		end
		
		-- X text with shadow
		draw.SimpleText("X", "DermaDefault", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("X", "DermaDefault", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
		self.ItemPrice:SetTextColor(Color(100, 255, 100))
		self.BuyButton:SetEnabled(true)
	else
		self.ItemPrice:SetTextColor(Color(255, 100, 100))
		self.BuyButton:SetEnabled(false)
		self.BuyButton:SetText("Cannot Afford")
	end
	
	-- Try-before-you-buy: accessories get a Customize button that opens the
	-- customization panel in preview-only mode. Staged mods are sent with the
	-- buy request and applied on first equip.
	local isAccessory = itemData.TYPE == "accessory" or itemData.Bone or itemData.Attachment
	if isAccessory and not IsValid(self.CustomizeButton) then
		self.ControlPanel:SetTall(505)
		self.ControlPanel:SetPos(20, ScrH() / 2 - 252)
		self.BackButton:SetPos(10, 410)

		self.CustomizeButton = vgui.Create("DButton", self.ControlPanel)
		self.CustomizeButton:SetPos(10, 360)
		self.CustomizeButton:SetSize(280, 40)
		self.CustomizeButton:SetText("")
		self.CustomizeButton:SetFont("DermaLarge")
		self.CustomizeButton.DoClick = function()
			if not self.ItemData then return end
			local item = self.ItemData
			-- Close first: the Inspector's CalcView hook and preview accessory
			-- would conflict with the customization panel's own preview.
			self:Close()
			local panel = vgui.Create("PSItemCustomizationPanel")
			panel:SetItem(item, true) -- previewOnly
			if PS and PS.ToggleMenu then PS:ToggleMenu() end
		end
		self.CustomizeButton.Paint = function(s, w, h)
			local isHovered = s:IsHovered()
			s._hoverAlpha = s._hoverAlpha or 0
			s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)

			local baseBlue = 90 + s._hoverAlpha * 30
			draw.RoundedBox(6, 0, 0, w, h, Color(40, 60, baseBlue, 255))
			draw.RoundedBox(6, 0, 0, w, h/2, Color(60, 80, baseBlue + 40, 100))

			if s._hoverAlpha > 0 then
				surface.SetDrawColor(100, 140, 220, s._hoverAlpha * 80)
				surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
			end

			surface.SetDrawColor(100, 130, 200, 200)
			surface.DrawOutlinedRect(0, 0, w, h)

			draw.SimpleText("Customize", "DermaLarge", w/2 + 1, h/2 + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("Customize", "DermaLarge", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
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
