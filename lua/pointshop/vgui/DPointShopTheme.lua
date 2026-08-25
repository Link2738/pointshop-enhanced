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
	StatusBar = "Status strip", Accent = "Accent line",

	MenuCategoryBG = "Category strip background",

	FrameBG     = "Window body",
	FrameBorder = "Window border",
	HeaderBG    = "Window header bar",
	HeaderRule  = "Header stripe",

	RowBG    = "List row",
	RowAlt   = "List row, alternate",
	RowHover = "List row, hovered",

	AccentFill       = "Tool button",
	AccentFillHover  = "Tool button, hovered",
	AccentGloss      = "Tool button sheen",
	AccentGlossHover = "Tool button sheen, hovered",
	AccentGlow       = "Tool button glow",
	AccentBorder     = "Tool button border",

	ModifyFill  = "Modify entry",
	MenuRowText = "Right-click menu text",
	PointsText  = "Points balance",

	BadgeGloss = "Item badge sheen",
	IconAdmin  = "Admin-only marker",
	IconGroup  = "Group-restricted marker",

	ScrollTrack     = "Scrollbar track",
	ScrollGrip      = "Scrollbar grip",
	ScrollGripHover = "Scrollbar grip, hovered",

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
CardMenuBG = "Right-click menu",

	Text = "Button text", TextDim = "Labels and status",
	Shadow = "Text shadow", ShadowStrong = "Text shadow, strong",
}

local SECTION_OF = {}
local function AssignSection(name, ...)
	for _, k in ipairs({ ... }) do SECTION_OF[k] = name end
end

AssignSection("Surfaces", "StatusBar", "CardMenuBG", "MenuCategoryBG", "FrameBG", "FrameBorder", "HeaderBG", "HeaderRule")
AssignSection("Lists", "RowBG", "RowAlt", "RowHover",
	"ScrollTrack", "ScrollGrip", "ScrollGripHover")
AssignSection("Accent", "Accent",
	"CategoryFill", "CategoryGloss", "CategoryGlow", "CategoryBorder",
	"CategoryIdleFill", "CategoryIdleFillHover", "CategoryIdleGloss",
	"CategoryIdleGlossHover", "CategoryIdleBorder", "CategoryIdleBorderHover",
	"SelectFill", "SelectGloss", "SelectGlow", "SelectBorder",
	"ControlFill", "ControlFillHover", "ControlGloss", "ControlGlossHover",
	"ControlBorder", "ControlBorderHover")
AssignSection("Buttons",
	"AccentFill", "AccentFillHover", "AccentGloss", "AccentGlossHover",
	"AccentGlow", "AccentBorder", "ModifyFill",
	"PositiveFill", "PositiveFillHover", "PositiveGloss", "PositiveGlossHover",
	"PositiveGlow", "PositiveBorder",
	"WarningFill", "WarningFillHover", "WarningGloss", "WarningGlossHover", "WarningBorder",
	"NeutralFill", "NeutralFillHover", "NeutralGloss", "NeutralGlossHover",
	"NeutralBorder", "NeutralText")
AssignSection("Items", "BadgeGloss", "IconAdmin", "IconGroup", "CardBG", "CardBorder", "CardHover", "CardEquipped", "CardOwned",
	"CardQueued", "CardCanBuy", "CardCantBuy", "CardLabelBG")
AssignSection("Text", "Text", "TextDim", "MenuRowText", "PointsText", "Shadow", "ShadowStrong")

-- Any name used by AssignSection must appear here: BuildShopSections indexes buckets by
-- section name, so one that is missing is a nil table indexed on the first row assigned to it.
local SECTION_ORDER = { "Surfaces", "Accent", "Buttons", "Lists", "Items", "Text", "Other" }

-- Walks the palette once and drops every colour into its section. Sorted within a section
-- so the order is stable between sessions rather than following pairs().
local function BuildShopSections()
	local buckets = {}
	for _, name in ipairs(SECTION_ORDER) do buckets[name] = {} end

	for k, v in pairs(PS.Theme) do
		if istable(v) and v.r ~= nil and v.g ~= nil and v.b ~= nil and not EXCLUDE[k] then
			local bucket = buckets[SECTION_OF[k] or "Other"]
			bucket[#bucket + 1] = {
				label = LABELS[k] or k,
				type  = "color",
				get   = function() return PS.Theme[k] end,
			}
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
-- PROVIDER CONTRACT
--
-- This panel is not the shop's private settings screen. It is a host: anything installed
-- alongside the shop can register appearance sections and get a live-previewed colour
-- editor without writing one. The shop registers itself through the same door as everyone
-- else, so there is no privileged path that could quietly diverge from the public one.
--
--     hook.Add("PS_CollectAppearanceProviders", "MyAddon", function(add)
--         add({
--             name     = "My Addon",
--             sections = { { name = "Colours", rows = { ... } } },
--             previews = { { label = "Preview", build = function(parent, w, h) end } },
--             save     = function() end,
--             reset    = function() end,
--         })
--     end)
--
-- Rows are one of:
--
--     { label = "…", type = "color",  get = function() return <Color> end }
--     { label = "…", type = "slider", get = function() return <number> end,
--       set = function(n) end, min = <n>, max = <n>, decimals = <n> }
--
-- A colour row's get() must return the LIVE Color table, not a copy. The editor writes
-- channels into it in place, and that is what makes a change show up on the next frame
-- without anything having to be told about it.
--
-- Everything below is validated rather than trusted. This contract is public, so a provider
-- may be third-party code with a typo in it, and one bad provider must not cost the player
-- their whole appearance menu — it gets skipped, with a console line saying which and why.
-- ============================================================================

local function Warn(msg)
	ErrorNoHalt("[PointShop] Appearance provider ignored: " .. msg .. "\n")
end

local function ValidRow(row, where)
	if not istable(row) then return false end
	if not isstring(row.label) then Warn(where .. " has a row with no label") return false end
	if not isfunction(row.get) then Warn(where .. " row '" .. row.label .. "' has no get()") return false end

	if row.type == "color" then
		local c = row.get()
		if not (istable(c) and c.r and c.g and c.b) then
			Warn(where .. " row '" .. row.label .. "' get() did not return a Color")
			return false
		end
		return true
	end

	if row.type == "slider" then
		if not isfunction(row.set) then Warn(where .. " slider '" .. row.label .. "' has no set()") return false end
		if not (isnumber(row.min) and isnumber(row.max)) then
			Warn(where .. " slider '" .. row.label .. "' needs numeric min and max")
			return false
		end
		return true
	end

	if row.type == "toggle" then
		if not isfunction(row.set) then Warn(where .. " toggle '" .. row.label .. "' has no set()") return false end
		return true
	end

	Warn(where .. " row '" .. row.label .. "' has unknown type " .. tostring(row.type))
	return false
end

-- Returns a cleaned copy, or nil if the provider is unusable. Rows that fail are dropped
-- individually so one bad entry does not discard a provider's whole section.
local function Validate(p)
	if not istable(p) then Warn("not a table") return end
	if not isstring(p.name) then Warn("no name") return end
	if not istable(p.sections) then Warn(p.name .. " has no sections") return end

	local out = { name = p.name, sections = {}, previews = {}, save = p.save, reset = p.reset }

	for _, section in ipairs(p.sections) do
		if istable(section) and istable(section.rows) then
			local rows = {}
			for _, row in ipairs(section.rows) do
				if ValidRow(row, p.name) then rows[#rows + 1] = row end
			end
			if #rows > 0 then
				out.sections[#out.sections + 1] = { name = section.name or p.name, rows = rows }
			end
		end
	end

	if #out.sections == 0 then Warn(p.name .. " contributed no usable rows") return end

	for _, pv in ipairs(p.previews or {}) do
		if istable(pv) and isfunction(pv.build) then
			out.previews[#out.previews + 1] = { label = pv.label or p.name, build = pv.build }
		end
	end

	return out
end

-- ShopProvider and CollectProviders live below the preview builders, which they reference —
-- a Lua local is not in scope above its own declaration.

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
-- PROVIDER COLLECTION
-- ============================================================================

-- The shop's own provider, registered through the public door like any other.
local function ShopProvider()
	return {
		-- "PointShop", not "Shop": this is the master tab, and one of its own subtabs is
		-- already called Shop. Naming both the same would read as a tab containing itself.
		name     = "PointShop",
		sections = BuildShopSections(),
		previews = {
			{ label = "Shop",          build = BuildShopMock },
			{ label = "Customization", build = BuildCustomizationMock },
		},
		save  = function() PS.Theme.Save() end,
		reset = function() PS.Theme.ResetToDefaults() end,
	}
end

-- Collected fresh every time the panel opens, so an addon that loaded late still appears,
-- and a provider is free to vary its rows by whatever state it likes.
--
-- Wrapped in pcall: a provider that errors while BUILDING its section list would otherwise
-- take the hook down and every provider after it with no indication why.
local function CollectProviders()
	local raw = { ShopProvider() }

	hook.Run("PS_CollectAppearanceProviders", function(p) raw[#raw + 1] = p end)

	local out = {}
	for _, p in ipairs(raw) do
		local ok, cleaned = pcall(Validate, p)
		if not ok then
			Warn("a provider errored while being validated: " .. tostring(cleaned))
		elseif cleaned then
			out[#out + 1] = cleaned
		end
	end

	return out
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

	self.Providers = CollectProviders()

	local listW  = 300
	local tabH   = 30
	local gap    = 8
	local top    = 45

	-- Master tab strip: one per provider. Picking one swaps BOTH panes, so the two halves
	-- always describe the same thing — the failure this replaced was a single flat list of
	-- every provider's rows next to a preview of one of them.
	self.MasterY = top
	self:BuildMasterTabs(w, tabH, gap)

	local bodyY = top + tabH + gap

	-- Left: the swatch list, scoped to the active provider.
	--
	-- Scoped to the MASTER tab, not the subtab. A provider's subtabs are sibling views of one
	-- palette — the shop's Shop and Customization surfaces share most of their colours — so
	-- splitting the list between them would just list the same rows twice.
	self.List = vgui.Create("DScrollPanel", self)
	self.List:SetPos(10, bodyY)
	self.List:SetSize(listW, h - bodyY - 55)
	self.ListW = listW

	-- Right: the active provider's previews as subtabs.
	local px = listW + 20

	self.Preview = vgui.Create("DPanel", self)
	self.Preview:SetPos(px, bodyY)
	self.Preview:SetSize(w - px - 10, h - bodyY - 55)
	self.Preview.Paint = function() end

	self.SubTabH, self.SubGap = tabH, gap

	self:SelectProvider(1)
	self:BuildFooter(w, h)
end

-- One button per provider, across the top.
function PANEL:BuildMasterTabs(w, tabH, gap)
	self._masterBtns = {}

	local n = #self.Providers
	if n == 0 then return end

	local tabW = math.floor((w - 20 - gap * (n - 1)) / n)

	for i, provider in ipairs(self.Providers) do
		local btn = vgui.Create("DButton", self)
		btn:SetText(provider.name)
		btn:SetFont("PS_CategoryButton")
		btn:SetTextColor(PS.Theme.Text)
		btn:SetSize(tabW, tabH)
		btn:SetPos(10 + (i - 1) * (tabW + gap), self.MasterY)
		btn.DoClick = function() self:SelectProvider(i) end
		btn.Paint = function(s, bw, bh)
			PS.Theme.PaintSelectable(s, bw, bh, self._activeProvider == i, PS.Theme.Selectable.Category)
		end

		self._masterBtns[i] = btn
	end
end

-- Switches both panes to a provider: its rows on the left, its previews as subtabs.
function PANEL:SelectProvider(index)
	local provider = self.Providers[index]
	if not provider then return end

	self._activeProvider = index

	self:BuildList()
	self:BuildSubTabs(provider)
end

-- Preview subtabs for one provider.
--
-- Pages are built first and only the ones that succeed get a tab. A provider's preview
-- builder is third-party code running inside our panel, so it is pcall'd: if it throws, its
-- tab is dropped and the rest of the menu still opens. Two passes rather than skipping
-- mid-loop keeps the page list contiguous — a hole in it would end the ipairs that drives
-- tab switching, and every tab after the failed one would go dead with nothing to say why.
function PANEL:BuildSubTabs(provider)
	self.Preview:Clear()

	local pw, ph = self.Preview:GetSize()
	local tabH, gap = self.SubTabH, self.SubGap

	local body = vgui.Create("DPanel", self.Preview)
	body:SetPos(0, tabH + gap)
	body:SetSize(pw, ph - tabH - gap)
	body.Paint = function() end

	self._tabPages = {}
	local built = {}

	for _, t in ipairs(provider.previews) do
		local ok, page = pcall(t.build, body, pw, ph - tabH - gap)
		if ok and IsValid(page) then
			built[#built + 1] = { label = t.label, page = page }
			self._tabPages[#built] = page
		else
			Warn("preview '" .. tostring(t.label) .. "' failed to build: " .. tostring(page))
			if IsValid(page) then page:Remove() end
		end
	end

	self._activeTab = 1

	local tabW = math.floor((pw - gap * math.max(#built - 1, 0)) / math.max(#built, 1))

	for i, b in ipairs(built) do
		b.page:SetVisible(i == 1)

		local btn = vgui.Create("DButton", self.Preview)
		btn:SetText(b.label)
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
			PS.Theme.PaintSelectable(s, bw, bh, self._activeTab == i, PS.Theme.Selectable.Category)
		end
	end
end

-- Fills the left column from the active provider.
--
-- Separate from Init because Reset has to rebuild it: a slider holds its own copy of the
-- value and does not notice one changing underneath it.
function PANEL:BuildList()
	local provider = self.Providers[self._activeProvider or 1]
	if not provider then return end

	local listW = self.ListW
	self.List:Clear()

	local y = 0

	-- No provider prefix on the headers. The list only ever shows one provider now, so
	-- "PointShop / Surfaces" would be repeating what the master tab already says.
	for _, section in ipairs(provider.sections) do
		local hdr = self.List:Add("DLabel")
		hdr:SetText(section.name)
		hdr:SetFont("DermaDefaultBold")
		hdr:SetTextColor(PS.Theme.TextDim)
		hdr:SetPos(4, y)
		hdr:SizeToContents()
		y = y + 20

		for _, row in ipairs(section.rows) do
			y = y + self:AddRow(row, y, listW)
		end

		y = y + 8
	end
end

-- Renders one row and returns the vertical space it used, so a taller control does not need
-- the caller to know which type it was.
function PANEL:AddRow(row, y, listW)
	if row.type == "slider" then return self:AddSliderRow(row, y, listW) end
	if row.type == "toggle" then return self:AddToggleRow(row, y, listW) end
	return self:AddColourRow(row, y, listW)
end

-- Label, a swatch of the current colour, and a mixer that opens on click.
function PANEL:AddColourRow(row, y, listW)
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
		-- Read through get() every frame rather than caching. A provider may change the
		-- colour from outside this panel, and the swatch should not be the one thing on
		-- screen still showing the old value.
		draw.RoundedBox(3, 0, 0, w, h, row.get())
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	swatch.DoClick = function() self:OpenMixer(row) end

	return 26
end

-- Label and a checkbox, on one line — a toggle needs no travel, so it fits where a slider
-- would not.
function PANEL:AddToggleRow(row, y, listW)
	local box = self.List:Add("DCheckBoxLabel")
	box:SetPos(4, y + 4)
	box:SetSize(listW - 30, 16)
	box:SetText(row.label)
	box:SetTextColor(PS.Theme.Text)
	box:SetValue(row.get() and true or false)

	box.OnChange = function(_, v)
		local ok, err = pcall(row.set, v and true or false)
		if not ok then Warn("toggle '" .. row.label .. "' set() errored: " .. tostring(err)) end
	end

	return 24
end

-- Label above, slider below. Two lines because the list column is 300px and a slider
-- squeezed alongside a label has almost no travel left to be precise with.
function PANEL:AddSliderRow(row, y, listW)
	local slider = self.List:Add("DNumSlider")
	slider:SetPos(4, y)
	slider:SetSize(listW - 20, 34)
	slider:SetText(row.label)
	slider:SetMin(row.min)
	slider:SetMax(row.max)
	slider:SetDecimals(row.decimals or 2)
	slider:SetValue(row.get())
	slider.Label:SetTextColor(PS.Theme.Text)

	slider.OnValueChanged = function(_, v)
		-- Guarded: a provider's set() is third-party code firing on every drag frame, and an
		-- error there would otherwise spam and leave the slider half-applied.
		local ok, err = pcall(row.set, v)
		if not ok then Warn("slider '" .. row.label .. "' set() errored: " .. tostring(err)) end
	end

	return 38
end

-- Mixer popup for one entry.
--
-- DColorMixer:SetColor fires ValueChanged more than once - the colour cube re-fires a frame
-- later with a value derived from its knob position, which lands as a second, different
-- write. The customization panel hit this and solved it with a seeding window; the same
-- guard applies here, or seeding the mixer would immediately overwrite the colour it was
-- seeded from.
function PANEL:OpenMixer(row)
	local col = row.get()
	if not istable(col) then return end

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

	-- Both scoped to the master tab, not fanned out across every provider.
	--
	-- Reset especially: fanning it out means someone undoing a shop colour also wipes their
	-- aura settings, which they have no reason to expect from a button on a tab that is not
	-- showing those. Save follows the same rule so the two do not disagree about what "this"
	-- means — a Save that wrote more than the Reset would undo is its own trap.
	local function ActiveProvider(what, fn)
		local provider = self.Providers[self._activeProvider or 1]
		if not provider then return end

		local f = provider[fn]
		if not isfunction(f) then return end

		local ok, err = pcall(f)
		if not ok then
			Warn(provider.name .. " failed to " .. what .. ": " .. tostring(err))
		end

		return provider.name
	end

	Btn(10, 140, "Positive", "Save", function()
		local name = ActiveProvider("save", "save")
		notification.AddLegacy((name or "Appearance") .. " settings saved.", NOTIFY_GENERIC, 3)
	end)

	Btn(158, 140, "Warning", "Reset to Default", function()
		ActiveProvider("reset", "reset")

		-- Sliders and checkboxes hold their own copy of the value, so they do not notice a
		-- reset that happened underneath them. Rebuilding the list is the honest fix; the
		-- alternative is every provider having to know to push values back into controls it
		-- never saw.
		self:BuildList()
	end)

	-- No server-default control here. This panel is a player's own appearance and nothing
	-- else; anything that changes what OTHER people see belongs on an owner surface, not
	-- one every player opens.

	Btn(w - 110, 100, "Neutral", "Close", function()
		self:Close()
	end)
end

vgui.Register("DPointShopTheme", PANEL, "DFrame")
