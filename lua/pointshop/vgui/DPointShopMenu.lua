-- Font definitions
surface.CreateFont('PS_Heading', { font = 'coolvetica', size = 64 })
surface.CreateFont('PS_Heading2', { font = 'coolvetica', size = 24 })
surface.CreateFont('PS_Heading3', { font = 'coolvetica', size = 19 })

surface.CreateFont( "PS_Default", {
	font = system.IsLinux() and "Arial" or "Tahoma",
	size = 13, weight = 500, antialias = true,
})

surface.CreateFont( "PS_DefaultBold", {
	font = system.IsLinux() and "Arial" or "Tahoma",
	size = 13, weight = 800, antialias = true,
})

surface.CreateFont( "PS_Heading1", {
	font = system.IsLinux() and "Arial" or "Tahoma",
	size = 18, weight = 500, antialias = true,
})

surface.CreateFont( "PS_Heading1Bold", {
	font = system.IsLinux() and "Arial" or "Tahoma",
	size = 18, weight = 800, antialias = true,
})

surface.CreateFont( "PS_ButtonText1", {
	font = "Roboto",
	size = 22, weight = 700, antialias = true,
})

surface.CreateFont( "PS_ItemText", {
	font = system.IsLinux() and "Arial" or "Tahoma",
	size = 11, weight = 500, antialias = true,
})

surface.CreateFont( "PS_LargeTitle", {
	font = "Roboto",
	size = 32, weight = 500, antialias = true,
})

surface.CreateFont( "PS_CategoryButton", {
	font = "Roboto",
	size = 14, weight = 600, antialias = true,
})

-- Removed: BGColor1/2/3. All three were assigned and never read. One of them was (57,56,54),
-- the only warm grey anywhere in the shop — which is how it survived: nothing ever drew it.

-- COL_SCRIM removed with the body gradient it was the colour for.

local PANEL = {}

function PANEL:Init()
	-- Calculate panel size (larger than before for better item display)
	local panelWidth = 900
	local panelHeight = math.Clamp(ScrH() - 100, 600, 900)
	
	self:SetSize(panelWidth, panelHeight)
	self:SetPos(20, (ScrH() / 2) - (panelHeight / 2))
	self:SetTitle("")
	self:SetDraggable(true)
	self:SetSizable(false)
	self:ShowCloseButton(false)
	self:SetDeleteOnClose(false)
	
	self.CurrentCategory = nil
	self.CategoryButtons = {}
	
	-- Header
	self.Header = vgui.Create("DPanel", self)
	self.Header:Dock(TOP)
	self.Header:SetTall(60)
	self.Header.Paint = function(s, w, h)
		surface.SetDrawColor(PS.Theme.MenuHeaderBG)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(60, 140, 200, 255)
		surface.DrawRect(0, 0, w, 3)
		
		draw.SimpleText("PointShop", "PS_LargeTitle", 15, h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		-- Show loading state if initial data hasn't arrived yet
		local pointsText
		if LocalPlayer().PS_InitialDataReceived then
			pointsText = LocalPlayer():PS_GetPoints() .. " " .. PS.Config.PointsName
		else
			pointsText = "Loading..."
		end

		-- Right edge derived from how many buttons are actually present rather than
		-- hardcoded. The admin button is conditional, so a fixed offset is wrong for one of
		-- the two cases — and with three buttons the old 140 put the text underneath one.
		draw.SimpleText(pointsText, "PS_Heading3", w - (self.HeaderTextInset or 105), h / 2, Color(255, 255, 0), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- Header buttons are laid out right to left: close, appearance, then admin if shown.
	-- 45px apart, matching the existing close/admin spacing.
	local isAdmin = LocalPlayer():IsAdmin() or LocalPlayer():IsSuperAdmin()
	self.HeaderTextInset = isAdmin and 195 or 150

	-- Appearance button. Everyone gets this one — it only changes what they see.
	local themeBtn = vgui.Create("DButton", self.Header)
	themeBtn:SetPos(panelWidth - 95, 15)
	themeBtn:SetSize(35, 35)
	themeBtn:SetText("")
	themeBtn:SetTextColor(Color(255, 255, 255))
	themeBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)

		draw.RoundedBox(6, 0, 0, w, h, Color(70 + s._hoverAlpha * 30, 70 + s._hoverAlpha * 30, 80 + s._hoverAlpha * 30, 200 + s._hoverAlpha * 55))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(100, 100, 115, 80))

		if s._hoverAlpha > 0 then
			surface.SetDrawColor(140, 140, 160, s._hoverAlpha * 100)
			surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
		end

		-- Four swatches in a 2x2, drawn from the live palette so the icon itself shows the
		-- current theme. Cheaper and clearer than hunting for a glyph the font may not have.
		local sw, pad = 7, 2
		local ox, oy = w/2 - sw - pad/2, h/2 - sw - pad/2
		local T = PS.Theme
		local swatches = { T.Accent, T.PositiveFill, T.WarningFill, T.DangerFill }
		for i = 1, 4 do
			local cx = ox + ((i - 1) % 2) * (sw + pad)
			local cy = oy + math.floor((i - 1) / 2) * (sw + pad)
			surface.SetDrawColor(swatches[i])
			surface.DrawRect(cx, cy, sw, sw)
		end
	end
	themeBtn.DoClick = function()
		vgui.Create("DPointShopTheme")
	end
	self.themeBtn = themeBtn

	-- Admin button (only for admins/superadmins)
	if isAdmin then
		local adminBtn = vgui.Create("DButton", self.Header)
		adminBtn:SetPos(panelWidth - 140, 15)
		adminBtn:SetSize(35, 35)
		adminBtn:SetText("")
		adminBtn:SetFont("PS_Heading3")
		adminBtn:SetTextColor(Color(255, 255, 255))
		adminBtn.Paint = function(s, w, h)
			local isHovered = s:IsHovered()
			s._hoverAlpha = s._hoverAlpha or 0
			s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
			
			local baseBlue = 60 + s._hoverAlpha * 40
			local baseGreen = 120 + s._hoverAlpha * 40
			draw.RoundedBox(6, 0, 0, w, h, Color(baseBlue, baseGreen, 180, 200 + s._hoverAlpha * 55))
			draw.RoundedBox(6, 0, 0, w, h/2, Color(baseBlue + 40, baseGreen + 40, 200, 80))
			
			-- Glow on hover
			if s._hoverAlpha > 0 then
				surface.SetDrawColor(100, 160, 220, s._hoverAlpha * 100)
				surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
			end
			
			-- Admin icon (simple wrench/gear symbol)
			draw.SimpleText("⚙", "PS_Heading2", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("⚙", "PS_Heading2", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		adminBtn.DoClick = function()
			vgui.Create("DPointShopAdmin")
		end
		self.adminBtn = adminBtn
	end
	
	-- Close button
	local closeBtn = vgui.Create("DButton", self.Header)
	closeBtn:SetPos(panelWidth - 50, 15)
	closeBtn:SetSize(35, 35)
	closeBtn:SetText("")
	closeBtn:SetFont("PS_Heading2")
	closeBtn:SetTextColor(Color(255, 255, 255))
	closeBtn.Paint = function(s, w, h)
		local isHovered = s:IsHovered()
		s._hoverAlpha = s._hoverAlpha or 0
		s._hoverAlpha = Lerp(FrameTime() * 10, s._hoverAlpha, isHovered and 1 or 0)
		
		local baseRed = 140 + s._hoverAlpha * 40
		draw.RoundedBox(6, 0, 0, w, h, Color(baseRed, 40, 40, 200 + s._hoverAlpha * 55))
		draw.RoundedBox(6, 0, 0, w, h/2, Color(baseRed + 40, 60, 60, 80))
		
		-- Glow on hover
		if s._hoverAlpha > 0 then
			surface.SetDrawColor(200, 80, 80, s._hoverAlpha * 100)
			surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
		end
		
		-- X text with shadow
		draw.SimpleText("X", "PS_Heading2", w/2 + 1, h/2 + 1, Color(0, 0, 0, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("X", "PS_Heading2", w/2, h/2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	closeBtn.DoClick = function()
		PS:ToggleMenu()
	end

	-- Category Grid Container (Scrollable)
	--
	-- Docks directly under the header now. The search strip that used to sit between them was
	-- deprecated and removed, so both grids gained its 44px without any layout change.
	self.CategoryScroll = vgui.Create("DScrollPanel", self)
	self.CategoryScroll:Dock(TOP)
	self.CategoryScroll:DockMargin(10, 8, 10, 5)
	self.CategoryScroll:SetTall(90) -- Reduced height to show scrollbar with fewer categories
	
	local catSbar = self.CategoryScroll:GetVBar()
	catSbar:SetWide(10)
	catSbar:SetHideButtons(true)
	function catSbar:Paint(w, h)
		surface.SetDrawColor(PS.Theme.MenuScrollBG)
		surface.DrawRect(0, 0, w, h)
	end
	function catSbar.btnGrip:Paint(w, h)
		local col = Color(60, 140, 200, 200)
		if self:IsHovered() then
			col = Color(80, 160, 220, 255)
		end
		surface.SetDrawColor(col)
		surface.DrawRect(0, 0, w, h)
	end
	
	self.CategoryContainer = vgui.Create("DPanel", self.CategoryScroll)
	self.CategoryContainer:Dock(FILL)
	self.CategoryContainer.Paint = function(s, w, h)
		surface.SetDrawColor(PS.Theme.MenuCategoryBG)
		surface.DrawRect(0, 0, w, h)
	end
	
	-- Item Grid ScrollPanel
	self.ItemScroll = vgui.Create("DScrollPanel", self)
	self.ItemScroll:Dock(FILL)
	self.ItemScroll:DockMargin(10, 5, 10, 10)
	
	local sbar = self.ItemScroll:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	function sbar:Paint(w, h)
		surface.SetDrawColor(PS.Theme.MenuScrollBG)
		surface.DrawRect(0, 0, w, h)
	end
	function sbar.btnGrip:Paint(w, h)
		local col = Color(60, 140, 200, 200)
		if self:IsHovered() then
			col = Color(80, 160, 220, 255)
		end
		surface.SetDrawColor(col)
		surface.DrawRect(0, 0, w, h)
	end
	
	-- Item Grid Layout
	self.ItemGrid = vgui.Create("DIconLayout", self.ItemScroll)
	self.ItemGrid:Dock(TOP)
	self.ItemGrid:SetSpaceX(5)
	self.ItemGrid:SetSpaceY(5)
	self.ItemGrid:SetBorder(5)
	
	self:PopulateCategories()
end

function PANEL:SetVisible(visible)
	-- Call parent SetVisible
	self.BaseClass.SetVisible(self, visible)
	
	-- Repopulate categories when menu becomes visible (handles team changes)
	if visible then
		self:PopulateCategories()
	end
end

function PANEL:PopulateCategories()
	-- Clear existing category buttons
	if IsValid(self.CategoryContainer) then
		for _, btn in pairs(self.CategoryButtons) do
			if IsValid(btn) then
				btn:Remove()
			end
		end
		self.CategoryButtons = {}
	end
	
	-- Build category buttons in a grid (4 columns)
	local buttonWidth = 210
	local buttonHeight = 35
	local spacing = 5
	local columns = 4
	
	local categories = {}
	for _, cat in pairs(PS.Categories) do
		-- Filter out categories the player can't see (e.g. team-restricted)
		if cat.CanPlayerSee and not cat:CanPlayerSee(LocalPlayer()) then continue end
		table.insert(categories, cat)
	end
	
	-- Sort categories by order if available
	table.sort(categories, function(a, b)
		local orderA = a.Order or 999
		local orderB = b.Order or 999
		if orderA == orderB then
			return (a.Name or "") < (b.Name or "")
		end
		return orderA < orderB
	end)
	
	-- Calculate required height for category container
	local rows = math.ceil(#categories / columns)
	local requiredHeight = rows * (buttonHeight + spacing) + spacing
	self.CategoryContainer:SetTall(requiredHeight)
	
	-- Create category buttons
	for i, category in ipairs(categories) do
		local row = math.floor((i - 1) / columns)
		local col = (i - 1) % columns
		
		local btn = vgui.Create("DButton", self.CategoryContainer)
		btn:SetSize(buttonWidth, buttonHeight)
		btn:SetPos(spacing + col * (buttonWidth + spacing), spacing + row * (buttonHeight + spacing))
		btn:SetText(category.Name or "Category")
		btn:SetFont("PS_CategoryButton")
		btn:SetTextColor(Color(255, 255, 255))
		
		btn.Category = category
		btn.IsActive = false
		
		btn.Paint = function(s, w, h)
			PS.Theme.PaintSelectable(s, w, h, s.IsActive, PS.Theme.Selectable.Category)
		end
		
		btn.DoClick = function()
			self:SelectCategory(category)
		end
		
		self.CategoryButtons[category.Name] = btn
	end
	
	-- Select first category by default
	if #categories > 0 then
		self:SelectCategory(categories[1])
	end
end

function PANEL:SelectCategory(category)
	if not category then return end

	for _, btn in pairs(self.CategoryButtons) do
		btn.IsActive = (btn.Category == category)
	end

	self.CurrentCategory = category
	self:PopulateItems()
end

function PANEL:PopulateItems()
	self.ItemGrid:Clear()

	if not self.CurrentCategory then return end

	local items = {}

	for _, item in pairs(PS.Items) do
		if item.Category == self.CurrentCategory.Name then
			if item.CanPlayerSee and not item:CanPlayerSee(LocalPlayer()) then continue end
			table.insert(items, item)
		end
	end

	table.sort(items, function(a, b)
		local aQueued = PS_RemovalQueue and PS_RemovalQueue[a.ID] ~= nil
		local bQueued = PS_RemovalQueue and PS_RemovalQueue[b.ID] ~= nil
		if aQueued ~= bQueued then return not aQueued end  -- queued items sink to bottom
		local aOwned = LocalPlayer():PS_HasItem(a.ID)
		local bOwned = LocalPlayer():PS_HasItem(b.ID)
		if aOwned ~= bOwned then return bOwned end
		local aPrice = PS.Config.CalculateBuyPrice(LocalPlayer(), a)
		local bPrice = PS.Config.CalculateBuyPrice(LocalPlayer(), b)
		return aPrice < bPrice
	end)

	for _, item in ipairs(items) do
		local itemPanel = vgui.Create("DPointShopItem")
		itemPanel:SetData(item)
		itemPanel:SetSize(200, 200)
		self.ItemGrid:Add(itemPanel)
	end

	self.ItemGrid:InvalidateLayout(true)
	self.ItemScroll:InvalidateLayout(true)
end

-- PANEL:OpenAdminMenu() and its PromptGivePoints / PromptSetPoints / BuildItemMenu
-- helpers used to sit here: a DermaMenu-based admin UI superseded by DPointShopAdmin,
-- which the admin button in Init creates. Nothing referenced OpenAdminMenu, so none of
-- it could run — but it carried live bugs for whoever wired it up, since it read another
-- player's points and inventory off the client (both are only networked to their owner,
-- so Set Points would have written 0 and the Take Item submenu was always empty).
-- Removed rather than repaired; DPointShopAdmin is the supported path.

-- An empty PANEL:Think() used to sit here as a placeholder. It wasn't inert: it replaced
-- DFrame:Think, which is what drives dragging, so SetDraggable(true) at the top of Init
-- did nothing and the shop window couldn't be moved. Removed rather than stubbed — if
-- per-frame work is needed here later it has to call self.BaseClass.Think(self) first.

function PANEL:Paint(w, h)
	-- Flat body. No scrim.
	--
	-- There was a black gradient over this, and it was drawing a hard bar across the bottom
	-- of the window rather than the subtle shade it was meant to be. PS_DrawScrim ramps to
	-- maxAlpha at row maxAlpha/slope and is FLAT below that: at 100/0.15 the ramp finishes at
	-- row 667, so on a ~900px panel the bottom ~225px was a solid 39% black rect with a
	-- visible seam where it began.
	--
	-- Removed rather than retuned. It was also a second layer of colour on top of MenuBG, so
	-- setting that entry never produced the colour it named — which defeats the point of the
	-- entry existing.
	draw.RoundedBox(8, 0, 0, w, h, PS.Theme.MenuBG)

	-- Outer border glow with rounded corners
	surface.SetDrawColor(60, 120, 180, 100)
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.SetDrawColor(60, 120, 180, 50)
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
end

vgui.Register('DPointShopMenu', PANEL, 'DFrame')
