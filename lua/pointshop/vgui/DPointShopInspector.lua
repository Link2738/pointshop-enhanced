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
	
	-- The control panel, built by PS.UI.Rows rather than from written-down coordinates.
	--
	-- Every position in here used to be a literal -- SetPos(10, 45), (10, 115), (10, 160) --
	-- and every size was 280 wide against a panel of 300. Correct at one scale and nowhere
	-- else, and the shop's scale is something the player sets, so at 2x the inspector stayed
	-- small while the window that opened it grew.
	--
	-- The rows also mean the panel's HEIGHT is measured rather than declared. It was 450, which
	-- had to be re-guessed by hand every time a control was added -- and the customize section
	-- below adds six sliders and a colour mixer conditionally, so 450 was only ever right for
	-- one of the two shapes this panel takes.
	self.ControlPanel = vgui.Create("DPanel", self)
	self.ControlPanel:SetMouseInputEnabled(true)

	-- The same status strip every other window in the addon uses as its header. This panel is
	-- not a DFrame, so it cannot go through UI.SetupFrame -- but the header is the frame's one
	-- part that is pure paint, and painting it here is what keeps this window a sibling of the
	-- others rather than the one with a bold label floating where a header should be.
	self.ControlPanel.Paint = function(s, w, h)
		PS.Theme.PaintFrame(w, h)
		PS.Theme.PaintStatusStrip(w, PS.UI.HeaderH("strip"), "Inspect")
	end

	-- The shared orbit camera. It owns the rotation, height, distance and tilt; the sliders
	-- below and the mouse are two ways of writing the same four numbers.
	self.Camera = PS.UI.Orbit("Inspector", {
		rot = 180, height = 0, radius = 80,
		minRadius = 30, maxRadius = 200,

		-- The mouse moved the camera, so the sliders have to catch up or they and the view
		-- disagree the moment you drag.
		OnChange = function(cam)
			if IsValid(self.RotationSlider) then self.RotationSlider:SetValue(cam.rot) end
			if IsValid(self.PitchSlider)    then self.PitchSlider:SetValue(cam.height) end
			if IsValid(self.ZoomSlider)     then self.ZoomSlider:SetValue(cam.radius) end
		end,
	})

	self.PreviewModel = nil

	-- Setup camera and rendering hooks
	self:SetupOrbit()
	self:SetupHooks()
end

function PANEL:SetupHooks()
	-- Stand still while being inspected.
	--
	-- The panel sets SetKeyboardInputEnabled(false) so it does not eat typing, which means WASD
	-- reaches the game -- and the inspector previews on the player's own character, so walking
	-- around carried the model you are looking at out of frame.
	--
	-- ClearMovement in CreateMove rather than a movetype change: the command itself goes to the
	-- server with its movement zeroed, so the player genuinely does not move rather than moving
	-- server-side and being corrected. Buttons are untouched, and the view angles are left
	-- alone -- mouse look and the scroll wheel are what drive the orbit.
	hook.Add("CreateMove", "DPointShopInspector_Freeze", function(cmd)
		if not IsValid(self) then return end
		cmd:ClearMovement()
	end)

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
	
	-- The camera itself is PS.UI.Orbit's, shared with the customization panel.
	self.Camera:Start(function() return IsValid(self) end)
end

-- Lays the control panel out, in order, for one item.
--
-- Built here rather than in Init because the shape depends on the item: an accessory gets seven
-- customization sliders and a colour mixer, everything else does not. The old version built the
-- fixed parts in Init at written-down positions, then added the customization ones starting at
-- a literal y = 310, then MOVED the buttons down and re-grew the panel to fit -- three places
-- that each had to agree about a layout none of them owned.
--
-- Rebuilt from scratch each time, which matters now that PS.UI.Open reuses one inspector: a
-- second Inspect on a different item would otherwise keep the first item's sliders.
function PANEL:BuildControls(itemData)
	local S = PS.Theme.Scale()
	local M = PS.Theme.Metrics

	self.ControlPanel:Clear()

	-- Below the strip the panel paints for itself, so the item name does not start underneath
	-- the close button.
	local rows = PS.UI.Rows(self.ControlPanel, nil, PS.UI.HeaderH("strip") + M.Margin)

	self.ItemName  = rows:Text("", { font = "PS_LargeTitle", colour = PS.Theme.Text,
		lines = 1, align = "center" })
	self.ItemDesc  = rows:Text("", { lines = 3 })
	self.ItemPrice = rows:Text("", { font = "PS_LargeTitle", colour = PS.Theme.PriceAfford,
		lines = 1, align = "center" })

	rows:Space(2)
	rows:Header("Camera")

	local cam = self.Camera

	self.RotationSlider = rows:Slider({ label = "Rotation", min = 0, max = 360,
		get = function() return cam.rot end,
		set = function(v) cam.rot = v end })

	self.PitchSlider = rows:Slider({ label = "Height", min = -100, max = 100,
		get = function() return cam.height end,
		set = function(v) cam.height = v end })

	self.ZoomSlider = rows:Slider({ label = "Distance", min = cam.minRadius, max = cam.maxRadius,
		get = function() return cam.radius end,
		set = function(v) cam.radius = v end })

	-- The panel sits over a live 3D view, and a slider that captures the mouse eats the
	-- drag-to-orbit that view exists for.
	for _, sl in ipairs({ self.RotationSlider, self.PitchSlider, self.ZoomSlider }) do
		sl.OnMousePressed = nil
	end

	-- Try-before-you-buy, for accessories only.
	local isAccessory = itemData.TYPE == "accessory" or itemData.Bone or itemData.Attachment
	if isAccessory then
		rows:Space(2)
		self:CustomizationRows(rows, itemData)
	end

	rows:Space(2)

	self.BuyButton = rows:Button("Purchase Item", "Positive", function()
		if not self.ItemData then return end

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
	end)

	-- Repainted from the disabled state rather than the style it was built with. SetText on it
	-- did nothing -- the label is drawn by the Paint function, not by the button -- so the old
	-- "Cannot Afford" never appeared and an unaffordable item just refused clicks.
	self.BuyButton.Paint = function(s, w, h)
		local off = s:GetDisabled()
		PS.Theme.PaintAction(s, w, h,
			off and PS.Theme.Action.Neutral or PS.Theme.Action.Positive,
			off and "Cannot Afford" or "Purchase Item")
	end

	rows:Button("Back to Shop", "Neutral", function() self:Close() end)

	-- The X sits in the header strip rather than in the run of rows, and is the same glyph
	-- button every other window uses instead of an "X" from two SimpleText calls.
	local close = PS.UI.IconButton(self.ControlPanel, PS.UI.GlyphIcon("close"), "Danger", function()
		self:Close()
	end)

	local sizeSelf = close.PerformLayout
	close.PerformLayout = function(s)
		if sizeSelf then sizeSelf(s) end
		s:SetPos(self.ControlPanel:GetWide() - M.IconBtn - M.IconInset,
			math.floor((PS.UI.HeaderH("strip") - M.IconBtn) / 2))
	end

	-- Sized from what is in it, then centred. Both numbers were written down before, and the
	-- height had to be re-guessed by hand every time a control was added.
	self.ControlPanel:SetSize(math.Round(320 * S), rows:Height() + M.Margin)
	self.ControlPanel:SetPos(math.Round(20 * S),
		math.max(M.Margin, (ScrH() - self.ControlPanel:GetTall()) / 2))
end

function PANEL:SetItem(itemData)
	self.ItemData = itemData

	if not itemData then return end

	self:BuildControls(itemData)

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
function PANEL:CustomizationRows(rows, itemData)
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

	rows:Header("Customize")

	-- The qualifier moved out of the header when the headers became one word each. It is not
	-- decoration -- these sliders change nothing until the item is actually bought.
	rows:Text("Applies when you buy.", { lines = 1, colour = PS.Theme.TextDim })

	-- Rows guards the seeding itself, which is what these needed: a DNumSlider fires
	-- OnValueChanged a frame after SetValue, so filling seven sliders in with the item's
	-- defaults arrived as the player having dragged all seven -- staging modifications they
	-- never made onto an item they have not bought.
	local function Slider(label, min, max, default, decimals)
		return rows:Slider({
			label = label, min = min, max = max, decimals = decimals,
			get = function() return default end,
			set = function() self:UpdateStagedMods() end,
		})
	end

	self.CustScale   = Slider("Scale",    0.1,  2,   defScale, 2)
	self.CustOffsetX = Slider("Offset X", -30,  30,  defOX,    1)
	self.CustOffsetY = Slider("Offset Y", -30,  30,  defOY,    1)
	self.CustOffsetZ = Slider("Offset Z", -30,  30,  defOZ,    1)
	self.CustPitch   = Slider("Pitch",    -180, 180, defP,     0)
	self.CustYaw     = Slider("Yaw",      -180, 180, defYaw,   0)
	self.CustRoll    = Slider("Roll",     -180, 180, defR,     0)

	-- The mixer is a control Rows knows nothing about, which is what Custom is for: the caller
	-- builds it and says how tall, the row places it and moves on.
	self.CustColor = vgui.Create("DColorMixer", self.ControlPanel)
	self.CustColor:SetPalette(false)
	self.CustColor:SetAlphaBar(false)
	self.CustColor:SetWangs(true)
	self.CustColor:SetColor(defColor)
	self.CustColor.ValueChanged = function() self:UpdateStagedMods() end

	rows:Custom(self.CustColor, 110)

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

-- Drag, wheel and shift-wheel. The panel is fullscreen, so it is the input surface for the
-- whole 3D view -- everything except its own control panel.
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
	self:OrbitThink()

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
