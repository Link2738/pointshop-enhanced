--[[
	pointshop/cl_tune.lua
	UI tuning panel. Debug only.

	Window dressing -- icon offsets and the like -- lives as constants in code. This panel
	makes them live while it is open so a value can be found by eye, prints the block to
	paste back into the source, and reverts on close.

	Reverting on close is the point. A value you liked but did not write down should not
	quietly persist and leave you looking at something the shipped code does not produce.
]]

if not CLIENT then return end
if not (PS.Config and PS.Config.Debug) then return end

local FIELDS = {
	{ key = "ButtonY", label = "Header button Y", min = -8, max = 8 },
	{ key = "NudgeX",  label = "Glyph X",         min = -8, max = 8 },
	{ key = "NudgeY",  label = "Glyph Y",         min = -8, max = 8 },
	{ key = "ShadowX", label = "Shadow X",        min = -4, max = 4 },
	{ key = "ShadowY", label = "Shadow Y",        min = -4, max = 4 },
}

local panel

local function Revert()
	local cv, def = PS.UI.IconCVars, PS.UI.IconDefaults
	if not cv then return end
	for k, v in pairs(def) do cv[k]:SetInt(v) end
end

local function Dump()
	local cv, def = PS.UI.IconCVars, PS.UI.IconDefaults
	if not cv then return end

	MsgN("")
	MsgN("-- paste into ICON in cl_ui.lua")
	MsgN("local ICON = {")
	for _, f in ipairs(FIELDS) do
		MsgN(string.format("\t%-7s = %d,", f.key, cv[f.key]:GetInt()))
	end
	MsgN("}")
	MsgN("")

	chat.AddText(PS.Theme.Accent, "[PS] ", color_white, "Values printed to console.")
end

local function Open()
	if IsValid(panel) then panel:Remove() end

	local T, UI = PS.Theme, PS.UI
	local M = T.Metrics
	local ROW_H = 44

	local f = UI.Frame({
		title = "UI tuning",
		w     = 420,
		h     = M.HeaderH + 26 + M.Margin * 2 + #FIELDS * (ROW_H + M.Gap) + M.Margin + M.ButtonH + M.Gap,
	})
	panel = f

	-- OnRemove, not the frame's onClose: that only fires from the X button, and this has to
	-- revert however the panel goes away -- Escape, Remove, a reopen replacing it.
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

	for i, fld in ipairs(FIELDS) do
		local cv = PS.UI.IconCVars[fld.key]

		local row = vgui.Create("DPanel", body)
		row:Dock(TOP)
		row:SetTall(ROW_H)
		row:DockMargin(M.Margin, i == 1 and M.Margin or 0, M.Margin, M.Gap)
		row.Paint = function(_, w, h)
			T.PaintRow(row, w, h, i, false)
			draw.SimpleText(fld.label, "PS_DefaultBold", M.Margin, 12,
				T.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local sl = vgui.Create("DNumSlider", row)
		sl:SetText("")
		sl:SetMin(fld.min)
		sl:SetMax(fld.max)
		sl:SetDecimals(0)
		sl:SetValue(cv:GetInt())
		sl.PerformLayout = function(s)
			s:SetPos(M.Margin, 22)
			s:SetSize(row:GetWide() - M.Margin * 2, 20)
		end
		sl.OnValueChanged = function(_, v) cv:SetInt(math.Round(v)) end
	end

	return f
end

hook.Add("PS_CollectOwnerTools", "PS_UITuning", function(add)
	add("UI tuning", Open)
end)

concommand.Add("ps_tune", Open, nil, "Open the UI tuning panel (debug only).")
