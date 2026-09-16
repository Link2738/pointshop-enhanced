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

				-- Written to disk as soon as it is picked, not on Save.
				--
				-- Which look you are on is a choice in its own right, separate from the
				-- colours in it: picking Classic and closing the panel without saving anything
				-- still means you chose Classic, and the shop should open there next time.
				-- Leaving it to Save meant browsing looks and closing lost the one you settled
				-- on, and you came back to whatever you had before.
				set     = function(id)
					local to = id ~= "" and id or nil
					
					local pnl = nil
					for _, child in ipairs(vgui.GetWorldPanel():GetChildren()) do
						if child.ClassName == "DPointShopTheme" then
							pnl = child
							break
						end
					end
					
					if IsValid(pnl) then
						pnl:PromptSizing(function(ignoreSizing)
							T.SetPreset(to, ignoreSizing)
							T.SavePreset(to)
							if IsValid(pnl) then pnl:BuildList() end
						end)
					else
						T.SetPreset(to, false)
						T.SavePreset(to)
					end
				end,
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
				enabled  = function() return T.HueLinked end,
				get      = function() return T.GetGroupHue(HUE_GROUP) end,
				set      = function(h) T.SetGroupHue(HUE_GROUP, h) end,
			},

			-- Structure rather than colour, and the thing that most makes Classic look like
			-- PS1: its active tab is not filled, it is underlined, with the text weight
			-- carrying the selection instead. It was reachable only by choosing Classic --
			-- a look you could not have on any other palette.
			{
				label = "Underline the active category",
				type  = "toggle",
				get   = function() return T.GetStyle("Category", "activeMode") == "underline" end,
				set   = function(on)
					T.SetStyle("Category", "activeMode", on and "underline" or nil)
				end,
			},
			{
				label = "Ghost standard close buttons",
				type  = "toggle",
				get   = function() return T.GetStyle("Frame", "ghostClose") == true end,
				set   = function(on)
					T.SetStyle("Frame", "ghostClose", on and true or nil)
				end,
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

function PANEL:SaveProviders()
	local ok, err = pcall(function()
		local provider = self.Providers[self._activeProvider or 1]
		if provider and isfunction(provider.save) then provider.save() end
	end)
	if not ok then Warn("provider save failed: " .. tostring(err)) end
end

function PANEL:PromptSaveLook()
	local T = PS.Theme
	local M = PS.Theme.Metrics
	local S = PS.Theme.Scale()

	local frame = PS.UI.Frame({
		title = "Save",
		w     = math.Round(320 * S),
		h     = math.Round(150 * S) + PS.UI.HeaderH(),
	})

	local label = vgui.Create("DLabel", frame)
	label:SetText("Name")
	label:SetTextColor(PS.Theme.Text)
	label:Dock(TOP)
	label:DockMargin(M.Margin, M.Gap, M.Margin, 0)
	label:SizeToContents()

	local entry = vgui.Create("DTextEntry", frame)
	entry:Dock(TOP)
	entry:DockMargin(M.Margin, M.Gap, M.Margin, 0)

	local row = vgui.Create("DPanel", frame)
	row:Dock(BOTTOM)
	row:DockMargin(M.Margin, M.Margin, M.Margin, M.Margin)
	row:SetTall(M.ButtonH)
	row.Paint = function() end

	local function Commit()
		local name = string.Trim(entry:GetValue())
		if name == "" then return end

		local id = T.LookID(name)
		if T.Presets[id] then
			PS.UI.Confirm({
				title = "Overwrite",
				text  = 'Replace "' .. name .. '"?',
				yes   = "Overwrite",
				onYes = function()
					local def  = T.Presets[id]
					local hadM = def and istable(def.metrics) or false

					T.SaveLook(name, hadM)
					self:SaveProviders()
					self:BuildList()
					frame:Close()
					notification.AddLegacy('Saved "' .. name .. '".', NOTIFY_GENERIC, 3)
				end,
			})
			return
		end

		T.SaveLook(name, false)
		self:SaveProviders()
		self:BuildList()
		frame:Close()
		notification.AddLegacy('Saved "' .. name .. '".', NOTIFY_GENERIC, 3)
	end

	local cancel = PS.UI.Button(row, "Cancel", "Neutral", function() frame:Close() end)
	cancel:Dock(RIGHT)
	cancel:DockMargin(M.Gap, 0, 0, 0)
	cancel:SetWide(math.Round(100 * S))

	local save = PS.UI.Button(row, "Save", "Positive", Commit)
	save:Dock(FILL)

	entry.OnEnter = Commit
	entry:RequestFocus()
end

function PANEL:Init()
	local M = PS.Theme.Metrics
	local S = PS.Theme.Scale()

	local w = math.min(math.Round(940 * S), ScrW() - 80)
	local h = math.min(math.Round(660 * S), ScrH() - 80)

	PS.UI.SetupFrame(self, {
		title    = "Appearance",
		w        = w,
		h        = h,
		remember = "theme",
	})

	self._activeProvider = 1
	self.Providers = CollectProviders()

	self.Master = Framework.UI.HBox(self)
	self.Master:Dock(FILL)
	self.Master:DockMargin(M.Margin, M.Margin, M.Margin, M.Margin)
	self.Master:SetGap(M.Margin)

	-- Left Column (Settings)
	self.SettingsCol = Framework.UI.VBox(self.Master)
	self.Master:AddNode(self.SettingsCol, 0, math.Round(350 * S))

	-- Right Column (Preview)
	self.PreviewCol = Framework.UI.VBox(self.Master)
	self.Master:AddNode(self.PreviewCol, 1)

	self.SubTabH = math.Round(30 * S)
	self.SubGap = math.Round(8 * S)

	self.MasterTabRow = Framework.UI.HBox(self.SettingsCol)
	self.SettingsCol:AddNode(self.MasterTabRow, 0, self.SubTabH)

	local mSpacer = vgui.Create("DPanel", self.SettingsCol)
	mSpacer.Paint = function() end
	self.SettingsCol:AddNode(mSpacer, 0, self.SubGap)

	self.PreviewSubTabs = Framework.UI.HBox(self.PreviewCol)
	self.PreviewCol:AddNode(self.PreviewSubTabs, 0, self.SubTabH)

	local pSpacer = vgui.Create("DPanel", self.PreviewCol)
	pSpacer.Paint = function() end
	self.PreviewCol:AddNode(pSpacer, 0, self.SubGap)

	self.PreviewBody = vgui.Create("DPanel", self.PreviewCol)
	self.PreviewBody.Paint = function() end
	self.PreviewCol:AddNode(self.PreviewBody, 1)

	self:BuildMasterTabs()
	
	-- Advanced / Base Hue Row
	self.OptionsRow = Framework.UI.HBox(self.SettingsCol)
	self.OptionsRow:SetGap(M.Gap)
	self.SettingsCol:AddNode(self.OptionsRow, 0, math.Round(20 * S))
	self.SettingsCol:AddNode(vgui.Create("DPanel", self.SettingsCol), 0, math.Round(4 * S)).Paint = function() end -- spacer
	
	local adv = vgui.Create("DCheckBoxLabel", self.OptionsRow)
	adv:SetText("Advanced")
	adv:SetTextColor(PS.Theme.TextDim)
	adv._seeding = true
	adv:SetValue(PS.Theme.ShowAdvanced and true or false)
	timer.Simple(0, function() if IsValid(adv) then adv._seeding = false end end)
	adv.OnChange = function(s, on)
		if s._seeding then return end
		PS.Theme.ShowAdvanced = on
		self.Providers = CollectProviders()
		self:BuildList()
	end
	self.OptionsRow:AddNode(adv, 1)

	local hue = vgui.Create("DCheckBoxLabel", self.OptionsRow)
	hue:SetText("Base hue")
	hue:SetTextColor(PS.Theme.TextDim)
	hue._seeding = true
	hue:SetValue(PS.Theme.HueLinked and true or false)
	timer.Simple(0, function() if IsValid(hue) then hue._seeding = false end end)
	hue.OnChange = function(s, on)
		if s._seeding then return end
		PS.Theme.HueLinked = on
		self:BuildList()
	end
	self.OptionsRow:AddNode(hue, 1)

	-- Settings List
	self.SettingsList = PS.UI.Scroll(self.SettingsCol)
	self.SettingsCol:AddNode(self.SettingsList, 1)
	self.SettingsList.Paint = function(_, pw, ph) PS.Theme.PaintListBox(pw, ph) end

	-- Inner VBox for the scroll panel
	self.ListInner = Framework.UI.VBox(self.SettingsList)
	self.ListInner:Dock(TOP)

	self.OwnerLabelH = math.Round(16 * S)
	self.OwnerBlockH = (PS_IsItemDefaultOwner and PS_IsItemDefaultOwner(LocalPlayer()))
		and (self.OwnerLabelH + M.Gap + M.ButtonH + M.Gap) or 0

	if self.OwnerBlockH > 0 then
		self.OwnerCol = Framework.UI.VBox(self.SettingsCol)
		self.OwnerCol:SetGap(M.Gap)
		self.SettingsCol:AddNode(self.OwnerCol, 0, self.OwnerBlockH)
	end

	-- Footer Row
	self.FooterCol = Framework.UI.VBox(self.SettingsCol)
	self.SettingsCol:AddNode(self.FooterCol, 0, M.ButtonH)

	-- Deferred one frame: the flex layout has not run yet, so PreviewBody is 0×0. The mock
	-- builders parent into it and would be clipped to nothing. By next frame the VBox has
	-- sized every node and GetWide/GetTall return real values.
	timer.Simple(0, function()
		if IsValid(self) then self:SelectProvider(1) end
	end)
end

function PANEL:BuildMasterTabs()
	local S = PS.Theme.Scale()
	local gap = math.Round(8 * S)
	self.MasterTabRow:Clear()
	self.MasterTabRow:SetGap(gap)

	for i, p in ipairs(self.Providers) do
		local btn = vgui.Create("DButton", self.MasterTabRow)
		btn:SetText(p.name)
		btn:SetFont("PS_CategoryButton")
		btn.DoClick = function()
			self:SelectProvider(i)
		end
		btn.Paint = function(s, pw, ph)
			PS.Theme.PaintSelectable(s, pw, ph, self._activeProvider == i, PS.Theme.Selectable.Category)
		end
		self.MasterTabRow:AddNode(btn, 1)
	end
end

function PANEL:SelectProvider(index)
	self._activeProvider = index

	local provider = self.Providers[index]
	self:BuildSubTabs(provider)
	self:BuildList()
	if self.BuildFooter then self:BuildFooter() end

	if IsValid(self.OwnerCol) then
		self.OwnerCol:Clear()
		if provider.isShop and PS_IsItemDefaultOwner and PS_IsItemDefaultOwner(LocalPlayer()) then
			local chk = vgui.Create("DCheckBoxLabel", self.OwnerCol)
			chk:SetText("Edit this look for everyone")
			chk:SetTextColor(PS.Theme.GoldLabel)
			chk._seeding = true
			chk:SetValue(PS.Theme.EditingLook and true or false)
			timer.Simple(0, function() if IsValid(chk) then chk._seeding = false end end)
			chk.OnChange = function(s, on)
				if s._seeding then return end
				PS.Theme.EditingLook = on
			end
			self.OwnerCol:AddNode(chk, 0, self.OwnerLabelH)

			local pub = vgui.Create("DButton", self.OwnerCol)
			pub:SetText("")
			pub.Paint = function(s, pw, ph)
				PS.Theme.PaintAction(s, pw, ph, PS.Theme.Action["Gold"], "Save for everyone")
			end
			pub.DoClick = function()
				if not PS.Theme.EditingLook then
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
						PS.Theme.PublishLook()
						notification.AddLegacy("Look published to the server.", NOTIFY_GENERIC, 3)
					end,
				})
			end
			self.OwnerCol:AddNode(pub, 0, PS.Theme.Metrics.ButtonH)
		end
	end
end

function PANEL:BuildSubTabs(provider)
	self.PreviewSubTabs:Clear()
	self.PreviewSubTabs:SetGap(self.SubGap)
	
	if IsValid(self.PreviewBody) then
		self.PreviewBody:Clear()
	end

	self._tabPages = {}
	local built = {}

	local pw = self.PreviewCol:GetWide()
	local ph = self.PreviewCol:GetTall() - self.SubTabH - self.SubGap
	if pw == 0 then
		local S = PS.Theme.Scale()
		local w = math.min(math.Round(940 * S), ScrW() - 80)
		pw = w - math.Round(350 * S) - (PS.Theme.Metrics.Margin * 3)
		ph = math.min(math.Round(660 * S), ScrH() - 80) - PS.UI.HeaderH() - (PS.Theme.Metrics.Margin * 2) - self.SubTabH - self.SubGap
	end

	for _, t in ipairs(provider.previews or {}) do
		local ok, page = pcall(t.build, self.PreviewBody, pw, ph)
		if ok and IsValid(page) then
			built[#built + 1] = { label = t.label, page = page }
			self._tabPages[#built] = page
		else
			if IsValid(page) then page:Remove() end
		end
	end

	self._activeTab = 1
	for i, b in ipairs(built) do
		b.page:SetVisible(i == 1)

		local btn = vgui.Create("DButton", self.PreviewSubTabs)
		btn:SetText(b.label)
		btn:SetFont("PS_CategoryButton")
		btn.DoClick = function()
			self._activeTab = i
			for n, p in ipairs(self._tabPages) do
				p:SetVisible(n == i)
			end
		end
		btn.Paint = function(s, bw, bh)
			PS.Theme.PaintSelectable(s, bw, bh, self._activeTab == i, PS.Theme.Selectable.Category)
		end
		self.PreviewSubTabs:AddNode(btn, 1)
	end
end

function PANEL:BuildList()
	local provider = self.Providers[self._activeProvider or 1]
	if not provider then return end

	if self.FooterCol then self:BuildFooter() end
	self.ListInner:Clear()
	self.ListInner:SetTall(0)

	for _, section in ipairs(provider.sections) do
		local hdr = vgui.Create("DLabel", self.ListInner)
		hdr:SetText(section.name)
		hdr:SetFont("PS_DefaultBold")
		hdr:SetTextColor(PS.Theme.TextDim)
		hdr:DockMargin(4, 8, 4, 0)
		self.ListInner:AddNode(hdr, 0, 20)

		for _, row in ipairs(section.rows) do
			self:AddRow(row)
		end
	end
	
	self.ListInner:InvalidateLayout(true)
end

function PANEL:AddRow(row)
	if row.type == "slider" then return self:AddSliderRow(row) end
	if row.type == "toggle" then return self:AddToggleRow(row) end
	if row.type == "choice" then return self:AddChoiceRow(row) end
	return self:AddColourRow(row)
end

function PANEL:NoteEdit()
	if not (PS.Theme.BeginEdit and PS.Theme.BeginEdit()) then return end

	timer.Simple(0, function()
		if IsValid(self) then self:BuildList() end
	end)
end

function PANEL:AddChoiceRow(row)
	local p = vgui.Create("DPanel", self.ListInner)
	p.Paint = function() end
	self.ListInner:AddNode(p, 0, 42)

	local label = vgui.Create("DLabel", p)
	label:SetText(row.label)
	label:SetTextColor(PS.Theme.Text)
	label:Dock(TOP)
	label:DockMargin(4, 0, 4, 0)
	label:SetTall(16)

	local combo = vgui.Create("DComboBox", p)
	combo:Dock(TOP)
	combo:DockMargin(4, 2, 20, 0)
	combo:SetTall(20)
	combo:SetSortItems(false)

	local current = row.get()
	for _, opt in ipairs(row.options) do
		combo:AddChoice(opt.name, opt.id, opt.id == current)
	end

	combo._seeding = true
	timer.Simple(0, function() if IsValid(combo) then combo._seeding = false end end)

	if not combo:GetSelected() then combo:SetValue(current and tostring(current) or "Default") end

	combo.OnSelect = function(s, _, _, data)
		if s._seeding then return end
		local ok, err = pcall(row.set, data)
		if not ok then
			Warn("choice '" .. row.label .. "' set() errored: " .. tostring(err))
		end
	end
end

function PANEL:AddColourRow(row)
	local p = vgui.Create("DPanel", self.ListInner)
	p.Paint = function() end
	self.ListInner:AddNode(p, 0, 26)

	local label = vgui.Create("DLabel", p)
	label:SetText(row.label)
	label:SetTextColor(PS.Theme.Text)
	label:Dock(LEFT)
	label:DockMargin(4, 4, 0, 4)
	label:SetWide(180)

	local swatch = vgui.Create("DButton", p)
	swatch:SetText("")
	swatch:Dock(RIGHT)
	swatch:DockMargin(0, 2, 20, 2)
	swatch:SetWide(60)
	swatch.Paint = function(s, w, h)
		draw.RoundedBox(3, 0, 0, w, h, row.get())
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	swatch.DoClick = function() self:OpenMixer(row) end
end

function PANEL:AddToggleRow(row)
	local p = vgui.Create("DPanel", self.ListInner)
	p.Paint = function() end
	self.ListInner:AddNode(p, 0, 24)

	local box = vgui.Create("DCheckBoxLabel", p)
	box:Dock(FILL)
	box:DockMargin(4, 4, 20, 4)
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
end

function PANEL:AddSliderRow(row)
	local p = vgui.Create("DPanel", self.ListInner)
	p.Paint = function() end
	self.ListInner:AddNode(p, 0, 38)

	local slider = vgui.Create("DNumSlider", p)
	slider:Dock(FILL)
	slider:DockMargin(4, 0, 20, 0)
	slider:SetText(row.label)
	slider:SetMin(row.min)
	slider:SetMax(row.max)
	slider:SetDecimals(row.decimals or 2)
	slider.Label:SetTextColor(PS.Theme.Text)

	slider._seeding = true
	slider:SetValue(row.get())
	timer.Simple(0, function() if IsValid(slider) then slider._seeding = false end end)

	-- Optional, so a row that says nothing is live — which is every row but the base hue.
	-- Greyed rather than removed: a control that vanishes when off cannot be found to turn on.
	if row.enabled and not row.enabled() then
		slider:SetEnabled(false)
		slider.Label:SetTextColor(PS.Theme.TextDim)
	end

	slider.OnValueChanged = function(s, v)
		if s._seeding then return end
		self:NoteEdit()

		local ok, err = pcall(row.set, v)
		if not ok then Warn("slider '" .. row.label .. "' set() errored: " .. tostring(err)) end
	end
end

function PANEL:OpenMixer(row)
	local col = row.get()
	if not istable(col) then return end

	if IsValid(self._mixerPanel) then self._mixerPanel:Remove() end

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

	mixer.ValueChanged = function(_, newcol)
		if frame._seeding then return end
		self:NoteEdit()

		-- In place. Every widget style holds a reference to this exact table, so writing
		-- channels is what makes the preview update; replacing it would orphan them.
		col.r, col.g, col.b = newcol.r, newcol.g, newcol.b

		-- Optional per-row hook. The shop uses it to recompute the variants that follow
		-- this colour — a button's sheen, glow, hovered fill and border all move with
		-- its base, and they are stale the instant it changes.
		if isfunction(row.onChange) then
			local ok, err = pcall(row.onChange)
			if not ok then Warn("row '" .. row.label .. "' onChange errored: " .. tostring(err)) end
		end
	end
	
	self._mixerPanel = frame
end

function PANEL:BuildFooter()
	if not IsValid(self.FooterCol) then return end
	self.FooterCol:Clear()

	local M = PS.Theme.Metrics
	local provider = self.Providers[self._activeProvider or 1]
	
	local actions = Framework.UI.HBox(self.FooterCol)
	actions:SetGap(M.Gap)
	self.FooterCol:AddNode(actions, 0, M.ButtonH)

	local function MakeBtn(label, style, fn, weight)
		local b = vgui.Create("DButton", actions)
		b:SetText("")
		b.Paint = function(s, pw, ph)
			PS.Theme.PaintAction(s, pw, ph, PS.Theme.Action[style], label)
		end
		b.DoClick = fn
		actions:AddNode(b, weight)
	end

	-- Save
	MakeBtn("Save", "Positive", function()
		local T = PS.Theme
		local from = T.SeededFrom and T.SeededFrom()
		local here = T.GetPreset and T.GetPreset()

		local onLook = (T.IsLook and T.IsLook(from) and from)
			or (T.IsLook and T.IsLook(here) and here)
			or nil

		if onLook then
			local name = T.LookName(onLook)
			PS.UI.Confirm({
				title = "Overwrite",
				text  = 'Replace "' .. name .. '" with what you are looking at?',
				yes   = "Overwrite",
				onYes = function()
					local def  = T.Presets[onLook]
					local hadM = def and istable(def.metrics) or false

					T.SaveLook(name, hadM)
					self:SaveProviders()
					self:BuildList()
					notification.AddLegacy('Saved "' .. name .. '".', NOTIFY_GENERIC, 3)
				end,
			})
			return
		end
		self:PromptSaveLook()
	end, 1)

	-- Delete
	local here = PS.Theme.GetPreset and PS.Theme.GetPreset()
	if PS.Theme.IsLook and PS.Theme.IsLook(here) then
		MakeBtn("Delete", "Danger", function()
			local name = PS.Theme.LookName(here)
			PS.UI.Confirm({
				title = "Delete",
				text  = 'Delete "' .. name .. '"?',
				yes   = "Delete",
				onYes = function()
					PS.Theme.DeleteLook(name)
					self:BuildList()
					notification.AddLegacy('Deleted "' .. name .. '".', NOTIFY_GENERIC, 3)
				end,
			})
		end, 1)
	end

	-- Reset
	MakeBtn("Reset", "Warning", function()
		if not provider then return end
		PS.UI.Confirm({
			title = "Reset",
			text  = "Reset " .. (provider.name or "these") .. " settings?",
			yes   = "Reset",
			onYes = function()
				if provider.reset and isfunction(provider.reset) then
					pcall(provider.reset)
					self:BuildList()
				end
			end,
		})
	end, 1)
end

function PANEL:PromptSizing(callback)
	local M = PS.Theme.Metrics
	local S = PS.Theme.Scale()

	local blur = vgui.Create("DPanel", self)
	blur:SetZPos(32767)
	
	local box = vgui.Create("DPanel", blur)
	box:SetSize(math.Round(420 * S), math.Round(180 * S))

	-- Only cover the body beneath the header, leaving the close button exposed
	blur.PerformLayout = function(s, w, h)
		local bar = self.BarH and self:BarH() or 32
		s:SetPos(0, bar)
		s:SetSize(self:GetWide(), self:GetTall() - bar)
		if IsValid(box) then
			box:Center()
		end
	end
	
	-- Darken the rest of the appearance panel
	blur.Paint = function(s, w, h)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(0, 0, w, h)
	end
	
	box.Paint = function(s, w, h)
		PS.Theme.PaintFrame(w, h)
	end
	
	local title = vgui.Create("DLabel", box)
	title:Dock(TOP)
	title:DockMargin(M.Margin, M.Margin, M.Margin, 0)
	title:SetFont("PS_Heading")
	title:SetTextColor(PS.Theme.Text)
	title:SetText("Apply Layout & Sizing?")
	title:SetContentAlignment(5)
	title:SizeToContents()
	
	local sub = vgui.Create("DLabel", box)
	sub:Dock(TOP)
	sub:DockMargin(M.Margin, M.Gap, M.Margin, 0)
	sub:SetFont("PS_Default")
	sub:SetTextColor(PS.Theme.TextDim)
	sub:SetText("This preset contains custom dimensions.\nDo you want to apply them, or keep your current layout?")
	sub:SetContentAlignment(5)
	sub:SizeToContents()
	
	local btnWrap = vgui.Create("DPanel", box)
	btnWrap:Dock(BOTTOM)
	btnWrap:DockMargin(M.Margin, 0, M.Margin, M.Margin)
	btnWrap:SetTall(M.ButtonH)
	btnWrap.Paint = nil
	
	local chosen = false

	local btnColors = PS.UI.Button(btnWrap, "Colors Only", "Neutral", function()
		chosen = true
		blur:Remove()
		callback(true)
	end)
	btnColors:Dock(LEFT)
	btnColors:SetWide(math.Round(190 * S))
	
	local btnAll = PS.UI.Button(btnWrap, "Colors & Layout", "Accent", function()
		chosen = true
		blur:Remove()
		callback(false)
	end)
	btnAll:Dock(RIGHT)
	btnAll:SetWide(math.Round(190 * S))

	-- If the blur panel is removed without a choice (e.g. they closed the window or we added a cancel button),
	-- force a rebuild so the dropdown natively reverts to the active preset.
	blur.OnRemove = function()
		if not chosen then
			timer.Simple(0, function() if IsValid(self) then self:BuildList() end end)
		end
	end
end

vgui.Register("DPointShopTheme", PANEL, "DFrame")
