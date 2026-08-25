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
			{ key = "NeutralFill",    label = "Dismiss" },
			{ key = "NeutralBorder",  label = "Dismiss border" },
		},
	},
	{
		name = "Text",
		rows = {
			{ key = "Text",    label = "Button text" },
			{ key = "TextDim", label = "Labels and status" },
		},
	},
}

-- ============================================================================
-- PREVIEW
-- ============================================================================

-- Builds the mock shop window: header strip, a row of category buttons with one active,
-- and a grid of item cards in the states that have distinct borders.
local function BuildShopMock(parent, w, h)
	local root = vgui.Create("DPanel", parent)
	root:SetPos(0, 0)
	root:SetSize(w, h)
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

	-- Capped rather than simply filling the pane. A card stretched to full height stops
	-- looking like an item card, and the point is to show what one looks like — the leftover
	-- space below is panel background, which is itself a colour being previewed.
	local cw = math.floor((w - 50) / 4)
	local ch = math.Clamp(h - 92, 100, 190)

	for i = 1, 4 do
		-- DButton rather than DPanel: the last card has no state, so its border is the
		-- hover one, and that only animates on something that takes mouse input.
		local card = vgui.Create("DButton", root)
		card:SetText("")
		card:SetSize(cw, ch)
		card:SetPos(10 + (i - 1) * (cw + 10), 82)
		card.Paint = function(s, pw, ph)
			PS.Theme.PaintItemCard(s, pw, ph, states[i].state, states[i].label)
		end
	end

	return root
end

-- Builds the mock customization panel: status strip, a row of value buttons, and one of
-- each action button so every Action style is visible together.
local function BuildCustomizationMock(parent, w, h)
	local root = vgui.Create("DPanel", parent)
	root:SetPos(0, 0)
	root:SetSize(w, h)
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

	-- The server-default controls are deliberately absent. That panel is owner-only and off
	-- limits — it is not previewed here and nothing in this editor themes it.
	local actions = {
		{ style = "Positive", label = "Save & Close",    h = 28 },
		{ style = "Warning",  label = "Reset Values",    h = 24 },
		{ style = "Neutral",  label = "Discard Changes", h = 24 },
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

	-- Right: the preview, one tab per surface.
	--
	-- Tabs rather than both stacked: each mock then gets the full height, so it can be laid
	-- out at something close to the proportions of the panel it stands for instead of being
	-- squashed into half the pane.
	local px = listW + 20
	local pw = w - px - 10
	local ph = h - 100

	self.Preview = vgui.Create("DPanel", self)
	self.Preview:SetPos(px, 45)
	self.Preview:SetSize(pw, ph)
	self.Preview.Paint = function() end

	local tabH, gap = 30, 8

	-- The tab strip paints with Selectable.Category, the same painter the shop's own
	-- category buttons use. Not just for consistency: it means the tabs are themselves part
	-- of the preview, so a change to the category colours is visible immediately in the
	-- control the cursor is already on.
	local body = vgui.Create("DPanel", self.Preview)
	body:SetPos(0, tabH + gap)
	body:SetSize(pw, ph - tabH - gap)
	body.Paint = function() end

	local tabs = {
		{ label = "Shop",          build = BuildShopMock },
		{ label = "Customization", build = BuildCustomizationMock },
	}

	self._tabPages = {}
	local tabW = math.floor((pw - gap) / #tabs)

	for i, t in ipairs(tabs) do
		local page = t.build(body, pw, ph - tabH - gap)
		page:SetVisible(i == 1)
		self._tabPages[i] = page

		local btn = vgui.Create("DButton", self.Preview)
		btn:SetText(t.label)
		btn:SetFont("PS_CategoryButton")
		btn:SetTextColor(PS.Theme.Text)
		btn:SetSize(tabW, tabH)
		btn:SetPos((i - 1) * (tabW + gap), 0)
		btn.DoClick = function()
			self._activeTab = i
			for n, p in ipairs(self._tabPages) do
				p:SetVisible(n == i)
			end
		end
		btn.Paint = function(s, bw, bh)
			PS.Theme.PaintSelectable(s, bw, bh, (self._activeTab or 1) == i, PS.Theme.Selectable.Category)
		end
	end

	self._activeTab = 1

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

	-- No server-default control here. This panel is a player's own appearance and nothing
	-- else; anything that changes what OTHER people see belongs on an owner surface, not
	-- one every player opens.

	Btn(w - 110, 100, "Neutral", "Close", function()
		self:Close()
	end)
end

vgui.Register("DPointShopTheme", PANEL, "DFrame")
