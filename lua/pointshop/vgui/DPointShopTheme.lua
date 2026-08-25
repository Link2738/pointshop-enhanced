--[[
	DPointShopTheme
	Colour editor for the shop's UI, with a live preview beside it.

	The preview is built from real panels calling the same PS.Theme painters the shop uses,
	not from a hand-drawn imitation. That is deliberate: a mockup that redrew the widgets
	itself would drift the first time either side changed, and the drift would be invisible
	until someone noticed the preview was lying about the thing it exists to show.

	It also means hover states are real. The mock widgets are DButtons, so moving the cursor
	over one animates exactly as the shop's would.
]]

local PANEL = {}

-- ============================================================================
-- WHAT IS EDITABLE
--
-- Ordered, grouped, and labelled for a person rather than for the code. Each row names a
-- key on PS.Theme; the editor writes channel values into that Color in place, never
-- replacing the table, because the widget styles hold references to it.
-- ============================================================================

local SECTIONS = {
	{
		name = "Surfaces",
		rows = {
			{ key = "PanelBG",   label = "Panel background" },
			{ key = "StatusBar", label = "Status strip" },
		},
	},
	{
		name = "Accent",
		rows = {
			{ key = "Accent",         label = "Accent line" },
			{ key = "CategoryFill",   label = "Category, active" },
			{ key = "CategoryBorder", label = "Category, active border" },
			{ key = "SelectFill",     label = "Value button, selected" },
			{ key = "SelectBorder",   label = "Value button, border" },
			{ key = "ControlFill",    label = "Value button, idle" },
			{ key = "ControlBorder",  label = "Value button, idle border" },
		},
	},
	{
		name = "Buttons",
		rows = {
			{ key = "PositiveFill",   label = "Confirm" },
			{ key = "PositiveBorder", label = "Confirm border" },
			{ key = "WarningFill",    label = "Reset" },
			{ key = "WarningBorder",  label = "Reset border" },
			{ key = "GoldFill",       label = "Owner action" },
			{ key = "GoldBorder",     label = "Owner action border" },
			{ key = "DangerFill",     label = "Destructive" },
			{ key = "DangerBorder",   label = "Destructive border" },
			{ key = "NeutralFill",    label = "Dismiss" },
			{ key = "NeutralBorder",  label = "Dismiss border" },
		},
	},
	{
		name = "Text",
		rows = {
			{ key = "Text",      label = "Button text" },
			{ key = "TextDim",   label = "Labels and status" },
			{ key = "GoldText",  label = "Owner action text" },
			{ key = "DangerText", label = "Destructive text" },
		},
	},
}

-- ============================================================================
-- PREVIEW
-- ============================================================================

-- Builds the mock shop window: header strip, a row of category buttons with one active,
-- and a grid of item cards in the states that have distinct borders.
local function BuildShopMock(parent, x, y, w)
	local root = vgui.Create("DPanel", parent)
	root:SetPos(x, y)
	root:SetSize(w, 200)
	root.Paint = function(_, pw, ph)
		PS.Theme.PaintPanelBody(pw, ph)
		PS.Theme.PaintStatusStrip(pw, 28, "Shop")
	end

	-- One active, two idle, so both halves of the selectable archetype are on screen at
	-- once rather than needing a click to compare.
	local names = { "Bear Models", "Accessories", "Trails" }
	local bw = math.floor((w - 40) / 3)
	for i = 1, 3 do
		local btn = vgui.Create("DButton", root)
		btn:SetText(names[i])
		btn:SetFont("PS_CategoryButton")
		btn:SetTextColor(PS.Theme.Text)
		btn:SetSize(bw, 30)
		btn:SetPos(10 + (i - 1) * (bw + 5), 38)
		btn.DoClick = function() root._activeCat = i end
		btn.Paint = function(s, pw, ph)
			PS.Theme.PaintSelectable(s, pw, ph, (root._activeCat or 1) == i, PS.Theme.Selectable.Category)
		end
	end

	root._activeCat = 1

	-- Item cards, one per border state the real card can be in. Affordability is not one of
	-- them - that shows in the badge, while the border shows ownership - so it is not
	-- previewed here.
	--
	-- Fixed states rather than real inventory, so this renders with the shop closed and
	-- nothing owned.
	local states = {
		{ label = "Equipped", state = "Equipped" },
		{ label = "Owned",    state = "Owned" },
		{ label = "Queued",   state = "Queued" },
		{ label = "Hover me", state = nil },
	}

	local cw = math.floor((w - 50) / 4)
	for i = 1, 4 do
		-- DButton rather than DPanel: the last card has no state, so its border is the
		-- hover one, and that only animates on something that takes mouse input.
		local card = vgui.Create("DButton", root)
		card:SetText("")
		card:SetSize(cw, 100)
		card:SetPos(10 + (i - 1) * (cw + 10), 82)
		card.Paint = function(s, pw, ph)
			PS.Theme.PaintItemCard(s, pw, ph, states[i].state, states[i].label)
		end
	end

	return root
end

-- Builds the mock customization panel: status strip, a row of value buttons, and one of
-- each action button so every Action style is visible together.
local function BuildCustomizationMock(parent, x, y, w)
	local root = vgui.Create("DPanel", parent)
	root:SetPos(x, y)
	root:SetSize(w, 250)
	root.Paint = function(_, pw, ph)
		PS.Theme.PaintPanelBody(pw, ph)
		PS.Theme.PaintStatusStrip(pw, 28, "Preview enabled. Use controls to customize.")
	end

	root._value = 0

	local bw = math.floor((w - 30) / 4)
	for i = 0, 3 do
		local btn = vgui.Create("DButton", root)
		btn:SetText(tostring(i))
		btn:SetTextColor(PS.Theme.Text)
		btn:SetSize(bw, 26)
		btn:SetPos(10 + i * (bw + 5), 40)
		btn.DoClick = function() root._value = i end
		btn.Paint = function(s, pw, ph)
			PS.Theme.PaintSelectable(s, pw, ph, root._value == i, PS.Theme.Selectable.Value)
		end
	end

	local actions = {
		{ style = "Positive", label = "Save & Close",     h = 28 },
		{ style = "Warning",  label = "Reset Values",     h = 24 },
		{ style = "Gold",     label = "Save as Default",  h = 24 },
		{ style = "Danger",   label = "Clear Default",    h = 24 },
		{ style = "Neutral",  label = "Discard Changes",  h = 24 },
	}

	local ay = 78
	for i = 1, #actions do
		local a = actions[i]
		local btn = vgui.Create("DButton", root)
		btn:SetText("")
		btn:SetSize(w - 20, a.h)
		btn:SetPos(10, ay)
		btn.Paint = function(s, pw, ph)
			PS.Theme.PaintAction(s, pw, ph, PS.Theme.Action[a.style], a.label)
		end
		ay = ay + a.h + 4
	end

	return root
end

-- ============================================================================
-- PANEL
-- ============================================================================

function PANEL:Init()
	local w = math.min(940, ScrW() - 80)
	local h = math.min(660, ScrH() - 80)

	self:SetSize(w, h)
	self:Center()
	self:SetTitle("")
	self:SetDraggable(true)
	self:SetSizable(false)
	self:MakePopup()

	self.Paint = function(_, pw, ph)
		PS.Theme.PaintPanelBody(pw, ph)
		PS.Theme.PaintStatusStrip(pw, 35, "Appearance - changes preview instantly")
	end

	local listW = 300

	-- Left: the swatch list.
	self.List = vgui.Create("DScrollPanel", self)
	self.List:SetPos(10, 45)
	self.List:SetSize(listW, h - 100)

	self.Rows = {}
	local y = 0

	for _, section in ipairs(SECTIONS) do
		local hdr = self.List:Add("DLabel")
		hdr:SetText(section.name)
		hdr:SetFont("DermaDefaultBold")
		hdr:SetTextColor(PS.Theme.TextDim)
		hdr:SetPos(4, y)
		hdr:SizeToContents()
		y = y + 20

		for _, row in ipairs(section.rows) do
			self:AddRow(row, y, listW)
			y = y + 26
		end

		y = y + 8
	end

	-- Right: the preview.
	local px = listW + 20
	local pw = w - px - 10

	self.Preview = vgui.Create("DPanel", self)
	self.Preview:SetPos(px, 45)
	self.Preview:SetSize(pw, h - 100)
	self.Preview.Paint = function() end

	BuildShopMock(self.Preview, 0, 0, pw)
	BuildCustomizationMock(self.Preview, 0, 210, pw)

	self:BuildFooter(w, h)
end

-- One swatch row: label, a colour button, and a mixer that opens on click.
function PANEL:AddRow(row, y, listW)
	local col = PS.Theme[row.key]
	if not col then return end

	local label = self.List:Add("DLabel")
	label:SetText(row.label)
	label:SetTextColor(PS.Theme.Text)
	label:SetPos(4, y + 4)
	label:SetSize(listW - 90, 16)

	local swatch = self.List:Add("DButton")
	swatch:SetText("")
	swatch:SetPos(listW - 80, y)
	swatch:SetSize(60, 22)
	swatch.Paint = function(s, w, h)
		draw.RoundedBox(3, 0, 0, w, h, col)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	swatch.DoClick = function() self:OpenMixer(row, col) end

	self.Rows[row.key] = swatch
end

-- Mixer popup for one entry.
--
-- DColorMixer:SetColor fires ValueChanged more than once - the colour cube re-fires a frame
-- later with a value derived from its knob position, which lands as a second, different
-- write. The customization panel hit this and solved it with a seeding window; the same
-- guard applies here, or seeding the mixer would immediately overwrite the colour it was
-- seeded from.
function PANEL:OpenMixer(row, col)
	local frame = vgui.Create("DFrame", self)
	frame:SetSize(260, 220)
	frame:SetTitle(row.label)
	frame:Center()
	frame:MakePopup()

	local mixer = vgui.Create("DColorMixer", frame)
	mixer:Dock(FILL)
	mixer:DockMargin(5, 5, 5, 5)
	mixer:SetPalette(true)
	mixer:SetAlphaBar(false)
	mixer:SetWangs(true)

	frame._seeding = true
	mixer:SetColor(Color(col.r, col.g, col.b, col.a))
	timer.Simple(0, function()
		if IsValid(frame) then frame._seeding = false end
	end)

	mixer.ValueChanged = function(_, newCol)
		if frame._seeding then return end

		-- In place. Every widget style holds a reference to this exact table, so writing
		-- channels is what makes the preview update; replacing it would orphan them.
		col.r, col.g, col.b = newCol.r, newCol.g, newCol.b
	end
end

function PANEL:BuildFooter(w, h)
	local y = h - 44

	local function Btn(x, bw, style, label, fn)
		local b = vgui.Create("DButton", self)
		b:SetText("")
		b:SetPos(x, y)
		b:SetSize(bw, 28)
		b.Paint = function(s, pw, ph)
			PS.Theme.PaintAction(s, pw, ph, PS.Theme.Action[style], label)
		end
		b.DoClick = fn
		return b
	end

	Btn(10, 140, "Positive", "Save", function()
		PS.Theme.Save()
		notification.AddLegacy("Appearance saved.", NOTIFY_GENERIC, 3)
	end)

	Btn(158, 140, "Warning", "Reset to Default", function()
		PS.Theme.ResetToDefaults()
	end)

	-- Owner control, gated on the same check the item defaults use. Hidden rather than
	-- disabled for anyone else; the server rejects the message regardless.
	if PS_IsItemDefaultOwner and PS_IsItemDefaultOwner(LocalPlayer()) then
		Btn(306, 180, "Gold", "Save as Server Default", function()
			net.Start("PS_Theme_SetDefault")
				net.WriteString(util.TableToJSON(PS.Theme.Serialise()))
			net.SendToServer()
			notification.AddLegacy("Saved as server default.", NOTIFY_GENERIC, 3)
		end)
	end

	Btn(w - 110, 100, "Neutral", "Close", function()
		self:Close()
	end)
end

vgui.Register("DPointShopTheme", PANEL, "DFrame")
