local PANEL = {}

local adminicon  = Material("icon16/shield.png")
local groupicon  = Material("icon16/group.png")

local LABEL_H = 38

local COL_BG         = Color(35, 35, 40,  255)
local COL_EQUIPPED   = Color(200, 170, 50, 255)
local COL_OWNED      = Color(60,  140, 200, 255)
local COL_CAN_BUY    = Color(50,  160, 70,  220)
local COL_CANT_BUY   = Color(160, 50,  50,  220)
local COL_BORDER_DEF = Color(70,  70,  75,  200)

-- ============================================================================
-- STYLED CONFIRMATION DIALOG
-- ============================================================================

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
		draw.SimpleText(title, "DermaLarge", w/2,     20, Color(200, 220, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha or 0, s:IsHovered() and 1 or 0)
		local g = 80 + s._hoverAlpha * 30
		draw.RoundedBox(6, 0, 0, w, h, Color(40, g, 50, 255))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(60, g + 40, 70, 100))
		if s._hoverAlpha > 0 then
			surface.SetDrawColor(80, 200, 100, s._hoverAlpha * 80)
			surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
		end
		surface.SetDrawColor(100, 180, 120, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("Yes", "DermaLarge", w/2 + 1, h/2 + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Yes", "DermaLarge", w/2,     h/2,     Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha or 0, s:IsHovered() and 1 or 0)
		local c = 70 + s._hoverAlpha * 20
		draw.RoundedBox(6, 0, 0, w, h, Color(c, c, c + 5, 255))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(c + 20, c + 20, c + 25, 80))
		surface.SetDrawColor(110, 110, 115, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("No", "DermaLarge", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("No", "DermaLarge", w/2,     h/2,     Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return frame
end

-- ============================================================================
-- ITEM PANEL
-- ============================================================================

function PANEL:Init()
	self.Info = ""
	self.InfoHeight = LABEL_H
	self._hoverAlpha = 0
end

function PANEL:DoClick()
	local points = PS.Config.CalculateBuyPrice(LocalPlayer(), self.Data)

	if not LocalPlayer():PS_HasItem(self.Data.ID) and not LocalPlayer():PS_HasPoints(points) then
		notification.AddLegacy("You don't have enough " .. PS.Config.PointsName .. " for this!", NOTIFY_GENERIC, 5)
	end

	if IsValid(PS._ItemPopupMenu) then PS._ItemPopupMenu:Remove() end

	local menu = vgui.Create("DPanel")
	menu:SetPos(gui.MouseX(), gui.MouseY())
	menu:SetSize(180, 10)
	menu:MakePopup()
	menu:SetKeyboardInputEnabled(false)

	menu.Paint = function(s, w, h)
		draw.RoundedBox(6, 0, 0, w, h, Color(40, 40, 45, 250))
		for i = 0, h, 2 do
			surface.SetDrawColor(0, 0, 0, math.min(60, i * 0.1))
			surface.DrawRect(3, i, w - 6, 1)
		end
		surface.SetDrawColor(60, 120, 180, 120)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local yPos = 5
	local BH = 28

	local function AddMenuButton(text, col, callback)
		local btn = vgui.Create("DButton", menu)
		btn:SetPos(5, yPos)
		btn:SetSize(170, BH)
		btn:SetText("")
		btn.DoClick = function() menu:Remove() callback() end
		btn.Paint = function(s, w, h)
			s._hoverAlpha = Lerp(FrameTime() * 12, s._hoverAlpha or 0, s:IsHovered() and 1 or 0)
			if s._hoverAlpha > 0 then
				draw.RoundedBox(4, 0, 0, w, h, Color(col.r + 20, col.g + 20, col.b + 20, s._hoverAlpha * 200))
			end
			draw.SimpleText(text, "DermaDefault", 8, h/2,
				s._hoverAlpha > 0 and Color(255, 255, 255) or Color(200, 200, 200),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		yPos = yPos + BH + 3
	end

	local function AddSpacer()
		yPos = yPos + 5
		local line = vgui.Create("DPanel", menu)
		line:SetPos(10, yPos)
		line:SetSize(160, 1)
		line.Paint = function(s, w, h)
			surface.SetDrawColor(60, 60, 65, 150)
			surface.DrawRect(0, 0, w, h)
		end
		yPos = yPos + 8
	end

	if LocalPlayer():PS_HasItem(self.Data.ID) then
		AddMenuButton("Sell", Color(180, 80, 60), function()
			CreateStyledConfirmation("Sell Item",
				"Are you sure you want to sell " .. self.Data.Name .. "?",
				function() LocalPlayer():PS_SellItem(self.Data.ID) end, nil)
		end)
	elseif LocalPlayer():PS_HasPoints(points) then
		AddMenuButton("Buy", Color(60, 160, 80), function()
			CreateStyledConfirmation("Buy Item",
				"Are you sure you want to buy " .. self.Data.Name .. "?",
				function() LocalPlayer():PS_BuyItem(self.Data.ID) end, nil)
		end)
	end

	if not LocalPlayer():PS_HasItem(self.Data.ID) and self.Data.Model then
		AddMenuButton("Inspect", Color(60, 120, 180), function()
			local inspector = vgui.Create("DPointShopInspector")
			inspector:SetItem(self.Data)
		end)
	end

	if LocalPlayer():PS_HasItem(self.Data.ID) then
		AddSpacer()
		if LocalPlayer():PS_HasItemEquipped(self.Data.ID) then
			AddMenuButton("Holster", Color(100, 100, 100), function()
				LocalPlayer():PS_HolsterItem(self.Data.ID)
			end)
		else
			AddMenuButton("Equip", Color(60, 140, 200), function()
				LocalPlayer():PS_EquipItem(self.Data.ID)
			end)
		end

		if LocalPlayer():PS_HasItemEquipped(self.Data.ID) and self.Data.Modify then
			AddSpacer()
			AddMenuButton("Modify...", Color(140, 100, 200), function()
				PS.Items[self.Data.ID]:Modify(LocalPlayer())
			end)
		end

	end

	menu:SetTall(yPos + 5)
	PS._ItemPopupMenu = menu

	menu.Think = function(s)
		if not input.IsMouseDown(MOUSE_LEFT) then
			s._canClose = true
		elseif s._canClose and input.IsMouseDown(MOUSE_LEFT) then
			local x, y = s:LocalCursorPos()
			if x < 0 or y < 0 or x > s:GetWide() or y > s:GetTall() then
				s:Remove()
			end
		end
	end
end

-- SetData kept identical to original to preserve DModelPanel rendering
function PANEL:SetData(data)
	self.Data = data
	self.Info = data.Name

	if data.Model then
		local DModelPanel = vgui.Create('DModelPanel', self)
		DModelPanel:SetModel(data.Model)
		DModelPanel:Dock(FILL)

		if data.Skin then
			DModelPanel:SetSkin(data.Skin)
		end

		local PrevMins, PrevMaxs = DModelPanel.Entity:GetRenderBounds()
		DModelPanel:SetCamPos(PrevMins:Distance(PrevMaxs) * Vector(0.5, 0.5, 0.5))
		DModelPanel:SetLookAt((PrevMaxs + PrevMins) / 2)

		function DModelPanel:LayoutEntity(ent)
			if self:GetParent().Hovered then
				ent:SetAngles(Angle(0, ent:GetAngles().y + 2, 0))
			end

			local ITEM = PS.Items[data.ID]
			ITEM:ModifyClientsideModel(LocalPlayer(), ent, Vector(), Angle())
		end

		function DModelPanel:DoClick()         self:GetParent():DoClick()         end
		function DModelPanel:OnCursorEntered() self:GetParent():OnCursorEntered() end
		function DModelPanel:OnCursorExited()  self:GetParent():OnCursorExited()  end
	else
		local DImageButton = vgui.Create('DImageButton', self)
		DImageButton:SetMaterial(data.Material)
		DImageButton.m_Image.FrameTime = 0
		DImageButton:Dock(FILL)

		function DImageButton:DoClick()         self:GetParent():DoClick()         end
		function DImageButton:OnCursorEntered() self:GetParent():OnCursorEntered() end
		function DImageButton:OnCursorExited()  self:GetParent():OnCursorExited()  end

		function DImageButton.m_Image:Paint(w, h)
			if not self:GetParent():GetParent().Data.NoScroll and self:GetParent():GetParent().Hovered then
				self.FrameTime = self.FrameTime + 1
			end
			self:PaintAt(0, self.FrameTime % self:GetTall() - self:GetTall(), self:GetWide(), self:GetTall())
			self:PaintAt(0, self.FrameTime % self:GetTall(),                  self:GetWide(), self:GetTall())
		end
	end

	if data.Description then
		self:SetTooltip(data.Description)
	end
end

-- ============================================================================
-- PAINT
-- ============================================================================

function PANEL:Paint(w, h)
	if not self.Data then return end

	local ply        = LocalPlayer()
	local isOwned    = ply:PS_HasItem(self.Data.ID)
	local isEquipped = ply:PS_HasItemEquipped(self.Data.ID)
	local points     = PS.Config.CalculateBuyPrice(ply, self.Data)
	local canAfford  = ply:PS_HasPoints(points)

	self._hoverAlpha = Lerp(FrameTime() * 8, self._hoverAlpha, self.Hovered and 1 or 0)

	-- Base background
	draw.RoundedBox(6, 0, 0, w, h, COL_BG)

	-- State-based border
	local bc
	if isEquipped then
		bc = COL_EQUIPPED
	elseif isOwned then
		bc = COL_OWNED
	elseif self._hoverAlpha > 0 then
		bc = Color(90, 90, 95, self._hoverAlpha * 180)
	end

	if bc then
		surface.SetDrawColor(bc.r, bc.g, bc.b, (bc.a or 255) * 0.4)
		surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
		surface.SetDrawColor(bc)
		surface.DrawOutlinedRect(0, 0, w, h)
	else
		surface.SetDrawColor(COL_BORDER_DEF)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
end

function PANEL:PaintOver()
	if not self.Data then return end
	local w, h = self:GetSize()

	local ply        = LocalPlayer()
	local isOwned    = ply:PS_HasItem(self.Data.ID)
	local isEquipped = ply:PS_HasItemEquipped(self.Data.ID)
	local points     = PS.Config.CalculateBuyPrice(ply, self.Data)
	local canAfford  = ply:PS_HasPoints(points)

	-- Bottom gradient overlay (drawn over model)
	for i = 0, LABEL_H do
		local a = math.min(230, (LABEL_H - i) * (230 / LABEL_H))
		surface.SetDrawColor(18, 18, 22, a)
		surface.DrawRect(1, h - LABEL_H + i, w - 2, 1)
	end

	-- Item name
	draw.SimpleText(self.Data.Name, "PS_ItemText", w/2 + 1, h - LABEL_H/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(self.Data.Name, "PS_ItemText", w/2,     h - LABEL_H/2,     Color(255, 255, 255),  TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Status badge pill (top-right)
	local badgeText, badgeCol
	if isEquipped then
		badgeText = "EQUIPPED"
		badgeCol  = COL_EQUIPPED
	elseif isOwned then
		badgeText = "OWNED"
		badgeCol  = COL_OWNED
	elseif canAfford then
		badgeText = "-" .. points
		badgeCol  = COL_CAN_BUY
	else
		badgeText = "-" .. points
		badgeCol  = COL_CANT_BUY
	end

	surface.SetFont("PS_ItemText")
	local tw = surface.GetTextSize(badgeText)
	local pad = 5
	local bw  = tw + pad * 2
	local bh  = 16
	local bx  = w - bw - 4
	local by  = 4

	draw.RoundedBox(4, bx, by, bw, bh, badgeCol)
	draw.RoundedBox(4, bx, by, bw, bh / 2, Color(255, 255, 255, 20))
	draw.SimpleText(badgeText, "PS_ItemText", bx + bw/2, by + bh/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Admin icon (top-left)
	if self.Data.AdminOnly then
		surface.SetMaterial(adminicon)
		surface.SetDrawColor(255, 220, 80, 230)
		surface.DrawTexturedRect(5, 5, 14, 14)
	end

	-- Group restriction icon
	if self.Data.AllowedUserGroups and #self.Data.AllowedUserGroups > 0 then
		surface.SetMaterial(groupicon)
		surface.SetDrawColor(200, 200, 200, 180)
		surface.DrawTexturedRect(5, h - LABEL_H - 18, 14, 14)
	end

	-- Color swatch for tinted items
	local pItems = ply.PS_Items
	if pItems and pItems[self.Data.ID] and pItems[self.Data.ID].Modifiers and pItems[self.Data.ID].Modifiers.color then
		local col = pItems[self.Data.ID].Modifiers.color
		draw.RoundedBox(3, 5, h - LABEL_H - 18, 12, 12, Color(col.r or 255, col.g or 255, col.b or 255, 255))
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawOutlinedRect(5, h - LABEL_H - 18, 12, 12)
	end
end

-- ============================================================================
-- CURSOR
-- ============================================================================

function PANEL:OnCursorEntered()
	self.Hovered = true
	self.Info = LocalPlayer():PS_HasItem(self.Data.ID)
		and ('+' .. PS.Config.CalculateSellPrice(LocalPlayer(), self.Data))
		or  ('-' .. PS.Config.CalculateBuyPrice(LocalPlayer(), self.Data))
	PS:SetHoverItem(self.Data.ID)
end

function PANEL:OnCursorExited()
	self.Hovered = false
	self.Info = self.Data.Name
	PS:RemoveHoverItem()
end

vgui.Register('DPointShopItem', PANEL, 'DPanel')
