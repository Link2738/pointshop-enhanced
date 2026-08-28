--[[
	cl_movement.lua — the owner's movement tuning panel.

	Four sliders, applied the moment you release one, so you can stand in the map and feel
	the change rather than editing a config file and restarting between guesses.

	Built on PS.UI and PS.Theme rather than hand-painted derma.

	The first version was hand-painted, on the reasoning that a gameplay tool should not
	depend on PointShop being loaded to open. That reasoning did not survive contact: the
	owner gate this panel uses IS PointShop's, and the way in is a button in the shop
	header. So the dependency was already total, and all the hand-painting bought was one
	window that ignored the server's palette and matched nothing else.

	If PointShop is somehow absent the panel refuses to open and says so, rather than
	erroring halfway through building itself. That is a diagnostic, not a fallback -- there
	is no owner without PointShop either, so there would be nobody allowed to use it.

	Opened from the owner button in the shop header, or `has_movement` in console.
]]

if not CLIENT then return end

local FIELDS = {
	{ key = "JumpPower",     label = "Jump power",  min = 100, max = 400,
	  help = "Stock Source is 200. Below 150 most map geometry stops being reachable." },
	{ key = "StepSize",      label = "Step height", min = 18,  max = 64,
	  help = "Engine default is 18. How tall a ledge you walk over without jumping." },
	{ key = "AirAccelerate", label = "Air control", min = 10,  max = 1000,
	  help = "Stock is 10. High values let you steer freely mid-air." },
	{ key = "Gravity",       label = "Gravity",     min = 200, max = 800,
	  help = "Stock is 600. Lower means longer jumps and more air time." },
}

local values = {}
local panel  = nil

local function IsOwner()
	local me = LocalPlayer()
	if not IsValid(me) then return false end
	if not PS_IsItemDefaultOwner then return false end
	return PS_IsItemDefaultOwner(me)
end

net.Receive("PS_Movement_Sync", function()
	local n = net.ReadUInt(8)
	for _ = 1, n do
		local k = net.ReadString()
		values[k] = net.ReadFloat()
	end

	-- Pushed into an open panel without firing the change callback, or the server's own
	-- broadcast would bounce straight back as a fresh Set.
	if IsValid(panel) and panel.Refresh then panel:Refresh() end
end)

local function Request()
	net.Start("PS_Movement_Get")
	net.SendToServer()
end

local function Send(key, val)
	net.Start("PS_Movement_Set")
		net.WriteString(key)
		net.WriteFloat(val)
	net.SendToServer()
end

local function Open()
	if IsValid(panel) then panel:Remove() end
	Request()

	local owner = IsOwner()
	local T, UI = PS and PS.Theme, PS and PS.UI
	if not (T and UI) then
		chat.AddText(Color(255, 150, 150), "[PS] PointShop is not loaded; the movement panel needs it.")
		return
	end

	local M = T.Metrics

	-- Row geometry, written down rather than left to chance. Every piece has its own band
	-- and they do not touch:
	--
	--   0..22    label
	--   22..46   the slider bar
	--   46..66   help text
	--
	-- The slider is positioned absolutely instead of docked, and its own label is emptied,
	-- because DNumSlider lays out a label, a bar and a number box by itself and will happily
	-- overlap all three in a row this short. Emptying the label removes it from that
	-- calculation entirely and leaves the bar the full width.
	local ROW_H     = 66
	local LABEL_Y   = 12
	local SLIDER_Y  = 24
	local SLIDER_H  = 22
	local HELP_Y    = 56

	local f = UI.Frame({
		remember = "has_movement",
		title = "Movement",
		w     = 460,
		-- header + status strip + body margins + rows + footer, with a little slack.
		-- Counted rather than eyeballed: the rows dock TOP and the footer docks BOTTOM out
		-- of what is left, so a frame that is short by twenty pixels does not scroll, it
		-- puts the footer through the last row.
		h     = M.HeaderH + 26 + 20 + #FIELDS * (ROW_H + M.Gap) + 10 + 56 + 10,
	})
	panel = f

	-- Status strip under the header, saying whether this client can change anything. A
	-- non-owner can open this and read the values -- the server's jump power is not a
	-- secret, and an admin working out why a map feels wrong should not need owner to look
	-- -- so the panel has to say plainly why the sliders will not move.
	local strip = vgui.Create("DPanel", f)
	strip:Dock(TOP)
	strip:SetTall(26)
	strip.Paint = function(_, w, h)
		T.PaintStatusStrip(w, h, owner and "Live · saved to the server"
			or "Read only · owner required")
	end

	local body = vgui.Create("DPanel", f)
	body:Dock(FILL)
	body:DockMargin(M.Margin, M.Margin, M.Margin, M.Margin)
	body.Paint = function(_, w, h) T.PaintPanelBody(w, h) end

	local rows = {}

	for i, fld in ipairs(FIELDS) do
		local row = vgui.Create("DPanel", body)
		row:Dock(TOP)
		row:SetTall(ROW_H)
		row:DockMargin(M.Margin, i == 1 and M.Margin or 0, M.Margin, M.Gap)

		local sl = vgui.Create("DNumSlider", row)
		sl:SetText("")
		sl:SetMin(fld.min)
		sl:SetMax(fld.max)
		sl:SetDecimals(0)
		sl:SetEnabled(owner)

		-- Absolute, and re-applied on layout so a resize cannot strand it.
		sl.PerformLayout = function(s)
			s:SetPos(M.Margin, SLIDER_Y)
			s:SetSize(row:GetWide() - M.Margin * 2, SLIDER_H)
		end

		row.Paint = function(_, w, h)
			T.PaintRow(row, w, h, i, false)

			draw.SimpleText(fld.label, "PS_DefaultBold", M.Margin, LABEL_Y,
				owner and T.Text or T.ButtonText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(fld.help, "PS_Default", M.Margin, HELP_Y,
				T.ButtonText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		-- Debounced. A slider dragged across its range fires per frame, and every one of
		-- those writes the file and re-applies to every player on the server.
		sl.OnValueChanged = function(s, v)
			if s._quiet or not owner then return end
			timer.Remove("PS_MoveSend_" .. fld.key)
			timer.Create("PS_MoveSend_" .. fld.key, 0.15, 1, function() Send(fld.key, v) end)
		end

		rows[fld.key] = sl
	end

	function f:Refresh()
		for key, sl in pairs(rows) do
			if values[key] then
				sl._quiet = true
				sl:SetValue(values[key])
				sl._quiet = nil
			end
		end
	end

	-- Created after the rows so it takes what is left rather than competing with them:
	-- docking resolves in creation order, so the TOP rows claim their space first and this
	-- gets the bottom of the remainder.
	--
	-- Two drawn lines rather than a wrapped DLabel. DLabel wrap has to guess a height, and
	-- a guess that comes up short clips the second line silently.
	local note = vgui.Create("DPanel", body)
	note:Dock(BOTTOM)
	note:DockMargin(M.Margin, M.Gap, M.Margin, M.Margin)
	note:SetTall(38)
	note.Paint = function(_, w, h)
		draw.SimpleText("Changes apply to everyone immediately and survive a restart.",
			"PS_Default", 0, 10, T.ButtonText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Walk and run speeds are per-team and live in sh_config.lua.",
			"PS_Default", 0, 26, T.ButtonText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	f:Refresh()
end

-- Registers as an owner tool, which puts a button in the PointShop header for the owner and
-- nobody else -- it is not built at all for other players, so there is nothing to find.
hook.Add("PS_CollectOwnerTools", "PS_MovementTool", function(add)
	add("Movement", Open)
end)

concommand.Add("has_movement", Open, nil, "Open the movement tuning panel.")

-- Values are wanted before the panel is first opened, so it populates rather than showing
-- every slider at its minimum for a frame.
hook.Add("InitPostEntity", "PS_MovementRequest", function()
	timer.Simple(2, Request)
end)
