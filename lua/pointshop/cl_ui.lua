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
-- An icon drawn from a text glyph, optically centred.
--
-- TEXT_ALIGN_CENTER centres on the font's LINE BOX, not on the glyph's ink. For a letter
-- those are close enough -- "X" fills its box and reads as centred. For a symbol they are
-- not: the ink sits wherever the designer put it inside a box sized for text, so a gear or
-- a star lands visibly off the button's middle.
--
-- Neither symbol exists in the UI font either, so both come from whatever the engine falls
-- back to: a different face, different metrics, chosen per machine.
--
-- Ink bounds cannot be measured from Lua, so the correction is a nudge per glyph. Ugly, but
-- honest -- the alternative is drawing each icon as geometry, which for a gear is a lot of
-- arithmetic to solve a two-pixel problem.
--
-- The floor matters as much as the nudge: the icon button is 35 wide, so w / 2 is 17.5 and
-- the renderer resolves the half-pixel however it likes. Flooring picks a side and keeps it.
UI.GlyphNudge = {
	["X"] = { 0, 0 },
	["⚙"] = { 0, -1 },   -- gear
	["★"] = { 0, -1 },   -- star
}

function UI.GlyphIcon(glyph, font)
	font = font or "PS_Heading2"
	local n = UI.GlyphNudge[glyph] or { 0, 0 }
	local dx, dy = n[1], n[2]

	return function(w, h)
		local cx, cy = math.floor(w / 2) + dx, math.floor(h / 2) + dy
		draw.SimpleText(glyph, font, cx + 1, cy + 1, PS.Theme.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(glyph, font, cx, cy, PS.Theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

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
-- opts: title, w, h, closable (default true), onClose, center (default true)
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

	frame.Paint = function(_, w, h) PS.Theme.PaintFrame(w, h) end

	local header = vgui.Create("DPanel", frame)
	header:Dock(TOP)
	header:SetTall(M().HeaderH)
	header.Paint = function(_, w, h) PS.Theme.PaintHeader(w, h, opts.title) end
	frame.Header = header

	if opts.closable ~= false then
		local close = UI.IconButton(header, UI.GlyphIcon("X"), "Danger", function()
			if opts.onClose then opts.onClose(frame) end
			frame:Close()
		end)

		-- Positioned in PerformLayout, not once at build time. A sizable frame moved the
		-- header out from under a one-shot SetPos and stranded the button mid-bar, or off
		-- the panel entirely.
		close.PerformLayout = function(s)
			s:SetPos(header:GetWide() - M().IconBtn - 15, (M().HeaderH - M().IconBtn) / 2)
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
