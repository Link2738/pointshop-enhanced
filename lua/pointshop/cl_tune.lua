--[[
	pointshop/cl_tune.lua
	UI tuning panel. Debug only.

	Icon placement lives as constants in cl_ui.lua. This makes them live while the panel is
	open so a value can be found by eye, prints the block to paste back, and reverts on close.

	Reverting is the point, not a convenience: a value you liked but did not write down
	should not persist and leave you looking at something the shipped code does not produce.
]]

if not CLIENT then return end
if not (PS.Config and PS.Config.Debug) then return end

local SHARED = {
	{ key = "ButtonY", label = "Button Y (all)", min = -8, max = 8 },
	{ key = "ShadowX", label = "Shadow X (all)", min = -4, max = 4 },
	{ key = "ShadowY", label = "Shadow Y (all)", min = -4, max = 4 },
}

-- Fixed order, so the panel does not reshuffle between opens the way pairs() would.
local ORDER = { "close", "gear", "star" }

local panel

local function Revert()
	local cv = PS.UI.IconCVars
	if not cv then return end
	for k, v in pairs(PS.UI.IconShared) do cv.shared[k]:SetInt(v) end
	for name, def in pairs(PS.UI.Icons) do
		cv.icons[name].x:SetInt(def.x)
		cv.icons[name].y:SetInt(def.y)
	end
end

local function Dump()
	local cv = PS.UI.IconCVars
	if not cv then return end

	MsgN("")
	MsgN("-- paste into cl_ui.lua")
	MsgN("UI.Icons = {")
	for _, name in ipairs(ORDER) do
		MsgN(string.format("\t%-5s = { glyph = %q, x = %d, y = %d },",
			name, PS.UI.Icons[name].glyph, cv.icons[name].x:GetInt(), cv.icons[name].y:GetInt()))
	end
	MsgN("}")
	MsgN(string.format("UI.IconShared = { ButtonY = %d, ShadowX = %d, ShadowY = %d }",
		cv.shared.ButtonY:GetInt(), cv.shared.ShadowX:GetInt(), cv.shared.ShadowY:GetInt()))
	MsgN("")

	chat.AddText(PS.Theme.Accent, "[PS] ", color_white, "Values printed to console.")
end

local function Open()
	if IsValid(panel) then panel:Remove() end

	local T, UI = PS.Theme, PS.UI
	local M     = T.Metrics
	local ROW_H = 42

	-- One row per shared value, plus one per icon carrying an X and a Y.
	local rowCount = #SHARED + #ORDER

	local f = UI.Frame({
		title = "UI tuning",
		w     = 460,
		h     = M.HeaderH + 26 + M.Margin * 2 + rowCount * (ROW_H + M.Gap) + M.ButtonH + M.Gap,
	})
	panel = f

	-- OnRemove rather than UI.Frame's onClose: that only fires from the X button, and this
	-- has to hold for Escape and for a reopen replacing the old panel too.
	f.OnRemove = Revert

	local strip = vgui.Create("DPanel", f)
	strip:Dock(TOP)
	strip:SetTall(26)
	strip.Paint = function(_, w, h)
		T.PaintStatusStrip(w, h, "Live while open · reverts on close")
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

	local copy = UI.Button(buttons, "Print to console", "Accent", Dump)
	copy:Dock(LEFT)
	copy:SetWide(150)

	local reset = UI.Button(buttons, "Revert", "Neutral", Revert)
	reset:Dock(RIGHT)
	reset:SetWide(90)

	local index = 0

	local function AddRow(label, build)
		index = index + 1
		local i = index

		local row = vgui.Create("DPanel", body)
		row:Dock(TOP)
		row:SetTall(ROW_H)
		row:DockMargin(M.Margin, i == 1 and M.Margin or 0, M.Margin, M.Gap)
		row.Paint = function(_, w, h)
			T.PaintRow(row, w, h, i, false)
			draw.SimpleText(label, "PS_DefaultBold", M.Margin, 11,
				T.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		build(row)
		return row
	end

	local function Slider(row, cv, min, max, x, w)
		local sl = vgui.Create("DNumSlider", row)
		sl:SetText("")
		sl:SetMin(min)
		sl:SetMax(max)
		sl:SetDecimals(0)
		sl:SetValue(cv:GetInt())
		sl.PerformLayout = function(s)
			s:SetPos(x(row), 21)
			s:SetSize(w(row), 18)
		end
		sl.OnValueChanged = function(_, v) cv:SetInt(math.Round(v)) end
		return sl
	end

	local full  = function(r) return M.Margin end
	local fullW = function(r) return r:GetWide() - M.Margin * 2 end

	for _, fld in ipairs(SHARED) do
		AddRow(fld.label, function(row)
			Slider(row, PS.UI.IconCVars.shared[fld.key], fld.min, fld.max, full, fullW)
		end)
	end

	-- Each icon gets X and Y side by side, so the pair reads as one control rather than as
	-- two unrelated rows you have to remember belong together.
	for _, name in ipairs(ORDER) do
		local cv = PS.UI.IconCVars.icons[name]
		AddRow(name .. "   " .. PS.UI.Icons[name].glyph, function(row)
			local half  = function(r) return M.Margin end
			local halfW = function(r) return (r:GetWide() - M.Margin * 3) / 2 end
			local rightX = function(r) return M.Margin * 2 + halfW(r) end

			Slider(row, cv.x, -8, 8, half, halfW)
			Slider(row, cv.y, -8, 8, rightX, halfW)
		end)
	end

	return f
end

hook.Add("PS_CollectOwnerTools", "PS_UITuning", function(add)
	add("UI tuning", Open)
end)

concommand.Add("ps_tune", Open, nil, "Open the UI tuning panel (debug only).")
