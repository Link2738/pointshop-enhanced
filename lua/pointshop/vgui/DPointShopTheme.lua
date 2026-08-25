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
-- The row list is GENERATED from the palette rather than hand-written. That is deliberate.
--
-- A hand-written subset is how the active category button ended up with a blue top half
-- after its fill was set to black: the sheen it draws over the top half is its own palette
-- entry, and that entry was not on the list. Same for every hover variant, every glow, and
-- the whole item card. Anything not listed was simply unreachable, and there was nothing to
-- make that visible short of noticing a colour that would not change.
--
-- Generating means an entry cannot go missing. LABELS supplies readable names and SECTION_OF
-- the grouping; anything with neither still appears, under "Other", rather than vanishing.
-- ============================================================================

-- Owner-only. The server-default panel is not this editor's to touch, so its colours are
-- not offered - see the note in the customization mock below.
local EXCLUDE = {
	GoldFill = true, GoldFillHover = true, GoldBorder = true,
	GoldText = true, GoldDivider = true, GoldLabel = true,
	DangerFill = true, DangerFillHover = true, DangerBorder = true, DangerText = true,
}

local LABELS = {
	PanelBG = "Panel background", StatusBar = "Status strip", Accent = "Accent line",

	CategoryFill   = "Category, active",        CategoryGloss  = "Category, active sheen",
	CategoryGlow   = "Category, active glow",   CategoryBorder = "Category, active border",
	CategoryIdleFill        = "Category, idle",        CategoryIdleFillHover   = "Category, idle hovered",
	CategoryIdleGloss       = "Category, idle sheen",  CategoryIdleGlossHover  = "Category, idle sheen hovered",
	CategoryIdleBorder      = "Category, idle border", CategoryIdleBorderHover = "Category, idle border hovered",

	SelectFill  = "Value button, selected",       SelectGloss  = "Value button, selected sheen",
	SelectGlow  = "Value button, selected glow",  SelectBorder = "Value button, selected border",
	ControlFill        = "Value button, idle",        ControlFillHover   = "Value button, idle hovered",
	ControlGloss       = "Value button, idle sheen",  ControlGlossHover  = "Value button, idle sheen hovered",
	ControlBorder      = "Value button, idle border", ControlBorderHover = "Value button, idle border hovered",

	PositiveFill  = "Confirm",       PositiveFillHover  = "Confirm hovered",
	PositiveGloss = "Confirm sheen", PositiveGlossHover = "Confirm sheen hovered",
	PositiveGlow  = "Confirm glow",  PositiveBorder     = "Confirm border",

	WarningFill  = "Reset",       WarningFillHover  = "Reset hovered",
	WarningGloss = "Reset sheen", WarningGlossHover = "Reset sheen hovered",
	WarningBorder = "Reset border",

	NeutralFill  = "Dismiss",       NeutralFillHover  = "Dismiss hovered",
	NeutralGloss = "Dismiss sheen", NeutralGlossHover = "Dismiss sheen hovered",
	NeutralBorder = "Dismiss border", NeutralText = "Dismiss text",

	CardBG      = "Item background", CardBorder  = "Item border",
	CardHover   = "Item border, hovered",
	CardEquipped = "Item, equipped", CardOwned  = "Item, owned",
	CardQueued  = "Item, queued for removal",
	CardCanBuy  = "Badge, affordable", CardCantBuy = "Badge, too costly",
	CardLabelBG = "Item name strip",
	CardPanelBG = "Dialog background", CardMenuBG = "Right-click menu",

	Text = "Button text", TextDim = "Labels and status",
	Shadow = "Text shadow", ShadowStrong = "Text shadow, strong",
}

local SECTION_OF = {}
local function AssignSection(name, ...)
	for _, k in ipairs({ ... }) do SECTION_OF[k] = name end
end

AssignSection("Surfaces", "PanelBG", "StatusBar", "CardPanelBG", "CardMenuBG")
AssignSection("Accent", "Accent",
	"CategoryFill", "CategoryGloss", "CategoryGlow", "CategoryBorder",
	"CategoryIdleFill", "CategoryIdleFillHover", "CategoryIdleGloss",
	"CategoryIdleGlossHover", "CategoryIdleBorder", "CategoryIdleBorderHover",
	"SelectFill", "SelectGloss", "SelectGlow", "SelectBorder",
	"ControlFill", "ControlFillHover", "ControlGloss", "ControlGlossHover",
	"ControlBorder", "ControlBorderHover")
AssignSection("Buttons",
	"PositiveFill", "PositiveFillHover", "PositiveGloss", "PositiveGlossHover",
	"PositiveGlow", "PositiveBorder",
	"WarningFill", "WarningFillHover", "WarningGloss", "WarningGlossHover", "WarningBorder",
	"NeutralFill", "NeutralFillHover", "NeutralGloss", "NeutralGlossHover",
	"NeutralBorder", "NeutralText")
AssignSection("Items", "CardBG", "CardBorder", "CardHover", "CardEquipped", "CardOwned",
	"CardQueued", "CardCanBuy", "CardCantBuy", "CardLabelBG")
AssignSection("Text", "Text", "TextDim", "Shadow", "ShadowStrong")

local SECTION_ORDER = { "Surfaces", "Accent", "Buttons", "Items", "Text", "Other" }

-- Walks the palette once and drops every colour into its section. Sorted within a section
-- so the order is stable between sessions rather than following pairs().
local function BuildSections()
	local buckets = {}
	for _, name in ipairs(SECTION_ORDER) do buckets[name] = {} end

	for k, v in pairs(PS.Theme) do
		if istable(v) and v.r ~= nil and v.g ~= nil and v.b ~= nil and not EXCLUDE[k] then
			local bucket = buckets[SECTION_OF[k] or "Other"]
			bucket[#bucket + 1] = { key = k, label = LABELS[k] or k }
		end
	end

	local out = {}
	for _, name in ipairs(SECTION_ORDER) do
		local rows = buckets[name]
		if #rows > 0 then
			table.sort(rows, function(a, b) return a.label < b.label end)
			out[#out + 1] = { name = name, rows = rows }
		end
	end

	return out
end

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

	for _, section in ipairs(BuildSections()) do
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
