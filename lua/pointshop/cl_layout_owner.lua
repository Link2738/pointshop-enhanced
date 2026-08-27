--[[
	pointshop/cl_layout_owner.lua

	Owner tool: the shop window's house size.

	Registers through PS_CollectOwnerTools like every other owner panel, so it appears behind
	the star button in the shop header and nowhere else. Nothing here is drawn for anyone who
	does not pass the owner check, and the server re-checks that gate on arrival regardless --
	hiding a button is not security and is not treated as any.

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
	saving puts back what was there when it opened. Only "Set as server default" leaves this
	client.
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

local function Restore(tbl)
	for k, v in pairs(tbl) do T.SetBaseMetric(k, v) end
	Relayout()
end

-- ============================================================================
-- PANEL
-- ============================================================================

local function Open()
	if IsValid(panel) then panel:Remove() end

	local M = T.Metrics
	before = T.FrameMetrics()

	local ROW_H = 76

	local f = UI.Frame({
		remember = "shoplayout",
		title = "Shop layout",
		w     = 470,
		h     = M.HeaderH + 26 + M.Margin * 2 + 2 * (ROW_H + M.Gap) + M.ButtonH + M.Gap * 2,
	})
	panel = f

	-- OnRemove, not onClose: onClose only fires from the X button, and this has to hold for
	-- Escape and for a reopen replacing the old panel too.
	f.OnRemove = function()
		if before then Restore(before) end
	end

	local strip = vgui.Create("DPanel", f)
	strip:Dock(TOP)
	strip:SetTall(26)
	strip.Paint = function(_, w, h)
		T.PaintStatusStrip(w, h, "Live while open · reverts on close unless saved")
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

	local rowIndex = 0

	-- One row per dimension: mode on the left, its value on the right, min and max beneath.
	local function AxisRow(axis, label, names)
		rowIndex = rowIndex + 1
		local i = rowIndex

		local row = vgui.Create("DPanel", body)
		row:Dock(TOP)
		row:SetTall(ROW_H)
		row:DockMargin(M.Margin, i == 1 and M.Margin or 0, M.Margin, M.Gap)
		row.Paint = function(_, w, h)
			T.PaintRow(row, w, h, i, false)
			draw.SimpleText(label, "PS_DefaultBold", M.Margin, 12,
				T.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

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

		local combo = vgui.Create("DComboBox", row)
		combo:SetSortItems(false)
		for k = FIXED, INSET do combo:AddChoice(names[k], k, k == mode) end
		combo.PerformLayout = function(s)
			s:SetPos(M.Margin, 28)
			s:SetSize((row:GetWide() - M.Margin * 3) / 2, 20)
		end
		combo.OnSelect = function(_, _, _, data)
			mode = data

			-- The number means something different in each mode, so carrying the old one
			-- across produces nonsense: 900 read as a percentage, or 62 read as pixels.
			-- There is no honest conversion either -- "900 wide" has no percentage that is
			-- right on every monitor, which is the whole reason the modes exist -- so each
			-- mode gets a sensible starting value and the owner adjusts from there.
			local lo, hi = ValueRange(mode, axis)
			local START = { [FIXED] = 900, [SHARE] = 62, [INSET] = 100 }
			value = math.Clamp(START[mode], lo, hi)

			valueSlider:SetMin(lo)
			valueSlider:SetMax(hi)
			valueSlider:SetValue(value)
			Push()
		end

		local lo, hi = ValueRange(mode, axis)
		valueSlider = vgui.Create("DNumSlider", row)
		valueSlider:SetText("")
		valueSlider:SetMin(lo)
		valueSlider:SetMax(hi)
		valueSlider:SetDecimals(0)
		valueSlider:SetValue(value)
		valueSlider.PerformLayout = function(s)
			local half = (row:GetWide() - M.Margin * 3) / 2
			s:SetPos(M.Margin * 2 + half, 28)
			s:SetSize(half, 20)
		end
		valueSlider.OnValueChanged = function(_, v)
			value = math.Round(v)
			Push()
		end

		-- Min and max are the guard rails: they are what stops a share-of-screen shop from
		-- becoming unusable on a very small or very wide monitor, so they are edited here
		-- rather than hidden.
		local function Bound(key, x, labelText)
			local sl = vgui.Create("DNumSlider", row)
			sl:SetText(labelText)
			sl:SetMin(240)
			sl:SetMax(2200)
			sl:SetDecimals(0)
			sl:SetValue(T.BaseMetric(key))
			sl.Label:SetTextColor(T.TextDim)
			sl.PerformLayout = function(s)
				local half = (row:GetWide() - M.Margin * 3) / 2
				s:SetPos(x(half), 52)
				s:SetSize(half, 18)
			end
			sl.OnValueChanged = function(_, v)
				T.SetBaseMetric(key, math.Round(v))

				-- A max under its min silently inverts the clamp, so the pair is kept in
				-- order here rather than at every place that reads it.
				if T.BaseMetric(maxKey) < T.BaseMetric(minKey) then
					if key == maxKey then
						T.SetBaseMetric(minKey, T.BaseMetric(maxKey))
					else
						T.SetBaseMetric(maxKey, T.BaseMetric(minKey))
					end
				end
				Relayout()
			end
			return sl
		end

		Bound(minKey, function() return M.Margin end, "Min")
		Bound(maxKey, function(half) return M.Margin * 2 + half end, "Max")

		return row
	end

	AxisRow("W", "Width",  MODE_NAMES)
	AxisRow("H", "Height", MODE_NAMES_H)

	local save = UI.Button(buttons, "Set as server default", "Gold", function()
		UI.Confirm({
			text = "Make this the shop's size for everyone?",
			yes  = "Set default",
			onYes = function()
				net.Start("PS_Theme_SetDefault")
					net.WriteString(util.TableToJSON({
						colours = T.Snapshot(),
						metrics = T.FrameMetrics(),
					}))
				net.SendToServer()

				-- Saved, so closing must not put the old size back.
				before = T.FrameMetrics()
			end,
		})
	end)
	save:Dock(LEFT)
	save:SetWide(190)

	local revert = UI.Button(buttons, "Revert", "Neutral", function()
		if before then Restore(before) end
	end)
	revert:Dock(RIGHT)
	revert:SetWide(90)

	return f
end

hook.Add("PS_CollectOwnerTools", "PS_ShopLayout", function(add)
	add("Shop layout", Open)
end)
