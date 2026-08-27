-- Callbacks for admin item requests (keyed by entity index).
--
-- Entries carry an expiry. The server drops a request silently when it fails the config
-- gate, the rate limit, or the target validity check, so a callback registered here would
-- otherwise sit forever — and because it's keyed by entity index, a stale one fires
-- against whoever next occupies that index.
local _adminItemsCallbacks = {}
local ADMIN_REQ_TIMEOUT = 5

-- Points and item counts for every player, filled by PS_AdminSummaryResponse.
-- Keyed by entity index. See the net handler in sv_init.lua for why this exists at all:
-- a player's points and inventory are only networked to that player, so an admin's
-- client has no way to read them off the remote player entity.
local _adminSummary = {}

-- Upper bound for both point prompts. Mirrors the math.Clamp in PS_GivePoints /
-- PS_SetPoints server-side; keep the two in step.
local PS_ADMIN_POINTS_MAX = 1000000

-- Cached at file scope rather than rebuilt inside Paint every frame.
-- COL_PANEL_BG and COL_SCRIM removed with the hand-drawn frame and its gradient.

-- Truncates `text` to fit `maxWidth`, appending an ellipsis, and caches the result on the
-- panel that asked for it.
--
-- The loop this replaces ran inside Paint: a string.sub allocation and a
-- surface.GetTextSize call for every character removed, on every row, on every frame — and
-- it produced the identical answer each time, because neither the name nor the width had
-- changed. A long name in a narrow column could run it 20+ times a frame.
--
-- One slot per panel is enough: each row draws exactly one truncated string. The cache dies
-- with the panel, so nothing needs clearing.
local function FitText(owner, text, font, maxWidth)
	local c = owner._fitCache
	if c and c.text == text and c.w == maxWidth and c.font == font then
		return c.out
	end

	surface.SetFont(font)
	local out = text
	local textW = surface.GetTextSize(text)

	if textW > maxWidth then
		while textW > maxWidth - 20 and #out > 0 do
			out = string.sub(out, 1, -2)
			textW = surface.GetTextSize(out)
		end
		out = out .. "..."
	end

	owner._fitCache = { text = text, w = maxWidth, font = font, out = out }
	return out
end

local PANEL = {}

function PANEL:Init()
	self:SetSize(1200, 600)
	PS.UI.RememberPosition(self, "admin")
	self:SetTitle("")
	self:SetDraggable(true)
	self:SetSizable(true)
	self:ShowCloseButton(false)
	self:MakePopup()

	-- The row layout positions its buttons from the right edge at fixed offsets, the
	-- furthest being 550px. Without a floor, dragging the sizable frame narrower than
	-- that slides the columns off the left of the panel and inverts the name-truncation
	-- width into a negative.
	self:SetMinWidth(900)
	self:SetMinHeight(300)

	-- Header
	self.Header = vgui.Create("DPanel", self)
	self.Header:Dock(TOP)
	self.Header:SetTall(50)
	self.Header.Paint = function(s, w, h)
		PS.Theme.PaintHeader(w, h, "PointShop Admin")
	end
	
	-- Close button.
	-- Positioned in PerformLayout rather than once in Init: the frame is sizable, and a
	-- one-shot SetPos against the Init width left the button stranded mid-header (or off
	-- the panel entirely) the moment it was resized.
	local closeBtn = vgui.Create("DButton", self.Header)
	closeBtn:SetSize(35, 35)
	closeBtn:SetText("")
	closeBtn.PerformLayout = function(s)
		s:SetPos(self.Header:GetWide() - 50, 8)
	end
	closeBtn.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Danger)
		draw.SimpleText("X", "PS_Heading2", w/2 + 1, h/2 + 1, PS.Theme.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("X", "PS_Heading2", w/2, h/2, PS.Theme.HeaderText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
	sbar.Paint = function(s, w, h) PS.Theme.PaintScrollTrack(w, h) end
	sbar.btnGrip.Paint = function(s, w, h) PS.Theme.PaintScrollGrip(s, w, h) end
	
	-- List container
	self.ListContainer = vgui.Create("DListLayout", self.PlayerList)
	self.ListContainer:Dock(FILL)

	self._KnownPlayerCount = 0
	self:PopulatePlayerList()
end

-- The list was only ever rebuilt on Init and after a point change, so a player joining
-- or leaving while the panel was open left it showing a stale roster — including rows
-- whose target had disconnected, which render as "Unknown" and whose buttons act on a
-- NULL entity.
--
-- Rebuilding is only done when the roster actually changes; the summary refresh is on a
-- timer instead, since points move without the player count moving. The server rate
-- limits that request to 0.5s, so 2s stays well clear.
function PANEL:Think()
	-- DFrame:Think is what actually moves and resizes the frame while the mouse is held.
	-- Defining PANEL:Think without chaining up replaces it, which silently kills both
	-- SetDraggable and SetSizable on this panel.
	self.BaseClass.Think(self)

	local count = player.GetCount()
	if count ~= self._KnownPlayerCount then
		self:PopulatePlayerList()
	end

	self._NextSummary = self._NextSummary or 0
	if CurTime() >= self._NextSummary then
		self:RequestSummary()
	end

	-- Drop admin item callbacks the server never answered.
	for idx, entry in pairs(_adminItemsCallbacks) do
		if CurTime() > entry.expires then
			_adminItemsCallbacks[idx] = nil
		end
	end
end

-- Single place that touches _NextSummary, so a direct call can't leave the timer stale
-- and trip the server's 0.5s rate limit on the following tick.
function PANEL:RequestSummary()
	self._NextSummary = CurTime() + 2
	net.Start('PS_AdminRequestSummary')
	net.SendToServer()
end

function PANEL:PopulatePlayerList()
	self.ListContainer:Clear()
	
	-- Header row
	local headerPanel = vgui.Create("DPanel", self.ListContainer)
	headerPanel:SetTall(40)
	headerPanel:Dock(TOP)
	headerPanel.Paint = function(s, w, h)
		surface.SetDrawColor(PS.Theme.RowAlt)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(PS.Theme.Accent)
		surface.DrawRect(0, h - 2, w, 2)
		
		draw.SimpleText("Player", "PS_DefaultBold", 15, h / 2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Points", "PS_DefaultBold", w - 550, h / 2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Items", "PS_DefaultBold", w - 450, h / 2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Actions", "PS_DefaultBold", w - 410, h / 2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- Player rows
	local plys = player.GetAll()
	self._KnownPlayerCount = #plys
	for _, ply in ipairs(plys) do
		self:AddPlayerRow(ply)
	end

	-- Whatever prompted a rebuild (a join, a point change) also invalidates the numbers.
	self:RequestSummary()
end

function PANEL:AddPlayerRow(ply)
	local row = vgui.Create("DPanel", self.ListContainer)
	row:SetTall(50)
	row:Dock(TOP)
	row:DockMargin(0, 2, 0, 0)
	row.TargetPlayer = ply
	
	row.Paint = function(s, w, h)
		PS.Theme.PaintRow(s, w, h)
		
		-- Player name
		local name = IsValid(ply) and ply:Nick() or "Unknown"
		-- w - 650 leaves space for the points, items and actions columns.
		local displayName = FitText(s, name, "PS_Default", w - 650)
		draw.SimpleText(displayName, "PS_Default", 15, h / 2, PS.Theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		-- Points and item count.
		--
		-- These come from the server's summary message, not from ply:PS_GetPoints() /
		-- ply:PS_GetItems(). Those read PS_Points / PS_Items off the player entity, and
		-- both are only ever net.Send()'d to the player they belong to — so on an admin's
		-- client they are nil for everyone else and both columns rendered a flat 0.
		--
		-- "?" until the first response lands, so an admin can tell "not fetched yet"
		-- from "genuinely has nothing".
		local summary = IsValid(ply) and _adminSummary[ply:EntIndex()]
		local points = summary and summary.points or "?"
		local itemCount = summary and summary.items or "?"

		draw.SimpleText(points, "PS_Default", w - 550, h / 2, PS.Theme.PointsText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(itemCount, "PS_Default", w - 450, h / 2, PS.Theme.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- View Items button
	local viewBtn = vgui.Create("DButton", row)
	viewBtn:SetSize(80, 40)
	viewBtn:SetText("")
	viewBtn.PerformLayout = function(s, w, h)
		s:SetPos(row:GetWide() - 410, 10)
	end
	viewBtn.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Modify, "View Items")
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
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Positive, "Give Points")
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
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Accent, "Set Points")
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
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Warning, "Give Item")
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
	_adminItemsCallbacks[idx] = {
		expires = CurTime() + ADMIN_REQ_TIMEOUT,
		fn = function(resolvedPly, items)
			if not IsValid(self) then return end
			self:_BuildPlayerItemsWindow(resolvedPly, items)
		end,
	}

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
		label:SetFont("PS_LargeTitle")
		return
	end

	-- Scrollable item list
	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)

	local sbar = scroll:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	sbar.Paint = function(s, w, h) PS.Theme.PaintScrollTrack(w, h) end
	sbar.btnGrip.Paint = function(s, w, h) PS.Theme.PaintScrollGrip(s, w, h) end

	local list = vgui.Create("DListLayout", scroll)
	list:Dock(FILL)

	-- Add header
	local header = vgui.Create("DPanel", list)
	header:SetTall(45)
	header:Dock(TOP)
	header.Paint = function(s, w, h)
		surface.SetDrawColor(PS.Theme.RowHover)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("Item Name", "PS_DefaultBold", 15, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Equipped", "PS_DefaultBold", w - 275, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Actions", "PS_DefaultBold", w - 150, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- Sorted for a stable order; pairs() over the inventory table meant the list
	-- reshuffled every time the window was opened.
	local sorted = {}
	for itemID, itemData in pairs(items) do
		sorted[#sorted + 1] = { id = itemID, data = itemData, ITEM = PS.Items[itemID] }
	end
	table.sort(sorted, function(a, b)
		local an = a.ITEM and a.ITEM.Name or a.id
		local bn = b.ITEM and b.ITEM.Name or b.id
		return string.lower(an) < string.lower(bn)
	end)

	-- Add each item
	for _, entry in ipairs(sorted) do
		local itemID, itemData, ITEM = entry.id, entry.data, entry.ITEM

		-- Rows with no matching PS.Items entry used to be skipped outright. That hides
		-- exactly the rows an admin most needs to act on — an item whose Lua file was
		-- deleted while players still owned it is invisible here *and* unreachable from
		-- the player's own shop, so there was no in-game way to take it back. Shown as
		-- an orphan instead; Take still works, because the server takes by ID.
		local displayName = ITEM and ITEM.Name or (itemID .. "  (orphaned - no item file)")
		local nameCol = ITEM and PS.Theme.Text or PS.Theme.WarningBorder

		local itemRow = vgui.Create("DPanel", list)
		itemRow:SetTall(50)
		itemRow:Dock(TOP)
		itemRow:DockMargin(0, 1, 0, 1)

		itemRow.Paint = function(s, w, h)
			PS.Theme.PaintRow(s, w, h)

			-- Item name - clip if too long
			local shown = FitText(s, displayName, "PS_Default", w - 300)
			draw.SimpleText(shown, "PS_Default", 15, h/2, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local equipped = itemData.Equipped and "Yes" or "No"
			local equipCol = itemData.Equipped and PS.Theme.PriceAfford or PS.Theme.MenuRowText
			draw.SimpleText(equipped, "PS_Default", w - 275, h/2, equipCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		-- Take button
		local takeBtn = vgui.Create("DButton", itemRow)
		takeBtn:SetSize(100, 25)
		takeBtn:SetText("")
		takeBtn.PerformLayout = function(btn, w, h)
			btn:SetPos(itemRow:GetWide() - 120, 12)
		end
		takeBtn.Paint = function(s, w, h)
			PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Danger,
				s:IsEnabled() and "Take Item" or "Taken")
		end
		takeBtn.DoClick = function(s)
			net.Start('PS_TakeItem')
				net.WriteEntity(ply)
				net.WriteString(itemID)
			net.SendToServer()

			-- Was frame:Close(). Taking one item tore down the whole window, so clearing
			-- out a player's inventory meant reopening it and paying another server round
			-- trip per item. Disable the row's button instead and leave the list up.
			s:SetEnabled(false)

			if IsValid(self) then self:RequestSummary() end
		end

		takeBtn:InvalidateLayout(true)
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
	-- DNumberWang defaults to a 0-100 range. Without this the box silently refused to
	-- give more than 100 at a time. Bounds match the server's clamp in PS_GivePoints.
	entry:SetMinMax(0, PS_ADMIN_POINTS_MAX)
	entry:SetDecimals(0)
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

		-- Was a full PopulatePlayerList(), which tears down and rebuilds every row and
		-- resets the scroll position. Only the numbers changed, so schedule a summary
		-- refresh instead. The delay clears the server's 0.5s rate limit on the request,
		-- which the old 0.1s timer would have tripped straight into.
		if IsValid(self) then self._NextSummary = CurTime() + 0.6 end
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
	-- This one was actively destructive, not just limiting. DNumberWang's default range
	-- is 0-100, so the SetValue below clamped the *displayed current balance* to 100 for
	-- anyone above that. An admin opening this on a player with 70k points saw "100" and
	-- pressing Set wrote 100 — wiping the balance while looking like a no-op.
	entry:SetMinMax(0, PS_ADMIN_POINTS_MAX)
	entry:SetDecimals(0)

	-- Seeded from the server summary rather than ply:PS_GetPoints(), which reads a field
	-- that is never networked to anyone but its owner and so returned 0 for every other
	-- player.
	local idx = ply:EntIndex()
	local btn = vgui.Create("DButton", frame)

	-- Set is held disabled until the current balance is actually known. Seeding the box
	-- with a placeholder and letting it be submitted is the same wipe by another route:
	-- an admin who opens this and immediately presses Set would write the placeholder.
	local seeded = false
	local function TrySeed()
		local summary = _adminSummary[idx]
		if not summary then return end
		seeded = true
		entry:SetValue(summary.points)
		btn:SetEnabled(true)
		btn:SetText("Set")
	end

	entry:SetValue(0)
	btn:SetEnabled(false)
	btn:SetText("Loading...")
	TrySeed()

	if not seeded then
		if IsValid(self) then self:RequestSummary() end
		-- Chained, not replaced: DFrame:Think is what makes the prompt draggable.
		local baseThink = frame.Think
		frame.Think = function(s)
			if baseThink then baseThink(s) end
			if not seeded then TrySeed() end
		end
	end

	btn:Dock(TOP)
	btn:DockMargin(5, 5, 5, 5)
	btn.DoClick = function()
		if not seeded then return end
		local amount = tonumber(entry:GetValue()) or 0
		net.Start('PS_SetPoints')
			net.WriteEntity(ply)
			net.WriteInt(amount, 32)
		net.SendToServer()
		frame:Close()

		-- See PromptGivePoints: summary refresh rather than a full list rebuild, delayed
		-- past the server's rate limit on the request.
		if IsValid(self) then self._NextSummary = CurTime() + 0.6 end
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
		label:SetFont("PS_LargeTitle")
		return
	end
	
	-- Scrollable item list
	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	
	local sbar = scroll:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	sbar.Paint = function(s, w, h) PS.Theme.PaintScrollTrack(w, h) end
	sbar.btnGrip.Paint = function(s, w, h) PS.Theme.PaintScrollGrip(s, w, h) end
	
	local list = vgui.Create("DListLayout", scroll)
	list:Dock(FILL)
	
	-- Add header
	local header = vgui.Create("DPanel", list)
	header:SetTall(45)
	header:Dock(TOP)
	header.Paint = function(s, w, h)
		surface.SetDrawColor(PS.Theme.RowHover)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("Item Name", "PS_DefaultBold", 15, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Category", "PS_DefaultBold", w - 200, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Actions", "PS_DefaultBold", w - 120, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- Sorted by category then name. pairs() over PS.Items gave a different order on every
	-- open, which makes finding anything in a list this long a matter of luck — and the
	-- window already has a Category column implying a grouping that was never applied.
	local sorted = {}
	for _, ITEM in pairs(items) do
		sorted[#sorted + 1] = ITEM
	end
	table.sort(sorted, function(a, b)
		local ac, bc = string.lower(a.Category or "Misc"), string.lower(b.Category or "Misc")
		if ac ~= bc then return ac < bc end
		return string.lower(a.Name or "") < string.lower(b.Name or "")
	end)

	-- Add each item
	for _, ITEM in ipairs(sorted) do
		local itemRow = vgui.Create("DPanel", list)
		itemRow:SetTall(50)
		itemRow:Dock(TOP)
		itemRow:DockMargin(0, 1, 0, 1)
		
		itemRow.Paint = function(s, w, h)
			PS.Theme.PaintRow(s, w, h)
			
			-- Item name - clip if too long
			local displayName = FitText(s, ITEM.Name, "PS_Default", w - 250)
			draw.SimpleText(displayName, "PS_Default", 15, h/2, PS.Theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			
			local category = ITEM.Category or "Misc"
			draw.SimpleText(category, "PS_Default", w - 200, h/2, PS.Theme.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		
		-- Give button
		local giveBtn = vgui.Create("DButton", itemRow)
		giveBtn:SetSize(100, 25)
		giveBtn:SetText("")
		giveBtn.PerformLayout = function(btn, w, h)
			btn:SetPos(itemRow:GetWide() - 110, 12)
		end
		giveBtn.Paint = function(s, w, h)
			PS.Theme.PaintAction(s, w, h, PS.Theme.Action.Positive,
				s:IsEnabled() and "Give Item" or "Given")
		end
		giveBtn.DoClick = function(s)
			net.Start('PS_GiveItem')
				net.WriteEntity(ply)
				net.WriteString(ITEM.ID)
			net.SendToServer()

			-- Was frame:Close(). Handing a player a loadout meant reopening and re-scrolling
			-- this list once per item. Disable the row instead and keep the window up.
			s:SetEnabled(false)

			timer.Simple(0.1, function()
				if IsValid(self) then
					self:RequestSummary()
				end
			end)
		end
		
		giveBtn:InvalidateLayout(true)
	end
end

function PANEL:Paint(w, h)
	PS.Theme.PaintFrame(w, h)
end

vgui.Register('DPointShopAdmin', PANEL, 'DFrame')

-- Receive admin item data from server and fire the waiting callback
net.Receive('PS_AdminItemsResponse', function()
	local ply = net.ReadEntity()
	local items = net.ReadTable()
	local idx = IsValid(ply) and ply:EntIndex() or -1
	local entry = _adminItemsCallbacks[idx]
	if entry then
		_adminItemsCallbacks[idx] = nil
		entry.fn(ply, items)
	end
end)

-- Points / item counts for the admin list columns. Replaces the whole table each time
-- rather than merging, so a disconnected player's row doesn't linger in the cache and
-- get attributed to whoever reuses that entity index.
net.Receive('PS_AdminSummaryResponse', function()
	local count = net.ReadUInt(8)
	local out = {}
	for _ = 1, count do
		local idx = net.ReadUInt(13)
		local points = net.ReadUInt(24)
		local items = net.ReadUInt(12)
		out[idx] = { points = points, items = items }
	end
	_adminSummary = out
end)
