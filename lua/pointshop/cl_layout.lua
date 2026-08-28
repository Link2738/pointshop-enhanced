--[[
	pointshop/cl_layout.lua

	The shop window's size, set by whoever is looking at it.

	Not owner-only, and nothing here is networked. A window size is a property of the screen it
	is being drawn on -- a player on a 4:3 laptop and one on an ultrawide do not want the same
	window, and neither of them is wrong -- so it belongs to the client the way a colour does.

	The server still supplies canonical sizes through the theme it publishes. Those are the
	starting point; this panel writes the player's own on top, into the same file as their
	colours and without touching them.

	WHAT IT EDITS

	The eight frame metrics, which the shop reduces to  scale * screen + offset, clamped.
	Raw, that is two numbers per dimension whose meaning depends on each other, which is a
	bad thing to hand someone as two sliders. So the panel offers the three shapes that are
	actually useful and derives the pair:

		Fixed              scale 0    offset N     always N pixels
		Share of screen    scale N    offset 0     N% of the screen
		Screen less margin scale 1    offset -N    the screen, less N pixels

	Reading back is the same mapping inverted, so a size set by a look or by hand in the JSON
	still opens in the right mode rather than resetting to Fixed.

	LIVE, AND REVERTIBLE

	Changes apply to the local client immediately and fire PS_PresetChanged so an open shop
	reflows -- an owner needs to see the size, not imagine it. Closing the panel without
	saving puts back what was there when it opened.

	Save sets the size for the whole server. There is no separate personal save: the window
	size belongs to the shop rather than to whoever is looking at it, and the only people who
	can open this panel are the ones who decide that for everyone.
]]--

local T, UI = PS.Theme, PS.UI

local panel = nil

-- What the metrics were when the panel opened, for Revert.
local before = nil

-- ============================================================================
-- MODES
-- ============================================================================

local FIXED, SHARE, INSET = 1, 2, 3

local MODE_NAMES = {
	[FIXED] = "Fixed width",
	[SHARE] = "Share of screen",
	[INSET] = "Screen less margin",
}

-- Height reads better with its own wording for the same three shapes.
local MODE_NAMES_H = {
	[FIXED] = "Fixed height",
	[SHARE] = "Share of screen",
	[INSET] = "Screen less margin",
}

-- scale/offset -> mode + the single number the owner actually sets.
local function Decode(scale, offset)
	if scale <= 0 then return FIXED, offset end
	if scale >= 1 then return INSET, -offset end
	return SHARE, math.Round(scale * 100)
end

local function Encode(mode, value)
	if mode == FIXED then return 0, value end
	if mode == INSET then return 1, -value end
	return math.Clamp(value, 1, 100) / 100, 0
end

-- The value slider's range depends on what the number means: a percentage is 10-100, a
-- pixel count is screen-sized.
local function ValueRange(mode, axis)
	if mode == SHARE then return 10, 100 end
	local screen = axis == "W" and ScrW() or ScrH()
	if mode == INSET then return 0, math.floor(screen / 2) end
	return 320, math.max(screen, 1280)
end

-- ============================================================================
-- APPLY
-- ============================================================================

local function Relayout()
	-- Same signal a look change sends. Sizes were written into panels when they were built,
	-- so an open shop is holding the old ones until something tells it otherwise.
	hook.Run("PS_PresetChanged", T.GetPreset())
end

-- Revert, not edit.
--
-- Goes through RestoreBaseMetrics rather than SetBaseMetric so the restored values are not
-- recorded as deliberate choices -- closing this panel with the X used to pin the old size in
-- as though it had been picked -- and so the whole set is applied in one rescale instead of
-- one per key.
local function Restore(tbl)
	T.RestoreBaseMetrics(tbl)
	Relayout()
end

-- ============================================================================
-- PANEL
-- ============================================================================

-- One axis: how the size is worked out, the number itself, and the two guard rails.
--
-- Built entirely from PS.UI.Rows. There is not a coordinate in this function -- the row
-- builder places each control and reports how tall the stack got, which is what the panel
-- is then sized from. Hand-placing these is what put a drop arrow on top of its own text
-- and half a buttons row off the bottom of the window, three times.
local function AxisRows(rows, axis, label, names)
	local sKey, oKey = "Frame" .. axis .. "Scale", "Frame" .. axis .. "Offset"
	local minKey, maxKey = "Frame" .. axis .. "Min", "Frame" .. axis .. "Max"

	local mode, value = Decode(T.BaseMetric(sKey), T.BaseMetric(oKey))
	local valueSlider

	local function Push()
		local scale, offset = Encode(mode, value)
		T.SetBaseMetric(sKey, scale)
		T.SetBaseMetric(oKey, offset)
		Relayout()
	end

	local options = {}
	for k = FIXED, INSET do options[#options + 1] = { id = k, name = names[k] } end

	rows:Choice({
		label   = label,
		options = options,
		get     = function() return mode end,
		set     = function(picked)
			mode = picked

			-- The number means something different in each mode, so carrying the old one
			-- across produces nonsense: 900 read as a percentage, or 62 read as pixels.
			-- There is no honest conversion -- "900 wide" has no percentage that is right on
			-- every monitor, which is the whole reason the modes exist -- so each mode starts
			-- somewhere sensible and the owner adjusts from there.
			local lo, hi = ValueRange(mode, axis)
			local START = { [FIXED] = 900, [SHARE] = 62, [INSET] = 100 }
			value = math.Clamp(START[mode], lo, hi)

			valueSlider:SetMin(lo)
			valueSlider:SetMax(hi)
			valueSlider:SetValue(value)
			Push()
		end,
	})

	local lo, hi = ValueRange(mode, axis)
	valueSlider = rows:Slider({
		label = "Value", min = lo, max = hi,
		get = function() return value end,
		set = function(v) value = v Push() end,
	})

	-- The guard rails: what stops a share-of-screen shop being unusable on a very small
	-- monitor or absurd on a very wide one.
	local function Bound(key, text)
		rows:Slider({
			label = text, min = 240, max = 2200,
			get = function() return T.BaseMetric(key) end,
			set = function(v)
				T.SetBaseMetric(key, v)

				-- A max under its min silently inverts the clamp, so the pair is kept in order
				-- here rather than at every place that reads it.
				if T.BaseMetric(maxKey) < T.BaseMetric(minKey) then
					if key == maxKey then
						T.SetBaseMetric(minKey, T.BaseMetric(maxKey))
					else
						T.SetBaseMetric(maxKey, T.BaseMetric(minKey))
					end
				end
				Relayout()
			end,
		})
	end

	Bound(minKey, "Minimum")
	Bound(maxKey, "Maximum")
end

local function Open()
	-- Brought forward rather than torn down and rebuilt. Rebuilding re-captured `before`,
	-- which is what a revert restores -- so reopening the panel quietly made the current
	-- values the ones you would revert TO, and the changes you meant to undo became the
	-- baseline.
	if IsValid(panel) then
		panel:MoveToFront()
		panel:RequestFocus()
		return
	end

	local M = T.Metrics
	before = T.FrameMetrics()

	local STRIP = math.Round(26 * T.Scale())

	-- Built before the frame exists, so the frame can be sized from it.
	--
	-- The body panel it will fill is created below and handed in afterwards; the rows only
	-- need a parent at the moment they build controls, and they need to be measured before
	-- there is a window to measure into. So: measure first, build second.
	local probe = PS.UI.Rows(nil, math.Round(560 * T.Scale()))
	AxisRows(probe, "W", "Width",  MODE_NAMES)
	probe:Space(2)
	AxisRows(probe, "H", "Height", MODE_NAMES_H)

	local contentH = probe:Height()

	local f = UI.Frame({
		remember = "shoplayout",
		title = "Layout",
		w     = math.Round(560 * T.Scale()),
		h     = UI.HeaderH() + STRIP + M.Margin * 2 + contentH
		        + M.Gap + M.ButtonH + M.Margin * 2,
	})
	panel = f

	-- OnRemove, not onClose: onClose only fires from the X button, and this has to hold for
	-- Escape and for a reopen replacing the old panel too.
	f.OnRemove = function()
		if before then Restore(before) end
	end

	local strip = vgui.Create("DPanel", f)
	strip:Dock(TOP)
	strip:SetTall(STRIP)
	strip.Paint = function(_, w, h)
		T.PaintStatusStrip(w, h, "Live while open - reverts on close unless saved")
	end

	local body = vgui.Create("DPanel", f)
	body:Dock(FILL)
	body:DockMargin(M.Margin, M.Margin, M.Margin, M.Margin)
	body.Paint = function(_, w, h) T.PaintPanelBody(w, h) end

	local buttons = vgui.Create("DPanel", body)
	buttons:Dock(BOTTOM)
	buttons:DockMargin(M.Margin, M.Gap, M.Margin, M.Margin)
	buttons:SetTall(M.ButtonH)
	buttons.Paint = function() end

	-- The real rows, into the real panel.
	local rows = PS.UI.Rows(body)
	AxisRows(rows, "W", "Width",  MODE_NAMES)
	rows:Space(2)
	AxisRows(rows, "H", "Height", MODE_NAMES_H)

	-- One Save, and it sets the server default.
	--
	-- Saves to this client, and nothing crosses the wire.
	--
	-- No confirmation either: it changes what one person sees, it is reversible by opening
	-- this panel again, and a dialog in front of a preference nobody else is affected by is
	-- friction pretending to be safety.
	--
	-- T.SaveMetrics writes only the sizing section of the client's theme file. Colours live in
	-- the same file and are not touched -- writing the whole file on every save is what
	-- deleted a palette when a size was saved.
	local save = UI.Button(buttons, "Save", "Positive", function()
		T.SaveMetrics()

		-- Saved, so closing must not put the old size back.
		before = T.FrameMetrics()

		notification.AddLegacy("Shop size saved.", NOTIFY_GENERIC, 3)
	end)
	save:Dock(RIGHT)
	save:DockMargin(M.Gap, 0, 0, 0)
	save:SetWide(math.Round(90 * T.Scale()))

	local revert = UI.Button(buttons, "Revert", "Neutral", function()
		if before then Restore(before) end
	end)
	revert:Dock(RIGHT)
	revert:SetWide(math.Round(90 * T.Scale()))

	return f
end

-- Opened from the appearance panel, which is where a player already goes to change how the
-- shop looks to them. Not on the owner menu any more: there is nothing owner-only left in it.
PS.OpenShopLayout = Open
