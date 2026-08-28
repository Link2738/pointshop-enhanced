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

-- Applies a change the admin just made to the cached summary, so the row shows it now instead
-- of when the next poll lands up to two seconds later.
--
-- Done without waiting for the server because the admin's own action is what the server is
-- being asked to do, and it accepts it. The poll overwrites this with the real number
-- regardless, so the worst case for a change that was somehow refused is one wrong number for
-- one interval -- against every give and set looking like it did nothing, which is what the
-- panel did before.
local function AdminPatchSummary(ply, fn)
	if not IsValid(ply) then return end

	local entry = _adminSummary[ply:EntIndex()]
	if entry then fn(entry) end
end

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
	local M = PS.Theme.Metrics

	-- Its own header, close button and remembered position lived here, hand-rolled. The
	-- close button drew its own "X" from two draw.SimpleText calls rather than using the
	-- glyph every other window's close button uses, and its 35x35 and (w - 50, 8) were
	-- written down rather than measured, so it sat wrong at any scale but one.
	PS.UI.SetupFrame(self, {
		title    = "Admin",
		w        = 1200,
		h        = 600,
		sizable  = true,
		remember = "admin",
	})

	-- The row layout positions its buttons from the right edge at fixed offsets, the
	-- furthest being 550px. Without a floor, dragging the sizable frame narrower than
	-- that slides the columns off the left of the panel and inverts the name-truncation
	-- width into a negative.
	self:SetMinWidth(900)
	self:SetMinHeight(300)

	-- Player list with scrollbar
	self.PlayerList = vgui.Create("DScrollPanel", self)
	self.PlayerList:Dock(FILL)
	-- Tighter at the sides than at the top and bottom. This is a wide window holding rows of
	-- columns, and the horizontal room is what the content actually wants.
	self.PlayerList:DockMargin(M.Gap, M.Gap, M.Gap, M.Gap)

	-- A box on the body, like the shop's item grid and the appearance panel's columns. The
	-- rows were painted straight onto the window.
	self.PlayerList.Paint = function(_, w, h) PS.Theme.PaintPanelBody(w, h) end
	
	local sbar = self.PlayerList:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	sbar.Paint = function(s, w, h) PS.Theme.PaintScrollTrack(w, h) end
	sbar.btnGrip.Paint = function(s, w, h) PS.Theme.PaintScrollGrip(s, w, h) end
	
	-- List container, in the scroll panel's CANVAS rather than parented to the scroll panel.
	-- See the item windows below: parented directly, Dock(FILL) pins it to the viewport and
	-- the roster cannot scroll however many players are on.
	self.ListContainer = vgui.Create("DListLayout")
	self.PlayerList:AddItem(self.ListContainer)
	self.ListContainer:Dock(TOP)

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
		draw.SimpleText(itemCount, "PS_Default", w - 450, h / 2, PS.Theme.ButtonText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	
	-- Laid out right to left by slot rather than from four written-down offsets. Removing the
	-- Give Item button meant shifting every one of those by hand, which is how they end up
	-- disagreeing with the column headers above them.
	local btnW = 88
	local btnH = 40
	local gap  = PS.Theme.Metrics.Gap

	local slot = 0
	local function Action(style, label, onClick)
		local at = slot
		slot = slot + 1

		local b = vgui.Create("DButton", row)
		b:SetText("")
		b.PerformLayout = function(s)
			s:SetSize(btnW, btnH)
			s:SetPos(row:GetWide() - (at + 1) * (btnW + gap),
				math.floor((row:GetTall() - btnH) / 2))
		end
		b.Paint = function(s, w, h)
			PS.Theme.PaintAction(s, w, h, PS.Theme.Action[style], label)
		end
		b.DoClick = onClick
		b:InvalidateLayout(true)
		return b
	end

	-- Right to left: Set Points, Give Points, Items.
	Action("Accent",   "Set Points",  function() self:PromptSetPoints(ply) end)
	Action("Positive", "Give Points", function() self:PromptGivePoints(ply) end)
	Action("Modify",   "Items",       function() self:OpenItemsWindow(ply) end)
end

function PANEL:OpenItemsWindow(ply)
	if not IsValid(ply) then return end

	-- PS_Items are only networked to the item owner; request them from the server
	local idx = ply:EntIndex()
	_adminItemsCallbacks[idx] = {
		expires = CurTime() + ADMIN_REQ_TIMEOUT,
		fn = function(resolvedPly, items)
			if not IsValid(self) then return end
			self:_BuildItemsWindow(resolvedPly, items)
		end,
	}

	net.Start('PS_AdminRequestItems')
		net.WriteEntity(ply)
	net.SendToServer()
end

-- Every item that exists, and what this player can be done with it.
--
-- This was two windows: View Items listed what they owned with a Take button, Give Item
-- listed everything with a Give button. Same list, filtered two ways, opened from two row
-- buttons. Worse, the Give list did not know what they already owned, and the server refuses
-- a give for an item they have -- silently -- so those rows looked live and did nothing.
--
-- One list now. The action follows ownership, which is the thing the admin is actually
-- deciding, and the row says which state it is in rather than the window saying it.
function PANEL:_BuildItemsWindow(ply, owned)
	if not IsValid(ply) then return end

	local frame = PS.UI.Frame({
		title = "Items",
		w     = 900,
		h     = 600,
	})

	-- Ownership, kept current locally as buttons are pressed. The server sends no
	-- acknowledgement for a give or a take, and re-requesting the whole inventory per click
	-- would trip its own 0.5s rate limit on the request.
	local ownedNow = {}
	for id, data in pairs(owned or {}) do
		ownedNow[id] = data or {}
	end

	-- Scrollable item list
	local scroll = vgui.Create("DScrollPanel", frame)
	scroll:Dock(FILL)
	scroll:DockMargin(PS.Theme.Metrics.Gap, PS.Theme.Metrics.Gap,
		PS.Theme.Metrics.Gap, PS.Theme.Metrics.Gap)
	scroll.Paint = function(_, w, h) PS.Theme.PaintPanelBody(w, h) end

	local sbar = scroll:GetVBar()
	sbar:SetWide(12)
	sbar:SetHideButtons(true)
	sbar.Paint = function(s, w, h) PS.Theme.PaintScrollTrack(w, h) end
	sbar.btnGrip.Paint = function(s, w, h) PS.Theme.PaintScrollGrip(s, w, h) end

	-- Added to the scroll panel's CANVAS, not parented to the scroll panel itself. Parented
	-- directly it is a sibling of the canvas and of the scrollbar, so Dock(FILL) stretched it
	-- across the whole rect including the bar's strip -- the rightmost column drew under the
	-- scrollbar, and the list could not scroll at all because FILL pins it to the viewport.
	local list = vgui.Create("DListLayout")
	scroll:AddItem(list)
	list:Dock(TOP)

	-- Add header
	local header = vgui.Create("DPanel", list)
	header:SetTall(45)
	header:Dock(TOP)
	header.Paint = function(s, w, h)
		surface.SetDrawColor(PS.Theme.RowHover)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("Item Name", "PS_DefaultBold", 15, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Category", "PS_DefaultBold", w - 400, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Owned", "PS_DefaultBold", w - 250, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Actions", "PS_DefaultBold", w - 150, h/2, PS.Theme.MenuRowText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- Everything that exists, plus anything this player owns that no longer does.
	--
	-- The orphans matter: an item whose Lua file was deleted while players still owned it is
	-- invisible in their own shop and unreachable from it, so if it is not listed here there
	-- is no in-game way to take it back. Take still works on one, because the server takes
	-- by ID and does not need the item to exist.
	local rows = {}
	for _, ITEM in pairs(PS.Items) do
		rows[#rows + 1] = { id = ITEM.ID, ITEM = ITEM }
	end
	for id in pairs(ownedNow) do
		if not PS.Items[id] then rows[#rows + 1] = { id = id } end
	end

	-- Sorted by category then name, and orphans last under their own heading. pairs() over
	-- the table gave a different order on every open, which makes finding anything in a list
	-- this long a matter of luck.
	local ORPHAN = "zzz orphaned - no item file"
	table.sort(rows, function(a, b)
		local ac = a.ITEM and string.lower(a.ITEM.Category or "Misc") or ORPHAN
		local bc = b.ITEM and string.lower(b.ITEM.Category or "Misc") or ORPHAN
		if ac ~= bc then return ac < bc end

		local an = a.ITEM and a.ITEM.Name or a.id
		local bn = b.ITEM and b.ITEM.Name or b.id
		return string.lower(an) < string.lower(bn)
	end)

	for _, entry in ipairs(rows) do
		local itemID, ITEM = entry.id, entry.ITEM

		local displayName = ITEM and ITEM.Name or (itemID .. "  (orphaned - no item file)")
		local category    = ITEM and (ITEM.Category or "Misc") or "-"
		local nameCol     = ITEM and PS.Theme.Text or PS.Theme.WarningBorder

		local itemRow = vgui.Create("DPanel", list)
		itemRow:SetTall(50)
		itemRow:Dock(TOP)
		itemRow:DockMargin(0, 1, 0, 1)

		itemRow.Paint = function(s, w, h)
			PS.Theme.PaintRow(s, w, h)

			local shown = FitText(s, displayName, "PS_Default", w - 420)
			draw.SimpleText(shown, "PS_Default", 15, h/2, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(category, "PS_Default", w - 400, h/2, PS.Theme.ButtonText,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			-- Owned, and equipped as a qualifier on it. Equipped without owned cannot happen,
			-- so it is one column rather than two.
			local data = ownedNow[itemID]
			local label, col

			if data and data.Equipped then
				label, col = "Equipped", PS.Theme.PriceAfford
			elseif data then
				label, col = "Yes", PS.Theme.Text
			else
				label, col = "No", PS.Theme.MenuRowText
			end

			draw.SimpleText(label, "PS_Default", w - 250, h/2, col,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		-- One button, and which one it is follows ownership. Re-read in Paint rather than
		-- decided at build time, because pressing it changes the answer.
		local actBtn = vgui.Create("DButton", itemRow)
		actBtn:SetSize(100, 25)
		actBtn:SetText("")
		actBtn.PerformLayout = function(btn)
			btn:SetPos(itemRow:GetWide() - 120, 12)
		end

		actBtn.Paint = function(s, w, h)
			local has = ownedNow[itemID] ~= nil
			PS.Theme.PaintAction(s, w, h,
				has and PS.Theme.Action.Danger or PS.Theme.Action.Positive,
				has and "Take Item" or "Give Item")
		end

		actBtn.DoClick = function()
			if ownedNow[itemID] then
				net.Start('PS_TakeItem')
					net.WriteEntity(ply)
					net.WriteString(itemID)
				net.SendToServer()
				ownedNow[itemID] = nil
				AdminPatchSummary(ply, function(e) e.items = math.max(0, e.items - 1) end)
			else
				net.Start('PS_GiveItem')
					net.WriteEntity(ply)
					net.WriteString(itemID)
				net.SendToServer()
				ownedNow[itemID] = {}
				AdminPatchSummary(ply, function(e) e.items = e.items + 1 end)
			end

			-- The window stays up. It used to close on every take, so clearing a player out
			-- meant reopening and re-scrolling once per item.
			if IsValid(self) then self:RequestSummary() end
		end

		actBtn:InvalidateLayout(true)
	end
end


function PANEL:PromptGivePoints(ply)
	if not IsValid(ply) then return end
	
	local pointsName = (PS and PS.Config and PS.Config.PointsName) or "Points"
	
	local frame = PS.UI.Frame({
		title = "Give",
		w     = 300,
		h     = 120 + PS.UI.HeaderH(),
	})
	
	local label = vgui.Create("DLabel", frame)
	-- Names the target and the unit, because the title no longer can. This dialog writes a
	-- player's balance and the only other thing in it is a number box; without this there is
	-- nothing on screen saying whose balance is about to change.
	label:SetText(pointsName .. " for " .. ply:Nick() .. ":")
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

		AdminPatchSummary(ply, function(e) e.points = e.points + amount end)

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
	
	local frame = PS.UI.Frame({
		title = "Set",
		w     = 300,
		h     = 120 + PS.UI.HeaderH(),
	})
	
	local label = vgui.Create("DLabel", frame)
	-- Names the target and the unit, because the title no longer can. This dialog writes a
	-- player's balance and the only other thing in it is a number box; without this there is
	-- nothing on screen saying whose balance is about to change.
	label:SetText(pointsName .. " for " .. ply:Nick() .. ":")
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

		AdminPatchSummary(ply, function(e) e.points = amount end)

		-- See PromptGivePoints: summary refresh rather than a full list rebuild, delayed
		-- past the server's rate limit on the request.
		if IsValid(self) then self._NextSummary = CurTime() + 0.6 end
	end
end

-- PromptGiveItem lived here: a second 900x600 window listing every item with a Give button,
-- opened from its own row button. It is _BuildItemsWindow now -- one list where the action
-- follows ownership, rather than two lists that differ by which action they offer.

-- PANEL:Paint lived here and drew the frame body. SetupFrame sets Paint on the instance,
-- which shadows a class method, so this had stopped being the one that ran -- and it drew
-- the body without the header strip, so leaving it would have been a silent difference
-- waiting for someone to move the call order.

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
