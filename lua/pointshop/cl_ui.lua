--[[
	PointShop - Widget layer

	Construction, where cl_theme.lua is paint.

	The shop had no shared widget layer, so the same recipe existed in six copies: 76
	hand-written Paint functions, 28 buttons each with its own, 5 separately styled
	scrollbars. They drifted apart one edit at a time — which is why the greys disagreed, and
	why the same scrim bug sat in five files. It was pasted, not shared.

	Everything here returns a real Derma panel. Callers still Dock, SetSize, and hook events
	exactly as before; this wraps Derma rather than replacing it, so nothing has to be learned
	twice and any panel can drop out of it for one control without leaving the system.

	No Paint function below allocates. Colours come from PS.Theme, and anything derived goes
	through T.Shade / T.Alpha into a scratch the caller owns. That is the whole reason the
	shop was rebuilding 123 Colors a frame.
]]

PS = PS or {}
PS.UI = PS.UI or {}

local UI = PS.UI

local function T() return PS.Theme end
local function M() return PS.Theme.Metrics end

-- ============================================================================
-- BUTTONS
-- ============================================================================

-- Labelled action button. `style` names an entry in PS.Theme.Action — "Positive",
-- "Warning", "Neutral", and so on.
function UI.Button(parent, label, style, onClick)
	local btn = vgui.Create("DButton", parent)
	btn:SetText("")
	btn:SetTall(M().ButtonH)
	btn.DoClick = onClick or function() end
	btn.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action[style] or PS.Theme.Action.Neutral, label)
	end
	return btn
end

-- Square button carrying a drawn glyph rather than a label.
--
-- `icon` is a function(w, h) that draws into the button, not a string: the header icons are
-- hand-drawn shapes and swatch grids, not text, and the ones that ARE text want their own
-- shadow offset. Handing the caller the surface is simpler than a config table trying to
-- describe every case.

-- Icons, by name rather than by character. Call sites say UI.GlyphIcon("bolt").
--
-- x and y are per icon because they need to be: the three glyphs come from different
-- fallback fonts and sit differently in their boxes, so one shared offset cannot fix all
-- three. Window dressing, so they are constants -- nothing to read or network at runtime.
--
-- Under PS.Config.Debug each gets live convars (ps_icon_bolt_x, ps_icon_bolt_y, ...) and
-- the tuning panel drives them. Write what you settle on back into this table.
UI.Icons = {
	close = { glyph = "X",  x = 0, y =  1 },
	bolt  = { glyph = "⚡", x = 0, y = -4 },
	star  = { glyph = "★", x = 0, y = -2 },
}

-- Shared by every icon: the button's place in the header, and the shadow behind the glyph.
UI.IconShared = { ButtonY = 0, ShadowX = 1, ShadowY = 1 }

UI.IconCVars = nil

if PS.Config and PS.Config.Debug then
	-- Not saved to the client config: a tuning value that persists is one you forget you
	-- set, and then what you are looking at is not the shipped constant.
	local function CV(n, v)
		return CreateClientConVar("ps_icon_" .. n, tostring(v), false, false)
	end

	UI.IconCVars = { shared = {}, icons = {} }
	for k, v in pairs(UI.IconShared) do
		UI.IconCVars.shared[k] = CV(string.lower(k), v)
	end
	for name, def in pairs(UI.Icons) do
		UI.IconCVars.icons[name] = { x = CV(name .. "_x", def.x), y = CV(name .. "_y", def.y) }
	end
end

local function Shared(k)
	local cv = UI.IconCVars
	if cv then return cv.shared[k]:GetInt() end
	return UI.IconShared[k]
end

local function Offset(name)
	local cv = UI.IconCVars
	if cv and cv.icons[name] then return cv.icons[name].x:GetInt(), cv.icons[name].y:GetInt() end
	local d = UI.Icons[name]
	return d and d.x or 0, d and d.y or 0
end

function UI.IconBtnY()
	return math.floor((M().HeaderH - M().IconBtn) / 2) + Shared("ButtonY")
end

function UI.GlyphIcon(name, font)
	font = font or "PS_Heading2"
	local def = UI.Icons[name]
	local glyph = def and def.glyph or name   -- a raw character still works

	return function(w, h)
		local ox, oy = Offset(name)
		local cx, cy = w / 2 + ox, h / 2 + oy
		draw.SimpleText(glyph, font, cx + Shared("ShadowX"), cy + Shared("ShadowY"),
			PS.Theme.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(glyph, font, cx, cy,
			PS.Theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- REMEMBERED PANEL POSITIONS
--
-- Drag a panel somewhere and it opens there next time, across reopens, map changes and
-- rejoins. Stored with the client's palette in PS.Theme.Panels -- same store, because it
-- is the same thing: this client's own record of how they like the UI.
--
-- Restored positions are CLAMPED to the current screen, which is why this is a helper
-- rather than four lines in each panel. A position saved on a second monitor, or before a
-- resolution change, is coordinates that no longer exist -- and a panel restored
-- off-screen cannot be dragged back, because there is nothing left to grab.
function UI.RememberPosition(panel, key)
	if not IsValid(panel) or not key then return end

	local w, h = panel:GetSize()
	panel:SetPos(ScrW() / 2 - w / 2, ScrH() / 2 - h / 2)

	local saved = PS.Theme.Panels and PS.Theme.Panels[key]
	if saved and saved.x and saved.y then
		panel:SetPos(math.Clamp(saved.x, 0, math.max(0, ScrW() - w)),
			math.Clamp(saved.y, 0, math.max(0, ScrH() - h)))
	end

	-- Saved when the drag ENDS, not while it happens, or this writes a file every frame the
	-- panel is moving. DFrame sets Dragging for the duration.
	local oldThink = panel.Think
	panel.Think = function(s, ...)
		if oldThink then oldThink(s, ...) end

		if s.Dragging then
			s._posMoved = true
		elseif s._posMoved then
			s._posMoved = nil
			local x, y = s:GetPos()
			PS.Theme.Panels[key] = { x = math.Round(x), y = math.Round(y) }
			PS.Theme.SavePanels()
		end
	end
end

-- Forgets every remembered position. The way back for a panel that ended up somewhere
-- unreachable despite the clamp.
concommand.Add("ps_reset_panels", function()
	PS.Theme.Panels = {}
	PS.Theme.SavePanels()
	chat.AddText(PS.Theme.Accent, "[PS] ", color_white, "Panel positions reset.")
end, nil, "Forget remembered panel positions.")

function UI.IconButton(parent, icon, style, onClick)
	local btn = vgui.Create("DButton", parent)
	btn:SetText("")
	btn:SetSize(M().IconBtn, M().IconBtn)
	btn.DoClick = onClick or function() end
	btn.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action[style] or PS.Theme.Action.Neutral)
		if icon then icon(w, h) end
	end
	return btn
end

-- One of a set where exactly one is active: category buttons, tabs, value pickers.
--
-- `isActive` is a function rather than a flag because the active one changes without this
-- button being told — clicking a sibling has to redraw this one, and asking at paint time is
-- the only version that cannot go stale.
--
-- It is handed the button, so a caller that stores the flag on the panel can write
-- `function(s) return s.IsActive end` rather than closing over a local that does not exist
-- yet at the point the callback is written.
function UI.Tab(parent, label, isActive, onClick, style)
	local btn = vgui.Create("DButton", parent)
	btn:SetText(label or "")
	btn:SetFont("PS_CategoryButton")
	btn:SetTextColor(PS.Theme.Text)
	btn.DoClick = onClick or function() end
	btn.Paint = function(s, w, h)
		PS.Theme.PaintSelectable(s, w, h, isActive and isActive(s) or false,
			PS.Theme.Selectable[style or "Category"])
	end
	return btn
end

-- ============================================================================
-- CONTAINERS
-- ============================================================================

-- DScrollPanel with a themed bar.
--
-- The bar is styled here rather than by each caller because it was the single most copied
-- block in the addon — five instances, all subtly different widths and colours.
function UI.Scroll(parent)
	local scroll = vgui.Create("DScrollPanel", parent)

	local bar = scroll:GetVBar()
	bar:SetWide(M().ScrollW)
	bar:SetHideButtons(true)
	bar.Paint = function(_, w, h) PS.Theme.PaintScrollTrack(w, h) end
	bar.btnGrip.Paint = function(s, w, h) PS.Theme.PaintScrollGrip(s, w, h) end

	return scroll
end

-- A scrolling list of rows.
--
-- :AddRow() returns the row panel; put whatever you like in it. The list tracks the index so
-- the alternating stripe survives rows being added over time rather than all at once.
function UI.List(parent)
	local list = UI.Scroll(parent)
	list._rows = 0

	function list:AddRow(tall)
		self._rows = self._rows + 1
		local index = self._rows

		local row = vgui.Create("DPanel", self)
		row:Dock(TOP)
		row:SetTall(tall or M().RowH)
		row:DockMargin(0, 0, 0, 2)
		row.Index = index
		row.Paint = function(s, w, h)
			PS.Theme.PaintRow(s, w, h, s.Index, s.Selected)
		end
		return row
	end

	function list:Reset()
		self:Clear()
		self._rows = 0
	end

	return list
end

-- ============================================================================
-- FRAMES
-- ============================================================================

-- A themed window: body, border, header with a title, and a close button.
--
-- opts: title, w, h, closable (default true), onClose, center (default true),
--       remember (a key: the panel opens where it was last dragged)
function UI.Frame(opts)
	opts = opts or {}

	local frame = vgui.Create("DFrame")
	frame:SetSize(opts.w or 600, opts.h or 400)
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(opts.draggable ~= false)
	frame:SetSizable(opts.sizable or false)

	if opts.center ~= false then frame:Center() end
	if opts.popup ~= false then frame:MakePopup() end
	if opts.remember then UI.RememberPosition(frame, opts.remember) end

	frame.Paint = function(_, w, h) PS.Theme.PaintFrame(w, h) end

	local header = vgui.Create("DPanel", frame)
	header:Dock(TOP)
	header:SetTall(M().HeaderH)
	header.Paint = function(_, w, h) PS.Theme.PaintHeader(w, h, opts.title) end
	frame.Header = header

	if opts.closable ~= false then
		local close = UI.IconButton(header, UI.GlyphIcon("close"), "Danger", function()
			if opts.onClose then opts.onClose(frame) end
			frame:Close()
		end)

		-- Positioned in PerformLayout, not once at build time. A sizable frame moved the
		-- header out from under a one-shot SetPos and stranded the button mid-bar, or off
		-- the panel entirely.
		close.PerformLayout = function(s)
			s:SetPos(header:GetWide() - M().IconBtn - 15, UI.IconBtnY())
		end

		frame.CloseButton = close
	end

	return frame
end

-- Modal yes/no.
--
-- Replaces three separately hand-built confirmation dialogs, which is also why the Yes and
-- No buttons had drifted into three different greens and greys.
--
-- opts: title, text, yes, no, onYes, onNo
function UI.Confirm(opts)
	opts = opts or {}

	local frame = UI.Frame({
		title    = opts.title or "Confirm",
		w        = opts.w or 400,
		h        = opts.h or 190,
		closable = false,
	})

	local body = vgui.Create("DPanel", frame)
	body:Dock(FILL)
	body:DockMargin(M().Margin, M().Margin, M().Margin, M().Margin)
	body.Paint = function(_, w, h)
		draw.SimpleText(opts.text or "", "DermaDefaultBold", w / 2, h / 2 - 20,
			PS.Theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local row = vgui.Create("DPanel", frame)
	row:Dock(BOTTOM)
	row:SetTall(M().ButtonH + M().Margin * 2)
	row:DockMargin(M().Margin, 0, M().Margin, 0)
	row.Paint = function() end

	local function Finish(fn)
		return function()
			frame:Close()
			if fn then fn() end
		end
	end

	local no = UI.Button(row, opts.no or "No", "Neutral", Finish(opts.onNo))
	no:Dock(RIGHT)
	no:SetWide(120)

	local yes = UI.Button(row, opts.yes or "Yes", "Positive", Finish(opts.onYes))
	yes:Dock(RIGHT)
	yes:DockMargin(0, 0, M().Gap, 0)
	yes:SetWide(120)

	return frame
end
