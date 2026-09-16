if SERVER then return end

local function ps_dbg(...)
	if ConVarExists("ps_debug") and GetConVar("ps_debug"):GetBool() then print(...) end
end

local PANEL = {}

local function CreateStyledConfirmation(title, message, yesCallback, noCallback)
	return PS.UI.Confirm({ title = title, text = message, onYes = yesCallback, onNo = noCallback })
end

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(true)
	self.ClassName = "DPointShopInspector"
	
	self.OldPlayerModel = LocalPlayer():GetModel()
	self.OldSkin = LocalPlayer():GetSkin()
	self.OldBodygroups = {}
	for i = 0, LocalPlayer():GetNumBodyGroups() - 1 do self.OldBodygroups[i] = LocalPlayer():GetBodygroup(i) end
	if PS and PS.ShopMenu and IsValid(PS.ShopMenu) and PS.ShopMenu:IsVisible() then PS.ShopMenu:Hide() end

	self.State = Framework.UI.State({
		item = nil,
		camera = { rot = 180, height = 0, radius = 80 },
		mods = { scale = 1, offsetX = 0, offsetY = 0, offsetZ = 0, pitch = 0, yaw = 0, roll = 0, color = Color(255, 255, 255) },
		purchased = false
	})

	self.Camera = PS.UI.Orbit("Inspector", {
		rot = 180, height = 0, radius = 80, minRadius = 30, maxRadius = 200,
		OnChange = function(cam) self.State.camera = { rot = cam.rot, height = cam.height, radius = cam.radius } end
	})
	self.State:Subscribe("camera", function(c)
		self.Camera.rot = c.rot; self.Camera.height = c.height; self.Camera.radius = c.radius
	end, false)
	self.State:Subscribe("mods", function(m) self:UpdateStagedMods(m) end)

	self:SetupHooks()
	self:SetupOrbit()

	local S = PS.Theme.Scale()
	local M = PS.Theme.Metrics

	self.ControlPanel = vgui.Create("DPanel", self)
	self.ControlPanel:SetMouseInputEnabled(true)
	self.ControlPanel.Paint = function(s, w, h)
		PS.Theme.PaintFrame(w, h)
		PS.Theme.PaintStatusStrip(w, PS.UI.HeaderH("strip"), "Inspect")
	end

	local closeBtn = PS.UI.IconButton(self.ControlPanel, PS.UI.GlyphIcon("close"), "Danger", function() self:Close() end)
	local sizeSelf = closeBtn.PerformLayout
	closeBtn.PerformLayout = function(s)
		if sizeSelf then sizeSelf(s) end
		s:SetPos(self.ControlPanel:GetWide() - M.IconBtn - M.IconInset, PS.UI.IconBtnY(PS.UI.HeaderH("strip")))
	end

	self.ControlScroll, self.ControlMaster = PS.UI.ControlColumn(self.ControlPanel)
	self.ControlScroll:DockMargin(M.Margin, PS.UI.HeaderH("strip") + M.Margin, M.Margin, M.Margin)
	self.ControlMaster:SetGap(M.Gap)

	self.ControlPanel:SetSize(math.Round(320 * S), math.min(ScrH() - M.Margin * 2, 800 * S))
	self.ControlPanel:SetPos(math.Round(20 * S), math.max(M.Margin, (ScrH() - self.ControlPanel:GetTall()) / 2))
end

function PANEL:SetupHooks()
	hook.Add("CreateMove", "DPointShopInspector_Freeze", function(cmd)
		if not IsValid(self) then return end
		cmd:ClearMovement()
	end)

	hook.Add("PostDrawOpaqueRenderables", "DPointShopInspector_DrawPreview", function()
		if not IsValid(self) then return end
		if IsValid(self.PreviewModel) then
			self.PreviewModel:DrawModel()
		end
	end)
	
	hook.Add("PrePlayerDraw", "DPointShopInspector_HidePlayer", function(ply)
		if ply ~= LocalPlayer() then return end
		if not IsValid(self) then return end
		if IsValid(self.PreviewModel) then return true end
	end)
	
	self.Camera:Start(function() return IsValid(self) end)
end

function PANEL:SetupOrbit()
	self.Camera:Attach(self, function()
		if not IsValid(self.ControlPanel) then return false end
		local mx, my = gui.MousePos()
		local px, py = self.ControlPanel:GetPos()
		local pw, ph = self.ControlPanel:GetSize()
		return mx >= px and mx <= px + pw and my >= py and my <= py + ph
	end)
end

function PANEL:Think()
	if self.OrbitThink then self:OrbitThink() end

	if IsValid(self.PreviewModel) then
		local ply = LocalPlayer()
		if IsValid(ply) then
			self.PreviewModel:SetPos(ply:GetPos())
			self.PreviewModel:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		end
	end
end

local function AddReactiveSlider(parent, label, min, max, dec, stateProxy, stateKey, subKey)
	local sl = vgui.Create("DNumSlider")
	sl:SetText(label)
	sl:SetMin(min)
	sl:SetMax(max)
	sl:SetDecimals(dec)
	sl:SetDark(false)
	if IsValid(sl.Label) then sl.Label:SetTextColor(PS.Theme.Text) end

	sl.OnMousePressed = nil
	local isModifying = false
	sl.OnValueChanged = function(s, v)
		if isModifying then return end
		local cur = stateProxy[stateKey]
		if type(cur) == "table" and subKey then
			local n = table.Copy(cur); n[subKey] = v; stateProxy[stateKey] = n
		else
			stateProxy[stateKey] = v
		end
	end

	stateProxy:Subscribe(stateKey, function(val)
		isModifying = true
		sl:SetValue(subKey and val[subKey] or val)
		isModifying = false
	end)
	parent:AddNode(sl, 0, PS.Theme.Metrics.ButtonH)
end

local function AddText(parent, text, font, color, align, lines, wrap)
	local l = vgui.Create("DLabel")
	l:SetText(text)
	l:SetFont(font or "PS_DefaultBold")
	l:SetTextColor(color or PS.Theme.Text)
	l:SetContentAlignment(align == "center" and 5 or 7)
	if wrap ~= false then l:SetWrap(true) end
	surface.SetFont(font or "PS_DefaultBold")
	local _, lh = surface.GetTextSize("Wg")
	parent:AddNode(l, 0, math.Round(lh * (lines or 1)))
	return l
end

local function AddHeader(parent, text)
	local l = vgui.Create("DLabel")
	l:SetText(text)
	l:SetFont("PS_Heading3")
	l:SetTextColor(PS.Theme.Text)
	l:SetContentAlignment(5)
	parent:AddNode(l, 0, PS.Theme.Metrics.ButtonH)
	return l
end

function PANEL:BuildControls()
	local item = self.State.item
	if not item then return end
	
	local M = PS.Theme.Metrics
	self.ControlMaster:Clear()

	local function Space(mult)
		local p = vgui.Create("DPanel")
		p.Paint = function() end
		self.ControlMaster:AddNode(p, 0, M.Gap * (mult or 1))
	end

	-- Name and description
	AddText(self.ControlMaster, item.Name or "Unknown", "PS_LargeTitle", PS.Theme.Text, "center", 1, false)
	AddText(self.ControlMaster, item.Description or "", "PS_Default", PS.Theme.Text, "left", 3)
	
	local price = PS.Config.CalculateBuyPrice(LocalPlayer(), item)
	local priceStr = string.Comma(price)
	local pointsLabel = PS.Config.PointsName .. ":"

	surface.SetFont("PS_LargeTitle")
	local priceW, priceH = surface.GetTextSize(priceStr)
	surface.SetFont("PS_Default")
	local labelW, _ = surface.GetTextSize(pointsLabel)

	local priceRow = vgui.Create("DPanel")
	priceRow.Paint = function(s, w, h)
		-- Number centered
		draw.SimpleText(priceStr, "PS_LargeTitle", w / 2, h / 2, PS.Theme.PriceAfford, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		-- "Points:" tucked to the left of the number
		local numLeft = (w - priceW) / 2
		draw.SimpleText(pointsLabel, "PS_Default", numLeft - 6, h / 2, PS.Theme.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	self.ControlMaster:AddNode(priceRow, 0, priceH)

	Space(2)
	
	-- Camera block in a themed box
	local sliderH = M.ButtonH
	local camRows = 4 -- header + 3 sliders
	local camH = M.Margin * 2 + sliderH * camRows + M.Gap * (camRows - 1)

	local camBox = vgui.Create("DPanel")
	camBox.Paint = function(s, w, h) PS.Theme.PaintPanelBody(w, h) end

	local camHeader = vgui.Create("DLabel", camBox)
	camHeader:SetText("Camera")
	camHeader:SetFont("PS_Heading3")
	camHeader:SetTextColor(PS.Theme.Text)
	camHeader:SetContentAlignment(5)
	camHeader:SetTall(sliderH)
	camHeader:Dock(TOP)
	local function camSlider(label, min, max, dec, stateKey, subKey)
		local sl = vgui.Create("DNumSlider", camBox)
		sl:Dock(TOP)
		sl:DockMargin(0, M.Gap, 0, 0)
		sl:SetTall(sliderH)
		sl:SetText(label)
		sl:SetMin(min)
		sl:SetMax(max)
		sl:SetDecimals(dec)
		sl:SetDark(false)
		if IsValid(sl.Label) then sl.Label:SetTextColor(PS.Theme.Text) end

		local updating = false
		sl.OnValueChanged = function(s, v)
			if updating then return end
			local cur = table.Copy(self.State[stateKey])
			cur[subKey] = v
			self.State[stateKey] = cur
		end
		self.State:Subscribe(stateKey, function(val)
			updating = true
			sl:SetValue(val[subKey])
			updating = false
		end)
	end
	camSlider("Rotation", 0, 360, 0, "camera", "rot")
	camSlider("Height", -100, 100, 0, "camera", "height")
	camSlider("Distance", self.Camera.minRadius, self.Camera.maxRadius, 0, "camera", "radius")
	camBox:DockPadding(M.Margin, M.Margin, M.Margin, M.Margin)

	self.ControlMaster:AddNode(camBox, 0, camH)

	Space(2)
	local btnBuy = vgui.Create("DButton")
	btnBuy:SetText("")
	btnBuy.Paint = function(s, w, h)
		local off = s:GetDisabled()
		PS.Theme.PaintAction(s, w, h, off and PS.Theme.Action.Neutral or PS.Theme.Action.Positive, off and "Cannot Afford" or "Purchase Item")
	end
	btnBuy.DoClick = function()
		CreateStyledConfirmation("Buy Item", "Are you sure you want to buy " .. item.Name .. "?", function()
			if self.StagedItemID then
				PS_PendingCustomizationData = PS_PendingCustomizationData or {}
				PS_PendingCustomizationData[(item.TYPE or "accessory") .. "_" .. item.ID] = self.StagedMods
				self.State.purchased = true
			end
			LocalPlayer():PS_BuyItem(item.ID)
			self:Close()
		end, nil)
	end
	self.ControlMaster:AddNode(btnBuy, 0, M.ButtonH)

	local btnBack = vgui.Create("DButton")
	btnBack:SetText("")
	btnBack.Paint = function(s, w, h) PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Neutral, "Back to Shop") end
	btnBack.DoClick = function() self:Close() end
	self.ControlMaster:AddNode(btnBack, 0, M.ButtonH)

	self.ControlMaster:InvalidateLayout(true)
	
	-- Shrink the outer panel to precisely fit the flexbox contents
	local targetHeight = self.ControlMaster:GetTall() + PS.UI.HeaderH("strip") + M.Margin * 2
	local clampedHeight = math.min(ScrH() - M.Margin * 2, targetHeight)
	
	self.ControlPanel:SetSize(math.Round(320 * PS.Theme.Scale()), clampedHeight)
	self.ControlPanel:SetPos(math.Round(20 * PS.Theme.Scale()), math.max(M.Margin, (ScrH() - clampedHeight) / 2))
end

function PANEL:SetItem(itemData)
	self.ItemData = itemData
	self.State.item = itemData
	if not itemData then return end
	local itemID = itemData.ID or itemData.Model
	self.StagedItemID = itemID
	
	local dm = (PS_GetItemDefault and PS_GetItemDefault(itemID)) or itemData.DefaultModifications or {}
	local dc = Color(255, 255, 255)
	if dm.color then dc = Color(dm.color.r or dm.color[1] or 255, dm.color.g or dm.color[2] or 255, dm.color.b or dm.color[3] or 255, dm.color.a or dm.color[4] or 255) end
	
	self.State.mods = {
		scale = dm.scale or 1,
		offsetX = dm.offset and (dm.offset[1] or dm.offset.x) or 0,
		offsetY = dm.offset and (dm.offset[2] or dm.offset.y) or 0,
		offsetZ = dm.offset and (dm.offset[3] or dm.offset.z) or 0,
		pitch = dm.ang and dm.ang[1] or 0,
		yaw = dm.ang and dm.ang[2] or 0,
		roll = dm.ang and dm.ang[3] or 0,
		color = dc
	}

	self:BuildControls()
	timer.Simple(0.05, function() if IsValid(self) then self:ApplyPreview() end end)
end

function PANEL:UpdateStagedMods(m)
	if not self.StagedItemID then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	self.StagedMods = {
		scale = m.scale,
		offset = { m.offsetX, m.offsetY, m.offsetZ },
		ang = { m.pitch, m.yaw, m.roll },
		color = { r = m.color.r, g = m.color.g, b = m.color.b, a = 255 }
	}

	PS_AccessoryCustomizations = PS_AccessoryCustomizations or {}
	PS_AccessoryCustomizations[ply] = PS_AccessoryCustomizations[ply] or {}
	PS_AccessoryCustomizations[ply][self.StagedItemID] = self.StagedMods
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
	if self.StagedItemID and not self.State.purchased then
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
	if self.Camera then self.Camera:Stop() end
	hook.Remove("CreateMove", "DPointShopInspector_Freeze")
	
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
	if self.Camera then self.Camera:Stop() end
	hook.Remove("CreateMove", "DPointShopInspector_Freeze")
end

function PANEL:Paint(w, h)
	-- Camera view is rendered by the game's CalcView hook
	-- Preview model is rendered by PostDrawOpaqueRenderables hook
	-- Keep transparent to not block 3D view
end

vgui.Register("DPointShopInspector", PANEL, "EditablePanel")




