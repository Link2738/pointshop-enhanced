-- Callbacks for admin item requests (keyed by entity index)
local _adminItemsCallbacks = {}

local PANEL = {}

function PANEL:Init()
	self:SetSize(1200, 600)
	self:Center()
	self:SetTitle("")
	self:SetDraggable(true)
	self:SetSizable(true)
	self:ShowCloseButton(false)
	self:MakePopup()
	
	-- Header
	self.Header = vgui.Create("DPanel", self)
	self.Header:Dock(TOP)
	self.Header:SetTall(50)
	self.Header.Paint = function(s, w, h)
		surface.SetDrawColor(30, 30, 30, 255)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(60, 140, 200, 255)
		surface.DrawRect(0, 0, w, 3)
		
		draw.SimpleText("PointShop Admin", "PS_LargeTitle", 15, h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- Close button
	local closeBtn = vgui.Create("DButton", self.Header)
	closeBtn:SetPos(self:GetWide() - 50, 10)
	closeBtn:SetSize(35, 35)
	closeBtn:SetText("")
	closeBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseRed = 140 + s._hoverAlpha * 40
		draw.RoundedBox(6, 0, 0, w, h, Color(baseRed, 40, 40, 200 + s._hoverAlpha * 55))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(baseRed + 40, 60, 60, 80))
		
		draw.SimpleText("X", "PS_Heading2", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("X", "PS_Heading2", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.DoClick = function()
		self:Close()
	end
	
	-- Player list with scrollbar
	self.PlayerList = vgui.Create("DScrollPanel", self)
	self.PlayerList:Dock(FILL)
	self.PlayerList:DockMargin(50, 10, 50, 10)
	
	local sbar = self.PlayerList:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	sbar.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 200))
	end
	sbar.btnGrip.Paint = function(s, w, h)
		draw.RoundedBox(4, 2, 0, w - 4, h, Color(60, 120, 180, 255))
	end
	
	-- List container
	self.ListContainer = vgui.Create("DListLayout", self.PlayerList)
	self.ListContainer:Dock(FILL)
	
	self:PopulatePlayerList()
end

function PANEL:PopulatePlayerList()
	self.ListContainer:Clear()
	
	-- Header row
	local headerPanel = vgui.Create("DPanel", self.ListContainer)
	headerPanel:SetTall(40)
	headerPanel:Dock(TOP)
	headerPanel.Paint = function(s, w, h)
		surface.SetDrawColor(45, 45, 50, 255)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(60, 120, 180, 255)
		surface.DrawRect(0, h - 2, w, 2)
		
		draw.SimpleText("Player", "DermaDefaultBold", 15, h / 2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Points", "DermaDefaultBold", w - 550, h / 2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Items", "DermaDefaultBold", w - 450, h / 2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Actions", "DermaDefaultBold", w - 410, h / 2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- Player rows
	for _, ply in ipairs(player.GetAll()) do
		self:AddPlayerRow(ply)
	end
end

function PANEL:AddPlayerRow(ply)
	local row = vgui.Create("DPanel", self.ListContainer)
	row:SetTall(50)
	row:Dock(TOP)
	row:DockMargin(0, 2, 0, 0)
	row.TargetPlayer = ply
	
	row.Paint = function(s, w, h)
		local col = s:IsHovered() and Color(50, 50, 55, 255) or Color(40, 40, 45, 255)
		draw.RoundedBox(4, 0, 0, w, h, col)
		
		-- Player name
		local name = IsValid(ply) and ply:Nick() or "Unknown"
		surface.SetFont("DermaDefault")
		local textW = surface.GetTextSize(name)
		local maxWidth = w - 650  -- Leave space for points, items, actions
		local displayName = name
		if textW > maxWidth then
			-- Truncate and add ellipsis
			while textW > maxWidth - 20 and #displayName > 0 do
				displayName = string.sub(displayName, 1, -2)
				textW = surface.GetTextSize(displayName)
			end
			displayName = displayName .. "..."
		end
		draw.SimpleText(displayName, "DermaDefault", 15, h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		-- Points
		local points = IsValid(ply) and ply:PS_GetPoints() or 0
		draw.SimpleText(points, "DermaDefault", w - 550, h / 2, Color(255, 255, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		-- Item count
		local itemCount = IsValid(ply) and table.Count(ply:PS_GetItems()) or 0
		draw.SimpleText(itemCount, "DermaDefault", w - 450, h / 2, Color(180, 180, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- View Items button
	local viewBtn = vgui.Create("DButton", row)
	viewBtn:SetSize(80, 40)
	viewBtn:SetText("")
	viewBtn.PerformLayout = function(s, w, h)
		s:SetPos(row:GetWide() - 410, 10)
	end
	viewBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local basePurple = 100 + s._hoverAlpha * 30
		draw.RoundedBox(4, 0, 0, w, h, Color(basePurple, 40, basePurple, 200 + s._hoverAlpha * 55))
		draw.SimpleText("View Items", "DermaDefault", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	viewBtn.DoClick = function()
		self:OpenPlayerItemsWindow(ply)
	end
	
	-- Give Points button
	local giveBtn = vgui.Create("DButton", row)
	giveBtn:SetSize(75, 40)
	giveBtn:SetText("")
	giveBtn.PerformLayout = function(s, w, h)
		s:SetPos(row:GetWide() - 330, 10)
	end
	giveBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseGreen = 60 + s._hoverAlpha * 30
		draw.RoundedBox(4, 0, 0, w, h, Color(40, baseGreen, 40, 200 + s._hoverAlpha * 55))
		draw.SimpleText("Give Points", "DermaDefault", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	giveBtn.DoClick = function()
		self:PromptGivePoints(ply)
	end
	
	-- Set Points button
	local setBtn = vgui.Create("DButton", row)
	setBtn:SetSize(75, 40)
	setBtn:SetText("")
	setBtn.PerformLayout = function(s, w, h)
		s:SetPos(row:GetWide() - 255, 10)
	end
	setBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseBlue = 80 + s._hoverAlpha * 30
		draw.RoundedBox(4, 0, 0, w, h, Color(40, 60, baseBlue, 200 + s._hoverAlpha * 55))
		draw.SimpleText("Set Points", "DermaDefault", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	setBtn.DoClick = function()
		self:PromptSetPoints(ply)
	end
	
	-- Initialize button positions
	viewBtn:InvalidateLayout(true)
	giveBtn:InvalidateLayout(true)
	setBtn:InvalidateLayout(true)
	
	-- Give Item button
	local giveItemBtn = vgui.Create("DButton", row)
	giveItemBtn:SetSize(80, 40)
	giveItemBtn:SetText("")
	giveItemBtn.PerformLayout = function(s, w, h)
		s:SetPos(row:GetWide() - 180, 10)
	end
	giveItemBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseOrange = 150 + s._hoverAlpha * 30
		draw.RoundedBox(4, 0, 0, w, h, Color(baseOrange, 100, 40, 200 + s._hoverAlpha * 55))
		draw.SimpleText("Give Item", "DermaDefault", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	giveItemBtn.DoClick = function()
		self:PromptGiveItem(ply)
	end
	
	giveItemBtn:InvalidateLayout(true)
end

function PANEL:OpenPlayerItemsWindow(ply)
	if not IsValid(ply) then return end

	-- PS_Items are only networked to the item owner; request them from the server
	local idx = ply:EntIndex()
	_adminItemsCallbacks[idx] = function(resolvedPly, items)
		if not IsValid(self) then return end
		self:_BuildPlayerItemsWindow(resolvedPly, items)
	end

	net.Start('PS_AdminRequestItems')
		net.WriteEntity(ply)
	net.SendToServer()
end

function PANEL:_BuildPlayerItemsWindow(ply, items)
	if not IsValid(ply) then return end

	local frame = vgui.Create("DFrame")
	frame:SetTitle(ply:Nick() .. "'s Items")
	frame:SetSize(900, 600)
	frame:Center()
	frame:MakePopup()

	local itemCount = table.Count(items)

	if itemCount == 0 then
		local label = vgui.Create("DLabel", frame)
		label:SetText("This player has no items.")
		label:Dock(FILL)
		label:SetContentAlignment(5)
		label:SetFont("DermaLarge")
		return
	end

	-- Scrollable item list
	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)

	local sbar = scroll:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	sbar.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 200))
	end
	sbar.btnGrip.Paint = function(s, w, h)
		draw.RoundedBox(4, 2, 0, w - 4, h, Color(60, 120, 180, 255))
	end

	local list = vgui.Create("DListLayout", scroll)
	list:Dock(FILL)

	-- Add header
	local header = vgui.Create("DPanel", list)
	header:SetTall(45)
	header:Dock(TOP)
	header.Paint = function(s, w, h)
		surface.SetDrawColor(50, 50, 55, 255)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("Item Name", "DermaDefaultBold", 15, h/2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Equipped", "DermaDefaultBold", w - 275, h/2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Actions", "DermaDefaultBold", w - 150, h/2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- Add each item
	for itemID, itemData in pairs(items) do
		local ITEM = PS.Items[itemID]
		if ITEM then
			local itemRow = vgui.Create("DPanel", list)
			itemRow:SetTall(50)
			itemRow:Dock(TOP)
			itemRow:DockMargin(0, 1, 0, 1)

			itemRow.Paint = function(s, w, h)
				local col = s:IsHovered() and Color(50, 50, 55, 255) or Color(40, 40, 45, 255)
				draw.RoundedBox(4, 0, 0, w, h, col)

				-- Item name - clip if too long
				surface.SetFont("DermaDefault")
				local textW = surface.GetTextSize(ITEM.Name)
				local maxWidth = w - 300
				local displayName = ITEM.Name
				if textW > maxWidth then
					-- Truncate and add ellipsis
					while textW > maxWidth - 20 and #displayName > 0 do
						displayName = string.sub(displayName, 1, -2)
						textW = surface.GetTextSize(displayName)
					end
					displayName = displayName .. "..."
				end
				draw.SimpleText(displayName, "DermaDefault", 15, h/2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				local equipped = itemData.Equipped and "Yes" or "No"
				local equipCol = itemData.Equipped and Color(100, 255, 100) or Color(150, 150, 150)
				draw.SimpleText(equipped, "DermaDefault", w - 275, h/2, equipCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			-- Take button
			local takeBtn = vgui.Create("DButton", itemRow)
			takeBtn:SetSize(100, 25)
			takeBtn:SetText("")
			takeBtn.PerformLayout = function(btn, w, h)
				btn:SetPos(itemRow:GetWide() - 120, 12)
			end
			takeBtn.Paint = function(s, w, h)
				local isHovered = s:IsHovered()
				s._hoverAlpha = s._hoverAlpha or 0
				s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)

				local baseRed = 120 + s._hoverAlpha * 40
				draw.RoundedBox(4, 0, 0, w, h, Color(baseRed, 40, 40, 200 + s._hoverAlpha * 55))
				draw.SimpleText("Take Item", "DermaDefault", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			takeBtn.DoClick = function()
				net.Start('PS_TakeItem')
					net.WriteEntity(ply)
					net.WriteString(ITEM.ID)
				net.SendToServer()

				frame:Close()
			end

			takeBtn:InvalidateLayout(true)
		end
	end
end


function PANEL:PromptGivePoints(ply)
	if not IsValid(ply) then return end
	
	local pointsName = (PS and PS.Config and PS.Config.PointsName) or "Points"
	
	local frame = vgui.Create("DFrame")
	frame:SetTitle("Give " .. pointsName .. " to " .. ply:Nick())
	frame:SetSize(300, 120)
	frame:Center()
	frame:MakePopup()
	
	local label = vgui.Create("DLabel", frame)
	label:SetText("Amount:")
	label:Dock(TOP)
	label:DockMargin(5, 10, 5, 5)
	
	local entry = vgui.Create("DNumberWang", frame)
	entry:Dock(TOP)
	entry:DockMargin(5, 0, 5, 5)
	entry:SetValue(100)
	
	local btn = vgui.Create("DButton", frame)
	btn:SetText("Give")
	btn:Dock(TOP)
	btn:DockMargin(5, 5, 5, 5)
	btn.DoClick = function()
		local amount = tonumber(entry:GetValue()) or 0
		net.Start('PS_GivePoints')
			net.WriteEntity(ply)
			net.WriteInt(amount, 32)
		net.SendToServer()
		frame:Close()
		timer.Simple(0.1, function()
			if IsValid(self) then
				self:PopulatePlayerList()
			end
		end)
	end
end

function PANEL:PromptSetPoints(ply)
	if not IsValid(ply) then return end
	
	local pointsName = (PS and PS.Config and PS.Config.PointsName) or "Points"
	
	local frame = vgui.Create("DFrame")
	frame:SetTitle("Set " .. pointsName .. " for " .. ply:Nick())
	frame:SetSize(300, 120)
	frame:Center()
	frame:MakePopup()
	
	local label = vgui.Create("DLabel", frame)
	label:SetText("Amount:")
	label:Dock(TOP)
	label:DockMargin(5, 10, 5, 5)
	
	local entry = vgui.Create("DNumberWang", frame)
	entry:Dock(TOP)
	entry:DockMargin(5, 0, 5, 5)
	entry:SetValue(ply:PS_GetPoints())
	
	local btn = vgui.Create("DButton", frame)
	btn:SetText("Set")
	btn:Dock(TOP)
	btn:DockMargin(5, 5, 5, 5)
	btn.DoClick = function()
		local amount = tonumber(entry:GetValue()) or 0
		net.Start('PS_SetPoints')
			net.WriteEntity(ply)
			net.WriteInt(amount, 32)
		net.SendToServer()
		frame:Close()
		timer.Simple(0.1, function()
			if IsValid(self) then
				self:PopulatePlayerList()
			end
		end)
	end
end

function PANEL:PromptGiveItem(ply)
	if not IsValid(ply) then return end
	
	local frame = vgui.Create("DFrame")
	frame:SetTitle("Give Item to " .. ply:Nick())
	frame:SetSize(900, 600)
	frame:Center()
	frame:MakePopup()
	
	local items = PS.Items
	if not items or table.Count(items) == 0 then
		local label = vgui.Create("DLabel", frame)
		label:SetText("No items available.")
		label:Dock(FILL)
		label:SetContentAlignment(5)
		label:SetFont("DermaLarge")
		return
	end
	
	-- Scrollable item list
	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	
	local sbar = scroll:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	sbar.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 35, 200))
	end
	sbar.btnGrip.Paint = function(s, w, h)
		draw.RoundedBox(4, 2, 0, w - 4, h, Color(60, 120, 180, 255))
	end
	
	local list = vgui.Create("DListLayout", scroll)
	list:Dock(FILL)
	
	-- Add header
	local header = vgui.Create("DPanel", list)
	header:SetTall(45)
	header:Dock(TOP)
	header.Paint = function(s, w, h)
		surface.SetDrawColor(50, 50, 55, 255)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("Item Name", "DermaDefaultBold", 15, h/2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Category", "DermaDefaultBold", w - 200, h/2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Actions", "DermaDefaultBold", w - 120, h/2, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- Add each item
	for itemID, ITEM in pairs(items) do
		local itemRow = vgui.Create("DPanel", list)
		itemRow:SetTall(50)
		itemRow:Dock(TOP)
		itemRow:DockMargin(0, 1, 0, 1)
		
		itemRow.Paint = function(s, w, h)
			local col = s:IsHovered() and Color(50, 50, 55, 255) or Color(40, 40, 45, 255)
			draw.RoundedBox(4, 0, 0, w, h, col)
			
			-- Item name - clip if too long
			surface.SetFont("DermaDefault")
			local textW = surface.GetTextSize(ITEM.Name)
			local maxWidth = w - 250
			local displayName = ITEM.Name
			if textW > maxWidth then
				-- Truncate and add ellipsis
				while textW > maxWidth - 20 and #displayName > 0 do
					displayName = string.sub(displayName, 1, -2)
					textW = surface.GetTextSize(displayName)
				end
				displayName = displayName .. "..."
			end
			draw.SimpleText(displayName, "DermaDefault", 15, h/2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			
			local category = ITEM.Category or "Misc"
			draw.SimpleText(category, "DermaDefault", w - 200, h/2, Color(180, 180, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		
		-- Give button
		local giveBtn = vgui.Create("DButton", itemRow)
		giveBtn:SetSize(100, 25)
		giveBtn:SetText("")
		giveBtn.PerformLayout = function(btn, w, h)
			btn:SetPos(itemRow:GetWide() - 110, 12)
		end
		giveBtn.Paint = function(s, w, h)
			local isHovered = s:IsHovered()
			s._hoverAlpha = s._hoverAlpha or 0
			s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
			
			local baseGreen = 60 + s._hoverAlpha * 30
			draw.RoundedBox(4, 0, 0, w, h, Color(40, baseGreen, 40, 200 + s._hoverAlpha * 55))
			draw.SimpleText("Give Item", "DermaDefault", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		giveBtn.DoClick = function()
			net.Start('PS_GiveItem')
				net.WriteEntity(ply)
				net.WriteString(ITEM.ID)
			net.SendToServer()
			frame:Close()
			timer.Simple(0.1, function()
				if IsValid(self) then
					self:PopulatePlayerList()
				end
			end)
		end
		
		giveBtn:InvalidateLayout(true)
	end
end

function PANEL:Paint(w, h)
	draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 45, 255))
	
	-- Gradient overlay
	for i = 8, h - 8 do
		local alpha = math.min(100, i * 0.15)
		surface.SetDrawColor(0, 0, 0, alpha)
		surface.DrawRect(8, i, w - 16, 1)
	end
	
	-- Border glow
	surface.SetDrawColor(60, 120, 180, 100)
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.SetDrawColor(60, 120, 180, 50)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
end

vgui.Register('DPointShopAdmin', PANEL, 'DFrame')

-- Receive admin item data from server and fire the waiting callback
net.Receive('PS_AdminItemsResponse', function()
	local ply = net.ReadEntity()
	local items = net.ReadTable()
	local idx = IsValid(ply) and ply:EntIndex() or -1
	if _adminItemsCallbacks[idx] then
		_adminItemsCallbacks[idx](ply, items)
		_adminItemsCallbacks[idx] = nil
	end
end)
