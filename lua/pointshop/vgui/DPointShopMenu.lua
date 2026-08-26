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
	
	local M = PS.Theme.Metrics

	-- Header
	self.Header = vgui.Create("DPanel", self)
	self.Header:Dock(TOP)
	self.Header:SetTall(M.HeaderH)
	self.Header.Paint = function(s, w, h)
		PS.Theme.PaintHeader(w, h, "PointShop")

		-- Show loading state if initial data hasn't arrived yet
		local pointsText
		if LocalPlayer().PS_InitialDataReceived then
			pointsText = LocalPlayer():PS_GetPoints() .. " " .. PS.Config.PointsName
		else
			pointsText = "Loading..."
		end

		-- Right edge derived from the buttons actually present rather than hardcoded. The
		-- admin button is conditional, so a fixed offset is wrong for one of the two cases.
		draw.SimpleText(pointsText, "PS_Heading3", w - self.HeaderTextInset, h / 2,
			PS.Theme.PointsText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- Header buttons, laid out right to left: close, appearance, then admin if shown.
	--
	-- Positioned in PerformLayout rather than once here, so they follow the header instead of
	-- being placed against an Init-time width.
	local isAdmin = LocalPlayer():IsAdmin() or LocalPlayer():IsSuperAdmin()

	local slot = 0
	local function HeaderButton(icon, style, onClick)
		local btn = PS.UI.IconButton(self.Header, icon, style, onClick)
		local mine = slot
		slot = slot + 1

		btn.PerformLayout = function(s)
			s:SetPos(self.Header:GetWide() - M.Margin - (mine + 1) * M.IconBtn - mine * 5,
				(M.HeaderH - M.IconBtn) / 2)
		end
		return btn
	end

	local function GlyphIcon(glyph)
		return function(w, h)
			draw.SimpleText(glyph, "PS_Heading2", w / 2 + 1, h / 2 + 1, PS.Theme.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(glyph, "PS_Heading2", w / 2, h / 2, PS.Theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	HeaderButton(GlyphIcon("X"), "Danger", function() PS:ToggleMenu() end)

	-- Appearance button. Everyone gets this one — it only changes what they see.
	--
	-- Its icon is a 2x2 of live palette swatches rather than a glyph, so the button shows the
	-- current theme. That is also why IconButton takes a draw function and not a string.
	self.themeBtn = HeaderButton(function(w, h)
		local sw, pad = 7, 2
		local ox, oy = w / 2 - sw - pad / 2, h / 2 - sw - pad / 2
		local T = PS.Theme
		local swatches = { T.Accent, T.PositiveFill, T.WarningFill, T.DangerFill }
		for i = 1, 4 do
			surface.SetDrawColor(swatches[i])
			surface.DrawRect(ox + ((i - 1) % 2) * (sw + pad),
				oy + math.floor((i - 1) / 2) * (sw + pad), sw, sw)
		end
	end, "Neutral", function() vgui.Create("DPointShopTheme") end)

	if isAdmin then
		self.adminBtn = HeaderButton(GlyphIcon("⚙"), "Accent", function()
			vgui.Create("DPointShopAdmin")
		end)
	end

	-- Owner tools.
	--
	-- NOT rendered for anyone else. Not disabled, not greyed -- absent. The button is only
	-- built if this client passes the owner check, so a non-owner has no way to know it
	-- exists, which is the point of it.
	--
	-- PS_IsItemDefaultOwner is the ULX "owner" group, the same gate this addon already uses
	-- for server-wide defaults. Deliberately NOT the isAdmin check above: admin is a much
	-- wider group and commonly inherited, and these tools change the game for everyone
	-- connected rather than just what one person sees.
	--
	-- Hiding a button is not security and is not treated as any. Whatever a tool does, its
	-- server side re-checks the same gate on arrival -- this only decides what is drawn.
	--
	-- Collected through a hook so the shop never names a gamemode, the same way the
	-- appearance providers work. No tools registered means no button.
	if PS_IsItemDefaultOwner and PS_IsItemDefaultOwner(LocalPlayer()) then
		local tools = {}
		hook.Run("PS_CollectOwnerTools", function(name, open)
			if isstring(name) and isfunction(open) then
				table.insert(tools, { name = name, open = open })
			end
		end)

		if #tools == 1 then
			self.ownerBtn = HeaderButton(GlyphIcon("★"), "Accent", tools[1].open)
		elseif #tools > 1 then
			table.sort(tools, function(a, b) return a.name < b.name end)
			self.ownerBtn = HeaderButton(GlyphIcon("★"), "Accent", function()
				local m = DermaMenu()
				for _, t in ipairs(tools) do m:AddOption(t.name, t.open) end
				m:Open()
			end)
		end
	end

	-- Points text clears whatever buttons exist, plus a gap.
	self.HeaderTextInset = M.Margin + slot * (M.IconBtn + 5) + M.Gap

	-- Category Grid Container (Scrollable)
	--
	-- Docks directly under the header now. The search strip that used to sit between them was
	-- deprecated and removed, so both grids gained its 44px without any layout change.
	self.CategoryScroll = PS.UI.Scroll(self)
	self.CategoryScroll:Dock(TOP)
	self.CategoryScroll:DockMargin(M.Margin, M.Gap, M.Margin, M.Gap)
	self.CategoryScroll:SetTall(90) -- Reduced height to show scrollbar with fewer categories

	self.CategoryContainer = vgui.Create("DPanel", self.CategoryScroll)
	self.CategoryContainer:Dock(FILL)
	self.CategoryContainer.Paint = function(s, w, h)
		surface.SetDrawColor(PS.Theme.MenuCategoryBG)
		surface.DrawRect(0, 0, w, h)
	end

	-- Item Grid ScrollPanel
	self.ItemScroll = PS.UI.Scroll(self)
	self.ItemScroll:Dock(FILL)
	self.ItemScroll:DockMargin(M.Margin, 0, M.Margin, M.Margin)

	-- Item Grid Layout
	self.ItemGrid = vgui.Create("DIconLayout", self.ItemScroll)
	self.ItemGrid:Dock(TOP)
	self.ItemGrid:SetSpaceX(M.Gap - 3)
	self.ItemGrid:SetSpaceY(M.Gap - 3)
	self.ItemGrid:SetBorder(M.Gap - 3)
	
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
		
		-- IsActive is read off the button rather than closed over, because SelectCategory
		-- sets it on every button in the list and the flag has to be the shared truth.
		local btn = PS.UI.Tab(self.CategoryContainer, category.Name or "Category",
			function(s) return s.IsActive end, nil)
		btn:SetSize(buttonWidth, buttonHeight)
		btn:SetPos(spacing + col * (buttonWidth + spacing), spacing + row * (buttonHeight + spacing))

		btn.Category = category
		btn.IsActive = false

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

-- Flat body, shared border. No scrim: there was a black gradient here that drew a hard bar
-- across the bottom of anything taller than ~675px, and it meant the body was never the
-- colour its entry named.
--
-- FrameBG, the same body every other window uses. The shop menu and the customization panel
-- are siblings, so they are one colour rather than two that drift.
function PANEL:Paint(w, h)
	PS.Theme.PaintFrame(w, h)
end

vgui.Register('DPointShopMenu', PANEL, 'DFrame')
