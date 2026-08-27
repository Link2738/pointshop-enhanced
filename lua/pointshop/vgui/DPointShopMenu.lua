-- Fonts moved to pointshop/cl_theme.lua.
--
-- They were never panel-specific: every file draws with them, and several of those files
-- are autoloaded by the engine rather than included after this one, so defining them here
-- was a load-order bet. They also have to be re-created when the screen scale changes,
-- which is the theme's job, not this panel's.

-- Removed: BGColor1/2/3. All three were assigned and never read. One of them was (57,56,54),
-- the only warm grey anywhere in the shop — which is how it survived: nothing ever drew it.

-- COL_SCRIM removed with the body gradient it was the colour for.

local PANEL = {}

-- Frame size, entirely from metrics: scale * screen + offset, clamped.
--
-- No formula lives here any more. The shipped values reproduce the size the shop has always
-- had -- 900 wide, and as tall as the screen less 100px -- and a look or an owner can supply
-- any of the three useful shapes (fixed, screen-share, screen-inset) without this function
-- knowing which it was given. See T.Metrics for the arithmetic.
local function FrameSize()
	local M = PS.Theme.Metrics

	-- Floored: a frame on a half pixel smears its own rounded corners and drags every
	-- centred child half a pixel with it.
	-- Clamped to the screen last, after the look's own min and max. A window larger than
	-- the monitor is never right, whatever a look or an owner asked for, and PointShop 1
	-- did the same -- its 1024x768 was written as Clamp(1024, 0, ScrW()).
	return math.floor(math.min(math.Clamp(ScrW() * M.FrameWScale + M.FrameWOffset, M.FrameWMin, M.FrameWMax), ScrW())),
	       math.floor(math.min(math.Clamp(ScrH() * M.FrameHScale + M.FrameHOffset, M.FrameHMin, M.FrameHMax), ScrH()))
end

function PANEL:Init()
	self:SetSize(FrameSize())

	-- Centred, then wherever it was last dragged. The old SetPos(20, ...) pinned it to the
	-- left edge, which on an ultrawide put the shop in a corner with the map beside it.
	PS.UI.RememberPosition(self, "menu")
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

		-- Wraps IconButton's own PerformLayout rather than replacing it: that one re-reads
		-- the button SIZE from the metrics, and dropping it left the buttons at whatever size
		-- the look active when the shop was built happened to use.
		local sizeSelf = btn.PerformLayout
		btn.PerformLayout = function(s)
			if sizeSelf then sizeSelf(s) end
			s:SetPos(self.Header:GetWide() - M.Margin - (mine + 1) * M.IconBtn - mine * M.IconGap,
				PS.UI.IconBtnY())
		end
		return btn
	end

	-- Icons come from PS.UI.GlyphIcon so the nudge table has one home. This file used to
	-- carry its own copy of the same six lines, alongside an identical copy in UI.Frame's
	-- close button -- three places to fix a centring problem.
	local GlyphIcon = PS.UI.GlyphIcon

	HeaderButton(GlyphIcon("close"), "Danger", function() PS:ToggleMenu() end)

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
		self.adminBtn = HeaderButton(GlyphIcon("bolt"), "Accent", function()
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
			self.ownerBtn = HeaderButton(GlyphIcon("star"), "Accent", tools[1].open)
		elseif #tools > 1 then
			table.sort(tools, function(a, b) return a.name < b.name end)
			self.ownerBtn = HeaderButton(GlyphIcon("star"), "Accent", function()
				local m = DermaMenu()
				for _, t in ipairs(tools) do m:AddOption(t.name, t.open) end
				m:Open()
			end)
		end
	end

	-- Points text clears whatever buttons exist, plus a gap.
	self.HeaderButtonCount = slot
	self.HeaderTextInset = M.Margin + slot * (M.IconBtn + M.IconGap) + M.Gap

	-- Category Grid Container (Scrollable)
	--
	-- Docks directly under the header now. The search strip that used to sit between them was
	-- deprecated and removed, so both grids gained its 44px without any layout change.
	self.CategoryScroll = PS.UI.Scroll(self)
	self.CategoryScroll:Dock(TOP)
	self.CategoryScroll:DockMargin(M.Margin, M.Gap, M.Margin, M.Gap)
	self.CategoryScroll:SetTall(M.CategoryStripH)

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
	self.ItemGrid:SetSpaceX(M.GridSpace)
	self.ItemGrid:SetSpaceY(M.GridSpace)
	self.ItemGrid:SetBorder(M.GridSpace)

	self:ApplyLook()
end

-- Re-reads every size the look supplies and rebuilds what depends on them.
--
-- Init BUILDS the panel; this decides how big the built things are. Separated so a look
-- change reaches a menu that is already open — Init only ever runs once, so metrics read
-- there were effectively frozen at whatever the look was when the shop was first opened.
--
-- Deliberately NOT PerformLayout: this calls SetTall and DockMargin, which invalidate layout,
-- so running it from the layout pass would re-enter every frame. It is called at the end of
-- Init, and by the PS_PresetChanged hook at the bottom of this file.
function PANEL:ApplyLook()
	local M = PS.Theme.Metrics

	self:SetSize(FrameSize())
	self.Header:SetTall(M.HeaderH)

	self.CategoryScroll:DockMargin(M.Margin, M.Gap, M.Margin, M.Gap)
	self.CategoryScroll:SetTall(M.CategoryStripH)

	self.ItemScroll:DockMargin(M.Margin, 0, M.Margin, M.Margin)

	self.ItemGrid:SetSpaceX(M.GridSpace)
	self.ItemGrid:SetSpaceY(M.GridSpace)
	self.ItemGrid:SetBorder(M.GridSpace)

	-- The points text clears whatever header buttons exist, and both the button size and
	-- the gap between them just moved.
	self.HeaderTextInset = M.Margin + (self.HeaderButtonCount or 0) * (M.IconBtn + M.IconGap) + M.Gap

	-- InvalidateChildren(true), not InvalidateLayout.
	--
	-- The header buttons size and position themselves in their own PerformLayout, and
	-- invalidating only this frame never reaches them -- they sat at the old look's
	-- coordinates until a mouse hover happened to force a layout pass on them, which is
	-- exactly what it looked like: buttons that moved when you went looking for them.
	self:InvalidateChildren(true)

	-- Column counts come from the metrics, so both grids have to be rebuilt rather than
	-- merely resized. PopulateCategories re-selects the current category, which repopulates
	-- the items.
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
	local M = PS.Theme.Metrics
	-- Clear existing category buttons
	if IsValid(self.CategoryContainer) then
		for _, btn in pairs(self.CategoryButtons) do
			if IsValid(btn) then
				btn:Remove()
			end
		end
		self.CategoryButtons = {}
	end
	
	-- Category buttons flow to fit the panel rather than being positioned into a fixed grid.
	--
	-- Four columns of 210 was fine at 900 wide and wrong at every other width -- too cramped
	-- narrow, too much dead space wide. Column count now comes from the space available, and
	-- the buttons divide it evenly so they always reach both edges.
	local buttonHeight = M.CategoryBtnH
	local spacing = M.CategoryGap
	-- Measured off the FRAME, not off the docked scroll panel. Populate runs inside Init,
	-- before any layout has happened, so the child's GetWide() is still 0 at this point --
	-- it would silently produce the minimum column count on every screen.
	local avail = math.max(self:GetWide() - M.Margin * 2 - spacing, 100)
	local columns = math.Clamp(math.floor(avail / M.CategoryW), M.CategoryMinCols, M.CategoryMaxCols)
	local buttonWidth = math.floor(avail / columns) - spacing
	
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

	-- The VIEWPORT follows the rows actually needed, capped by CategoryStripH.
	--
	-- It used to be pinned at CategoryStripH regardless. That is wrong in both
	-- directions: a shop with three categories reserved room for two rows of nothing,
	-- and a look with narrower tabs -- more columns, fewer per row, but a shorter strip
	-- -- hid whole categories behind a scrollbar 34 pixels tall. How many rows the
	-- buttons need depends on the window width and the number of categories, neither of
	-- which is knowable when a look is written, so it cannot be a constant.
	self.CategoryScroll:SetTall(math.min(requiredHeight, M.CategoryStripH))
	
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
	local M = PS.Theme.Metrics
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

	-- Card size derived from the grid width, so cards fill the row instead of leaving a
	-- ragged margin whenever the panel is not exactly 900 wide. Clamped: below ~150 the
	-- model is too small to identify, above ~230 a row holds too few to browse.
	-- Frame width again, for the same reason, less the margins and the scrollbar.
	local gridW = math.max(self:GetWide() - M.Margin * 2 - M.ScrollW, 200)
	local perRow = math.Clamp(math.floor(gridW / M.CardW), M.CardMinCols, M.CardMaxCols)
	local cardSize = math.Clamp(math.floor(gridW / perRow) - M.CardPad, M.CardMin, M.CardMax)

	for _, item in ipairs(items) do
		local itemPanel = vgui.Create("DPointShopItem")
		itemPanel:SetData(item)
		itemPanel:SetSize(cardSize, cardSize)
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

-- A look change reaches an open menu.
--
-- Colours need nothing here: every paint function reads PS.Theme live, so they change on the
-- next frame on their own. Sizes are the opposite — they were applied to panels once, so
-- without this the menu keeps the geometry of whatever look was active when it was built,
-- and a player switching look with the shop open sees half a change.
hook.Add("PS_PresetChanged", "PS_ShopMenu_ApplyLook", function()
	local menu = PS and PS.ShopMenu
	if IsValid(menu) and menu.ApplyLook then menu:ApplyLook() end
end)
