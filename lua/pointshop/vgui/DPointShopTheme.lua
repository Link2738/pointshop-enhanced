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
	StatusBar = "Status strip", Accent = "Accent (borders, stripes, lines)",


	FrameBG     = "Window body",
	PanelBG     = "Panel on the body",
	ListBG      = "Options box",
	ListBorder  = "Options box edge",

	RowBG    = "List row",
	RowAlt   = "List row, alternate",
	RowHover = "List row, hovered",

	AccentFill = "Tool button",
	AccentFillHover = "Tool button, hovered", AccentGloss = "Tool button sheen",
	AccentGlossHover = "Tool button sheen, hovered", AccentGlow = "Tool button glow",
	AccentBorder = "Tool button border",

	ModifyFill  = "Modify / view",
	ModifyFillHover = "Modify / view, hovered", ModifyBorder = "Modify / view border",
	PriceAfford = "Price, affordable", PriceCant = "Price, too costly",
	MenuRowText = "Right-click menu text",
	PointsText  = "Points balance",
	HeaderText  = "Header bar text",
	ButtonText  = "Button text",
	CardText    = "Item name text",

	BadgeGloss = "Item badge sheen",
	IconAdmin  = "Admin-only marker",
	IconGroup  = "Group-restricted marker",

	ScrollTrack     = "Scrollbar track",
	ScrollGrip      = "Scrollbar grip",
	ScrollGripHover = "Scrollbar grip, hovered",

	CategoryFill = "Category, active", CategoryIdleFill = "Category, idle",
	CategoryGloss = "Category sheen", CategoryGlow = "Category glow",
	CategoryBorder = "Category border",
	CategoryIdleFillHover = "Category idle, hovered",
	CategoryIdleGloss = "Category idle sheen",
	CategoryIdleGlossHover = "Category idle sheen, hovered",
	CategoryIdleBorder = "Category idle border",
	CategoryIdleBorderHover = "Category idle border, hovered",

	SelectFill = "Value button, selected", ControlFill = "Value button, idle",
	SelectGloss = "Value button sheen", SelectGlow = "Value button glow",
	SelectBorder = "Value button border",
	ControlFillHover = "Value button idle, hovered", ControlGloss = "Value button idle sheen",
	ControlGlossHover = "Value button idle sheen, hovered",
	ControlBorder = "Value button idle border",
	ControlBorderHover = "Value button idle border, hovered",

	PositiveFill = "Confirm",
	PositiveFillHover = "Confirm, hovered", PositiveGloss = "Confirm sheen",
	PositiveGlossHover = "Confirm sheen, hovered", PositiveGlow = "Confirm glow",
	PositiveBorder = "Confirm border",

	WarningFill = "Reset",
	WarningFillHover = "Reset, hovered", WarningGloss = "Reset sheen",
	WarningGlossHover = "Reset sheen, hovered", WarningBorder = "Reset border",

	NeutralFill = "Dismiss",
	NeutralFillHover = "Dismiss, hovered", NeutralGloss = "Dismiss sheen",
	NeutralGlossHover = "Dismiss sheen, hovered", NeutralBorder = "Dismiss border",

	CardBG      = "Item background", CardBorder  = "Item border",
	CardHover   = "Item border, hovered",
	CardEquipped = "Item, equipped", CardOwned  = "Item, owned",
	CardQueued  = "Item, queued for removal",
	CardCanBuy  = "Badge, affordable", CardCantBuy = "Badge, too costly",
	CardLabelBG = "Item name strip",
CardMenuBG = "Right-click menu",

	Text = "Body text", TextDim = "Labels and status",
	CategoryText = "Category button text",
	Shadow = "Text shadow", ShadowStrong = "Text shadow, strong",
}

local SECTION_OF = {}
local function AssignSection(name, ...)
	for _, k in ipairs({ ... }) do SECTION_OF[k] = name end
end

AssignSection("Surfaces", "CardMenuBG", "StatusBar", "FrameBG", "PanelBG", "ListBG", "ListBorder")

-- What the hue control under the preset moves: the window surfaces and the category strip.
--
-- Not the same set as the Surfaces section, and deliberately not built from it. Two things
-- are out of the group that sit in that section, and one family is in that does not:
--
--   CardMenuBG   a right-click menu is a SUB-PANEL, its own tier, so it does not follow the
--                windows when their hue swings
--   CategoryText the strip's colours move, the writing on them does not -- text has to stay
--                readable against whatever the fill becomes, which is a separate decision
--
-- The category variants are listed alongside their bases rather than left to derive, because
-- the recorded offsets were measured in the old hue and would drag the variants back toward
-- it. SetGroupHue re-measures them after the swing.
local HUE_GROUP = {
	"StatusBar", "FrameBG", "PanelBG", "ListBG", "ListBorder",

	"CategoryFill", "CategoryGloss", "CategoryGlow", "CategoryBorder",
	"CategoryIdleFill", "CategoryIdleFillHover",
	"CategoryIdleGloss", "CategoryIdleGlossHover",
	"CategoryIdleBorder", "CategoryIdleBorderHover",
}
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
	"AccentGlow", "AccentBorder", "ModifyFill", "ModifyFillHover", "ModifyBorder",
	"PositiveFill", "PositiveFillHover", "PositiveGloss", "PositiveGlossHover",
	"PositiveGlow", "PositiveBorder",
	"WarningFill", "WarningFillHover", "WarningGloss", "WarningGlossHover", "WarningBorder",
	"NeutralFill", "NeutralFillHover", "NeutralGloss", "NeutralGlossHover",
	"NeutralBorder")
AssignSection("Items", "BadgeGloss", "IconAdmin", "IconGroup", "CardBG", "CardBorder", "CardHover", "CardEquipped", "CardOwned",
	"CardQueued", "CardCanBuy", "CardCantBuy", "CardLabelBG")
AssignSection("Text", "Text", "HeaderText", "ButtonText", "CategoryText", "CardText", "TextDim", "MenuRowText", "PointsText", "PriceAfford", "PriceCant", "Shadow", "ShadowStrong")

-- Any name used by AssignSection must appear here: BuildShopSections indexes buckets by
-- section name, so one that is missing is a nil table indexed on the first row assigned to it.
local SECTION_ORDER = { "Surfaces", "Accent", "Buttons", "Lists", "Items", "Text", "Other" }

-- The preset row, or nil when nothing has registered one.
--
-- Declared above BuildShopSections because that is where it is called from, and a Lua local
-- is not in scope above its own declaration — the failure is silent, since an undeclared
-- name is just a nil global until something tries to call it.
--
-- Returns nil rather than an empty section when no presets exist: a lone "Default" dropdown
-- that can only ever say Default is worse than no dropdown.
local function PresetSection()
	local T = PS.Theme
	if not istable(T.Presets) then return end

	local options = { { id = "", name = "Default" } }

	-- Custom is a slot rather than a registered preset, so it is added by hand. Offered
	-- only once something has been customised: an empty Custom is not a look, and picking
	-- it would do nothing visible.
	if T.CustomExists and T.CustomExists() then
		options[#options + 1] = { id = "custom", name = "Custom" }
	end
	for id, def in pairs(T.Presets) do
		options[#options + 1] = { id = id, name = (istable(def) and def.name) or id }
	end

	if #options < 2 then return end

	-- Registration order is pairs() order, which is not stable between sessions. Sorted by
	-- name so the list does not reshuffle itself every time the panel opens; Default is
	-- pinned to the top because it is the absence of a choice, not one of the choices.
	table.sort(options, function(a, b)
		if a.id == "" then return true end
		if b.id == "" then return false end
		return a.name < b.name
	end)

	return {
		name = "Look",
		rows = {
			{
				label   = "Preset",
				type    = "choice",
				options = options,
				get     = function() return T.GetPreset() or "" end,
				set     = function(id) T.SetPreset(id ~= "" and id or nil) end,
			},

			-- One control for the whole family, sat between the preset that sets everything
			-- and the swatches that set one each. That is the order of the decisions: pick a
			-- look, swing its hue, then correct anything individually.
			--
			-- Hue only. Every member keeps its own saturation and value, so the relationships
			-- survive the swing -- the options box stays darker than the body, the idle
			-- category button stays a shade off the body it sits on. Picking a dozen greens by
			-- hand and hoping they sit together is the thing this exists to avoid.
			{
				label    = "Base hue",
				type     = "slider",
				min      = 0,
				max      = 359,
				decimals = 0,
				get      = function() return T.GetGroupHue(HUE_GROUP) end,
				set      = function(h) T.SetGroupHue(HUE_GROUP, h) end,
			},
		},
	}
end

-- Walks the palette once and drops every colour into its section. Sorted within a section
-- so the order is stable between sessions rather than following pairs().
local function BuildShopSections()
	local buckets = {}
	for _, name in ipairs(SECTION_ORDER) do buckets[name] = {} end

	for k, v in pairs(PS.Theme) do
		local derived = PS.Theme.Derived[k]

		-- Derived variants are hidden by default. A button's sheen, glow, hovered fill and
		-- border all follow its base, so showing them is six rows describing one decision —
		-- and it lets someone set a fill without its sheen, which is precisely how the
		-- category button ended up black with a blue top half.
		--
		-- Advanced reveals them for anyone who does want the sheen a different hue.
		if istable(v) and v.r ~= nil and v.g ~= nil and v.b ~= nil
			and not EXCLUDE[k] and (PS.Theme.ShowAdvanced or not derived) then

			local bucket = buckets[SECTION_OF[k] or "Other"]
			bucket[#bucket + 1] = {
				label = (derived and "  " or "") .. (LABELS[k] or k),
				type  = "color",
				get   = function() return PS.Theme[k] end,

				-- A base resyncs everything that follows it. A variant edited by hand
				-- re-measures instead, so it becomes the new relationship rather than being
				-- overwritten the next time its base moves.
				onChange = derived
					and function() PS.Theme.RemeasureDerived(k) end
					or  PS.Theme.SyncDerived,
			}
		end
	end

	local out = {}

	-- The preset picker sits above every colour, because it moves all of them. Choosing one
	-- is the coarse decision; the swatches below are the fine adjustment on top of it.
	local presets = PresetSection()
	if presets then out[#out + 1] = presets end

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

	if row.type == "choice" then
		if not isfunction(row.set) then Warn(where .. " choice '" .. row.label .. "' has no set()") return false end
		if not istable(row.options) then
			Warn(where .. " choice '" .. row.label .. "' needs an options list")
			return false
		end
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

	-- isShop travels with the copy because the owner controls need it: publishing a look sends
	-- the SHOP's palette, so those controls belong to the shop's tab and nowhere else. Without
	-- it, an owner editing the gamemode's colours and pressing the button would publish the
	-- shop colours they had not touched and silently drop the ones they had.
	local out = { name = p.name, isShop = p.isShop, sections = {}, previews = {},
		save = p.save, reset = p.reset }

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
		-- The header, not a status strip. This mock stands in for the shop window, and the
		-- shop window has a header bar -- previewing it with the strip meant the bar an owner
		-- was actually recolouring was the one surface the preview did not show.
		PS.Theme.PaintHeader(pw, 28, "Shop")
	end

	-- One active, two idle, so both halves of the selectable archetype are on screen at
	-- once rather than needing a click to compare.
	local names = { "Bear Models", "Accessories", "Trails" }
	local bw = math.floor((w - 40) / 3)
	for i = 1, 3 do
		local btn = vgui.Create("DButton", root)
		btn:SetText(names[i])
		btn:SetFont("PS_CategoryButton")
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

		-- The one provider whose colours a look is made of, and so the only tab the owner's
		-- publish controls belong on.
		isShop   = true,
		sections = BuildShopSections(),
		previews = {
			{ label = "Shop",          build = BuildShopMock },
			{ label = "Customization", build = BuildCustomizationMock },
		},
		-- Colours only. This panel edits colours; the window's size is the layout panel's, and
		-- writing both from here would have this one silently commit a size the player was
		-- still trying out.
		save  = function() PS.Theme.SaveColours() end,
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
	-- The owner controls are a band of their own above the footer, and the window grows to
	-- hold them rather than the list shrinking to make room.
	--
	-- They were placed at a fixed y from the top to begin with, which put them straight
	-- through the middle of the colour list. Everything vertical in this panel is measured
	-- from the bottom for exactly that reason -- the footer sits at h - 44 -- and the owner
	-- block has to be measured the same way or it lands wherever the list happens to be.
	--
	-- Measured from the parts, not picked. PS.UI.Button takes its height from M.ButtonH, which
	-- scales with the screen, so a fixed band is right at 1080p and too short everywhere above
	-- it -- at 2x the button alone is 56 inside a 58 band and runs into the footer.
	local M = PS.Theme.Metrics
	local S = PS.Theme.Scale()

	self.OwnerLabelH = math.Round(16 * S)
	self.OwnerBlockH = (PS_IsItemDefaultOwner and PS_IsItemDefaultOwner(LocalPlayer()))
		and (self.OwnerLabelH + M.Gap + M.ButtonH + M.Gap) or 0

	-- The title strip is sized around the close button rather than the other way round.
	--
	-- It was a flat 35, which is exactly M.IconBtn -- so the button filled the strip edge to
	-- edge with nothing around it and looked wedged in. A gap above and below is the whole
	-- difference, and taking the height from the button means it stays a gap at every scale
	-- instead of closing up as the button grows.
	self.StripH = PS.UI.HeaderH()

	-- The panel itself scales, not just what is in it.
	--
	-- It was capped at a flat 940 while its contents grew with the scale, which is the trap:
	-- at 2x the three footer buttons alone wanted more than 940 and ran under the Close on the
	-- right. A panel that scales its contents has to scale its own frame or it is just a
	-- smaller box with bigger things in it.
	--
	-- Still bounded by the screen. The scale is derived from a window width that is itself
	-- clamped to the screen, so a scale big enough to overflow a monitor cannot arise from a
	-- window that fits on it.
	local w = math.min(math.Round(940 * S), ScrW() - 80)

	-- Grown by whatever the strip gained, so the list below is exactly as tall as it was.
	local h = math.min(math.Round(660 * S) + self.OwnerBlockH + (self.StripH - math.Round(35 * S)),
		ScrH() - 80)

	-- The frame, the strip, the close button, the remembered position and Derma's own titlebar
	-- buttons were all set up by hand here. The close button in particular was a near copy of
	-- the one in the constructor, down to the floor on its y.
	--
	-- One difference is deliberate and visible: the body was PaintPanelBody, so this window
	-- painted itself in the colour meant for a box sitting ON a window. It is a window, so it
	-- gets the window body like every other one.
	PS.UI.SetupFrame(self, {
		title    = "Appearance",
		w        = w,
		h        = h,
		remember = "theme",
	})

	self.Providers = CollectProviders()

	-- Every fixed number in this panel scales with the rest of the UI.
	--
	-- The scale now follows the shop window's size, which a player sets. Leave any of these as
	-- constants and the panel becomes scaled text inside an unscaled layout: at 2x the master
	-- tabs clipped their own labels, the section headings truncated to "T..." and "Ot...", and
	-- the three footer buttons overlapped each other.
	--
	-- Stored on self because BuildFooter and the row builders need the same numbers.
	local S = PS.Theme.Scale()

	local listW = math.Round(300 * S)
	local tabH  = math.Round(30 * S)
	local gap   = math.Round(8 * S)

	self.S      = S
	self.ListW  = listW
	self.Edge   = math.Round(10 * S)   -- panel edge to content
	self.FootH  = math.Round(44 * S)   -- footer band, measured up from the bottom

	-- Below the strip, not at a number that happened to clear it. It was 45 against a strip of
	-- 35, so the 10px gap was only correct while the strip never moved.
	local top    = self.StripH + self.Edge

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
	-- Advanced reveals the derived variants — a button's sheen, glow, hovered fill and
	-- border — for anyone who wants one of them off its base's hue. Off by default, because
	-- for almost everyone they are six rows describing one decision.
	--
	-- Toggling rebuilds from the providers rather than filtering what is already there: the
	-- rows are generated, so the honest way to change what is generated is to generate again.
	local adv = vgui.Create("DCheckBoxLabel", self)
	adv:SetPos(self.Edge + math.Round(2 * S), bodyY + math.Round(2 * S))
	adv:SetSize(listW - self.Edge * 2, math.Round(16 * S))
	adv:SetText("Advanced")
	adv:SetTextColor(PS.Theme.TextDim)
	-- Seeded, so the callback has to ignore the seed. A checkbox fires OnChange from SetValue
	-- a frame later, which here would collect every provider and rebuild the whole list at
	-- the moment the panel opens -- work that has already just been done.
	adv._seeding = true
	adv:SetValue(PS.Theme.ShowAdvanced and true or false)
	timer.Simple(0, function() if IsValid(adv) then adv._seeding = false end end)

	adv.OnChange = function(s, on)
		if s._seeding then return end

		PS.Theme.ShowAdvanced = on
		self.Providers = CollectProviders()
		self:BuildList()
	end

	local listY = bodyY + math.Round(24 * S)

	self.List = vgui.Create("DScrollPanel", self)
	self.List:SetPos(self.Edge, listY)

	-- Stops above the owner block, which sits between it and the footer. Zero for anyone who
	-- is not the owner, so the list is exactly as tall as it always was.
	self.List:SetSize(listW, h - listY - self.FootH - self.Edge - self.OwnerBlockH)

	-- The options column is a panel on the window body, so it is painted as one.
	--
	-- It had no Paint at all, which meant it was transparent and the window body showed
	-- straight through -- every label and swatch floating on the same surface as the
	-- preview beside it, with nothing saying where one ended and the other began. On the
	-- dark theme the swatches carried enough contrast to hide that; on a light one there
	-- is nothing to hide it.
	self.List.Paint = function(_, pw, ph) PS.Theme.PaintListBox(pw, ph) end

	-- Right: the active provider's previews as subtabs.
	local px = listW + self.Edge * 2

	self.Preview = vgui.Create("DPanel", self)
	self.Preview:SetPos(px, bodyY)
	self.Preview:SetSize(w - px - self.Edge, h - bodyY - self.FootH - self.Edge)
	self.Preview.Paint = function() end

	self.SubTabH, self.SubGap = tabH, gap

	-- Footer first: it builds the owner controls, and SelectProvider is what decides whether
	-- they are shown. The other way round they simply did not exist yet on the first call.
	self:BuildFooter(w, h)
	self:SelectProvider(1)
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

	-- The owner's publish controls follow the shop's tab, because publishing sends the shop's
	-- palette. On another provider's tab they would appear to act on what is on screen and
	-- would not: an owner editing the gamemode's colours would publish shop colours they had
	-- not touched and drop the ones they had.
	--
	-- Hidden rather than removed, so switching tabs does not rebuild them, and the band they
	-- sit in stays reserved so the list does not resize under the cursor.
	local showOwner = provider.isShop and true or false
	for _, panel in ipairs(self.OwnerControls or {}) do
		if IsValid(panel) then panel:SetVisible(showOwner) end
	end

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
		hdr:SetFont("PS_DefaultBold")
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
	if row.type == "choice" then return self:AddChoiceRow(row, y, listW) end
	return self:AddColourRow(row, y, listW)
end

-- Called by every path that changes a value, before the change lands.
--
-- Default and Classic are read-only, so an edit to one moves the player to Custom, seeded
-- from what is already on screen. That changes which look is selected, and the picker at the
-- top of this panel is showing the old one until something rebuilds it.
--
-- One function because the three edit paths had drifted: the colour mixer rebuilt, the slider
-- and toggle rows did not, so two of the three moved you to a different look while the
-- dropdown went on naming the one you left. Anything that edits a value calls this and
-- nothing calls BeginEdit directly.
function PANEL:NoteEdit()
	if not (PS.Theme.BeginEdit and PS.Theme.BeginEdit()) then return end

	-- Deferred a frame: this runs from inside a control's own callback, and that control is
	-- about to be destroyed by the rebuild it is asking for.
	timer.Simple(0, function()
		if IsValid(self) then self:BuildList() end
	end)
end

-- Label above, a combo box below. Same two-line shape as the slider and for the same reason:
-- the list column is narrow, and a combo squeezed beside a label truncates its own values.
--
-- Choosing an option rebuilds the list, because a choice can move the very rows being drawn
-- -- picking a preset changes every swatch below it. The rebuild is deferred by a frame so
-- it does not happen inside the combo's own OnSelect, which is still using the panel.
function PANEL:AddChoiceRow(row, y, listW)
	local label = self.List:Add("DLabel")
	label:SetText(row.label)
	label:SetTextColor(PS.Theme.Text)
	label:SetPos(4, y)
	label:SetSize(listW - 20, 16)

	local combo = self.List:Add("DComboBox")
	combo:SetPos(4, y + 18)
	combo:SetSize(listW - 20, 20)
	combo:SetSortItems(false)

	local current = row.get()
	for _, opt in ipairs(row.options) do
		combo:AddChoice(opt.name, opt.id, opt.id == current)
	end

	-- The preset picker is the sharpest case of this: a spurious OnSelect here does not
	-- edit a colour, it switches the whole look.
	combo._seeding = true
	timer.Simple(0, function() if IsValid(combo) then combo._seeding = false end end)

	-- A saved choice whose provider has gone (a preset from an addon since removed) leaves
	-- the combo blank rather than silently showing the wrong name.
	if not combo:GetSelected() then combo:SetValue(current and tostring(current) or "Default") end

	combo.OnSelect = function(s, _, _, data)
		if s._seeding then return end
		local ok, err = pcall(row.set, data)
		if not ok then
			Warn("choice '" .. row.label .. "' set() errored: " .. tostring(err))
			return
		end

		timer.Simple(0, function()
			if IsValid(self) then self:BuildList() end
		end)
	end

	return 42
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
	box._seeding = true
	box:SetValue(row.get() and true or false)
	timer.Simple(0, function() if IsValid(box) then box._seeding = false end end)

	box.OnChange = function(s, v)
		if s._seeding then return end
		self:NoteEdit()

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
	-- Seeding a DNumSlider fires OnValueChanged a frame later, after the callback below is
	-- wired up, so filling the panel in reads as the user having moved every slider on it.
	slider._seeding = true
	slider:SetValue(row.get())
	timer.Simple(0, function() if IsValid(slider) then slider._seeding = false end end)

	slider.Label:SetTextColor(PS.Theme.Text)

	slider.OnValueChanged = function(s, v)
		if s._seeding then return end
		self:NoteEdit()

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

	-- Parented to the panel so it dies with it, then given the standard chrome. The bar is
	-- added to the height rather than taken out of it, so the mixer keeps the room it had.
	local frame = vgui.Create("DFrame", self)
	PS.UI.SetupFrame(frame, {
		title = row.label,
		w     = 260,
		h     = 220 + PS.UI.HeaderH(),
	})

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

		self:NoteEdit()

		-- In place. Every widget style holds a reference to this exact table, so writing
		-- channels is what makes the preview update; replacing it would orphan them.
		col.r, col.g, col.b = newCol.r, newCol.g, newCol.b

		-- Optional per-row hook. The shop uses it to recompute the variants that follow this
		-- colour — a button's sheen, glow, hovered fill and border all move with its base,
		-- and they are stale the instant it changes.
		if isfunction(row.onChange) then
			local ok, err = pcall(row.onChange)
			if not ok then Warn("row '" .. row.label .. "' onChange errored: " .. tostring(err)) end
		end
	end
end

function PANEL:BuildFooter(w, h)
	local S = self.S or 1
	local y = h - self.FootH

	-- Buttons laid out left to right by a running cursor rather than at written-down x
	-- positions.
	--
	-- The positions were 10, 158 and 306 against a width of 140 -- correct at scale 1 and
	-- nowhere else. Scaling only the widths made them overlap; scaling both by hand would be
	-- four numbers that have to agree. A cursor cannot disagree with itself.
	local cursor = self.Edge

	local function Btn(bw, style, label, fn)
		local width = math.Round(bw * S)

		local b = vgui.Create("DButton", self)
		b:SetText("")
		b:SetPos(cursor, y)
		b:SetSize(width, PS.Theme.Metrics.ButtonH)
		b.Paint = function(s, pw, ph)
			PS.Theme.PaintAction(s, pw, ph, PS.Theme.Action[style], label)
		end
		b.DoClick = fn

		cursor = cursor + width + math.Round(8 * S)
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

	local function DoSave()
		local name = ActiveProvider("save", "save")
		notification.AddLegacy((name or "Appearance") .. " settings saved.", NOTIFY_GENERIC, 3)
	end

	Btn(140, "Positive", "Save", function()
		-- There is one Custom slot, and saving writes to it.
		--
		-- Worth a warning only when this session began somewhere else: the player picked
		-- Default or Classic, changed something, and was moved to Custom to hold the change.
		-- Saving then replaces a Custom they built earlier and may not have in mind, and there
		-- is no undo. Saving edits made while already on Custom is just saving.
		local T = PS.Theme
		if T.CustomWasSeeded and T.CustomWasSeeded() and T.CustomExists and T.CustomExists() then
			PS.UI.Confirm({
				title = "Overwrite",
				text  = "This replaces your saved Custom appearance.",
				yes   = "Overwrite",
				onYes = DoSave,
			})
			return
		end

		DoSave()
	end)

	-- The window's size, for everyone rather than just the owner.
	--
	-- It lives beside the colours because it is the same kind of choice: how the shop looks to
	-- the person looking at it. A player on a 4:3 laptop and one on an ultrawide do not want
	-- the same window, and neither of them is wrong.
	if PS.OpenShopLayout then
		Btn(140, "Neutral", "Window size", function()
			PS.OpenShopLayout()
		end)
	end

	Btn(140, "Warning", "Reset to Default", function()
		ActiveProvider("reset", "reset")

		-- Sliders and checkboxes hold their own copy of the value, so they do not notice a
		-- reset that happened underneath them. Rebuilding the list is the honest fix; the
		-- alternative is every provider having to know to push values back into controls it
		-- never saw.
		self:BuildList()
	end)

	-- Owner controls. Absent for everyone else, not disabled.
	--
	-- This panel is a player's own appearance, so anything that changes what OTHER people see
	-- is built only for the client that passes the owner check. The server re-checks the same
	-- gate when the message arrives, so this decides what is drawn and nothing more.
	--
	-- These two replace a pair of console commands: one that made edits land on the selected
	-- look instead of diverting to Custom, and one that printed the result for hand-copying
	-- into a source file. A look's colours are owner data, and the addon already keeps owner
	-- data in data/ behind a gated message.
	if PS_IsItemDefaultOwner and PS_IsItemDefaultOwner(LocalPlayer()) then
		local T = PS.Theme

		-- Measured up from the footer, the way everything else vertical in this panel is.
		local blockY = y - self.OwnerBlockH

		local edit = vgui.Create("DCheckBoxLabel", self)
		edit:SetPos(10, blockY)
		edit:SetSize((self.ListW or 300) - 20, self.OwnerLabelH)
		edit:SetText("Edit this look for everyone")
		edit:SetTextColor(PS.Theme.GoldLabel)

		edit._seeding = true
		edit:SetValue(T.EditingLook and true or false)
		timer.Simple(0, function() if IsValid(edit) then edit._seeding = false end end)

		edit.OnChange = function(s, on)
			if s._seeding then return end

			-- Only changes where an edit LANDS. Turning it on publishes nothing, and turning
			-- it off leaves whatever was already changed exactly where it is.
			T.EditingLook = on
		end

		local publish = PS.UI.Button(self, "Save for everyone", "Gold", function()
			if not T.EditingLook then
				PS.UI.Confirm({
					title = "Blocked",
					text  = "Tick 'Edit this look for everyone' first.",
					yes   = "OK",
				})
				return
			end

			PS.UI.Confirm({
				title = "Publish",
				text  = "Save this look's colours for every player?",
				yes   = "Publish",
				onYes = function()
					T.PublishLook()
					notification.AddLegacy("Look published to the server.", NOTIFY_GENERIC, 3)
				end,
			})
		end)
		publish:SetPos(10, blockY + self.OwnerLabelH + PS.Theme.Metrics.Gap)
		publish:SetWide((self.ListW or 300) - 20)

		-- SelectProvider shows and hides these as the master tab changes.
		self.OwnerControls = { edit, publish }
	end

	-- A Close button sat on the right here. The X in the header does the same thing, and every
	-- other window in the addon closes that way and only that way.
end

vgui.Register("DPointShopTheme", PANEL, "DFrame")
