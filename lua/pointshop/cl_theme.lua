--[[
	PointShop - UI Palette

	Every colour the shop's panels paint with. Deliberately shop-only: the gamemode HUD
	keeps its own palette, so the shop stays usable as a standalone addon on a gamemode
	that has never heard of Bear Hunt.

	WHAT BELONGS HERE

	Chrome only - colours that describe the panel. Backgrounds, borders, button fills,
	label text.

	Colours that carry a VALUE never belong here. The colour mixers in the customization
	panel, a player's chosen playermodel colour, an item's stored default: those are data
	that happens to be a Color, and theming them would mean repainting the thing the player
	is trying to pick. Roughly half the Color() calls in that panel are this kind, which is
	why the extraction could not just be a sweep of every Color() in the file.

	READING IT

	Read PS.Theme.X inside a paint function, never cached into a local at file scope. Two
	reasons: this file is included from cl_init.lua while the panels in lua/vgui/ are
	autoloaded by the engine, so load order between them is not guaranteed - but painting
	always happens long after both. And reading live is what will let a colour change apply
	without a reconnect once these become player-settable.

	NOT ALLOCATING

	Paint functions run every frame for every visible panel, so a Color() built inside one
	is garbage every frame. The static entries below are built once. Anything derived - a
	fill that brightens on hover - goes through Shade() into a scratch Color the caller owns
	at file scope. Same pattern the gamemode uses for its aura colours.
]]

PS = PS or {}
PS.Theme = PS.Theme or {}

local T = PS.Theme

-- ============================================================================
-- SURFACES
-- ============================================================================

-- ONE entry per surface across the whole shop.
--
-- These were briefly split per panel — MenuBG, PanelBG, CardPanelBG, MenuHeaderBG,
-- MenuScrollBG — so that changing one would show which surface it drew. That was a step, not
-- a destination: the shop menu, the customization panel, Admin, Inspector and the dialogs
-- are windows of one program, so their bodies are one colour, their headers are one colour,
-- and their scrollbars are one colour.
--
-- Collapsed onto (40,40,45), the value four of the five already used. The customization
-- panel was (30,30,35) and gets very slightly lighter, which is the point: it was the one
-- disagreeing.
T.FrameBG  = Color(40, 40, 45, 255)     -- every window body
T.HeaderBG = Color(30, 30, 30, 255)     -- every header bar

-- A panel sitting ON the window body, rather than the body itself: the boxed sections in
-- the appearance editor, the owner panels, anything PaintPanelBody draws.
--
-- Ships identical to FrameBG, which is what it was before it had a name -- PaintPanelBody
-- drew the body colour, so a panel on the ground was the same tone as the ground. On a
-- dark theme that is invisible and fine, because the accent rule along the panel's top
-- edge does the separating. On a light theme there is no glow to do that job and the whole
-- window collapses into one sheet, which is exactly what happened to Classic.
T.PanelBG  = Color(40, 40, 45, 255)

-- The window border and the header stripe are not their own colours: they are the accent,
-- and they read as it. FrameBorder and HeaderRule were separate entries holding (60,120,180)
-- and (60,140,200), which meant setting the accent left both behind.
--
-- Both now draw from T.Accent, with their own alphas applied at paint time.
T.StatusBar = Color(20, 40, 60)         -- status strip gradient base, a surface not an accent

-- Still its own: the strip behind the category buttons is a recessed container within a
-- window rather than a window, and nothing else in the shop draws one.
T.MenuCategoryBG = Color(40, 40, 40, 255)

-- List rows.
T.RowBG    = Color(40, 40, 45, 255)
T.RowAlt   = Color(44, 44, 50, 255)        -- every other row
T.RowHover = Color(50, 50, 55, 255)

-- Scrollbars.
T.ScrollTrack     = Color(30, 30, 35, 200)
T.ScrollGrip      = Color(60, 120, 180, 255)
T.ScrollGripHover = Color(80, 160, 220, 255)

-- ============================================================================
-- METRICS
--
-- Sizes, not colours, and here for the same reason the colours are: they were magic numbers
-- repeated per file, which is why header heights and row heights disagree between panels
-- that are meant to look like the same program.
--
-- Not exposed in the Appearance editor. The palette generator only picks up Colors, so this
-- table is invisible to it — which is correct: a player choosing their own row height is a
-- layout engine, not a theme.
-- ============================================================================

-- Every entry's value is the literal it replaced, so the shipped look is unchanged by any of
-- them existing. A look supplies a different combination; nothing here is a new default.
T.Metrics = {
	HeaderH   = 50,   -- header bar height
	RowH      = 44,   -- list row
	ButtonH   = 28,   -- action button
	IconBtn   = 35,   -- square header buttons
	Margin    = 10,   -- panel edge to content
	Gap       = 8,    -- between sibling controls
	Radius    = 8,    -- frames and dialogs
	RadiusMd  = 6,    -- category buttons, cards, context menus
	RadiusSm  = 4,    -- rows, buttons, small boxes
	ScrollW   = 12,

	-- The accent stripe along the top of a header bar. 0 removes it, which is what a look
	-- with a coloured header wants -- a stripe in the accent on a bar already in the accent
	-- is an invisible 3px.
	HeaderRule = 3,

	-- The MOST the category strip may take. It sizes itself to the rows the buttons
	-- actually need and only scrolls past this, so a look sets the ceiling, not the
	-- height -- the row count depends on window width and category count, which no look
	-- can know in advance. Too low and categories hide behind a scrollbar.
	CategoryStripH = 90,

	-- Gap between item cards in the grid. Was Gap - 3, which meant it could not be set
	-- without moving every other gap in the shop with it.
	GridSpace = 5,

	-- Gap between the square buttons in a header bar, and their inset from its right edge.
	IconGap    = 5,
	IconInset  = 15,

	-- The bar under an active tab, when the tab style draws one. See T.Selectable.
	UnderlineH = 3,

	-- Category strip. Buttons flow to fit rather than sitting in a fixed grid: the column
	-- count comes from the width available divided by CategoryW, then the buttons divide that
	-- width evenly so they always reach both edges.
	--
	-- CategoryW is a TARGET, not a size. Lowering it packs more, narrower columns in; raising
	-- it gives fewer, wider ones. The clamp is what keeps an ultrawide from producing a single
	-- row of twelve and a 4:3 from producing one column.
	CategoryBtnH = 35,
	CategoryGap  = 5,
	CategoryW    = 215,
	CategoryMinCols = 2,
	CategoryMaxCols = 6,

	-- Item grid, same idea. CardW is the target width per column; CardMin and CardMax bound
	-- what a card may actually become once the row is divided.
	CardW    = 208,
	CardPad  = 8,
	CardMin  = 150,
	CardMax  = 230,
	CardMinCols = 2,
	CardMaxCols = 8,

	-- ========================================================================
	-- SHOP WINDOW SIZE
	--
	-- Each dimension is  scale * screen + offset,  then clamped to [min, max].
	--
	-- Two numbers rather than one because neither alone covers what the shop has actually
	-- wanted. A pure fraction cannot express "900 wide, whatever the monitor"; a pure
	-- constant cannot express "as tall as the screen, less a margin". The pair does both,
	-- and an owner setting a house size does not have to know which kind theirs is:
	--
	--   fixed         scale 0,    offset 900     -> always 900
	--   screen-share  scale 0.62, offset 0       -> 62% of the width
	--   screen-inset  scale 1,    offset -100    -> the screen less 100px
	--
	-- These defaults are the third and first of those, which is the size the shop had before
	-- it was briefly made a pure screen-share. The clamps are what keep it usable on a small
	-- screen and stop it sprawling on a large one.
	-- ========================================================================
	FrameWScale  = 0,
	FrameWOffset = 900,
	FrameWMin    = 640,
	FrameWMax    = 1400,

	FrameHScale  = 1,
	FrameHOffset = -100,
	FrameHMin    = 600,
	FrameHMax    = 900,

	-- ========================================================================
	-- RESOLUTION SCALING
	--
	-- Every number above is authored against a screen RefH pixels tall, and multiplied by
	-- ScrH()/RefH at runtime. 1080 because that is what the shipped look was drawn against,
	-- so a 1080p screen gets exactly the values written here and nothing changes for it.
	--
	-- The clamps stop both extremes: below ScaleMin a 4:3 laptop would get a shop too small
	-- to read, above ScaleMax a 4K panel would get one so large it stops being a window.
	-- A look wanting to be scaled harder or not at all sets these like any other metric,
	-- and ScaleMin = ScaleMax = 1 turns scaling off entirely.
	-- ========================================================================
	RefH     = 1080,
	ScaleMin = 0.75,
	ScaleMax = 2,
}

-- ============================================================================
-- ACCENT
--
-- The blue that reads as "this is PointShop": divider lines, the status strip border,
-- loading text, and the selected state of a value button.
-- ============================================================================

T.Accent = Color(60, 120, 180)

T.SelectFill   = Color(80, 130, 220, 255)
T.SelectGloss  = Color(100, 150, 255, 80)   -- top-half sheen
T.SelectGlow   = Color(100, 150, 255)       -- hover halo; alpha set per frame
T.SelectBorder = Color(120, 170, 255, 200)

-- Unselected value button. Two entries per layer because the button lerps between them as
-- the cursor moves over it, rather than being one colour with an alpha change.
T.ControlFill        = Color(50, 50, 55, 255)
T.ControlFillHover   = Color(70, 70, 75, 255)
T.ControlGloss       = Color(70, 70, 75, 50)
T.ControlGlossHover  = Color(90, 90, 95, 50)
T.ControlBorder      = Color(100, 100, 110, 150)
T.ControlBorderHover = Color(100, 100, 110, 250)

-- Category button in the shop's category strip. Structurally the same widget as the value
-- button above - fill, sheen, halo, border, selected or not - but a different blue and a
-- larger radius, so it gets its own entries rather than being forced to share.
T.CategoryFill   = Color(60, 140, 200, 255)
T.CategoryGloss  = Color(80, 160, 220, 100)
T.CategoryGlow   = Color(80, 160, 220)
T.CategoryBorder = Color(100, 180, 240, 200)

T.CategoryIdleFill        = Color(60, 60, 65, 255)
T.CategoryIdleFillHover   = Color(75, 75, 80, 255)
T.CategoryIdleGloss       = Color(80, 80, 85, 60)
T.CategoryIdleGlossHover  = Color(95, 95, 100, 60)
T.CategoryIdleBorder      = Color(90, 90, 95, 150)
T.CategoryIdleBorderHover = Color(90, 90, 95, 250)

-- ============================================================================
-- ACTION BUTTONS
--
-- Grouped by what the button means rather than by its colour, so a theme changes intent
-- consistently: everything destructive moves together, everything confirming moves
-- together.
-- ============================================================================

-- Confirm / save
T.PositiveFill       = Color(40, 80, 50, 255)
T.PositiveFillHover  = Color(40, 110, 50, 255)
T.PositiveGloss      = Color(60, 120, 70, 100)
T.PositiveGlossHover = Color(60, 150, 70, 100)
T.PositiveGlow       = Color(80, 200, 100)     -- alpha set per frame
T.PositiveBorder     = Color(100, 180, 120, 200)

-- Reset / revert
T.WarningFill       = Color(120, 80, 30, 255)
T.WarningFillHover  = Color(140, 80, 30, 255)
T.WarningGloss      = Color(160, 100, 40, 80)
T.WarningGlossHover = Color(180, 100, 40, 80)
T.WarningBorder     = Color(180, 120, 60, 200)

-- Owner-only controls. Gold marks "this affects the server, not just you", so it is a
-- distinct role rather than a shade of Warning.
--
-- The hover value is 93.75 rather than 94 because the original computed it as base * 0.75
-- with base running 100 to 125. Kept exact so this extraction cannot shift a pixel.
T.GoldFill      = Color(100, 75, 20, 255)
T.GoldFillHover = Color(125, 93.75, 20, 255)
T.GoldBorder    = Color(180, 140, 30, 200)
T.GoldText      = Color(255, 230, 150)
T.GoldDivider   = Color(180, 140, 30, 120)
T.GoldLabel     = Color(180, 140, 30)

-- Destructive
T.DangerFill      = Color(100, 35, 35, 255)
T.DangerFillHover = Color(125, 35, 35, 255)
T.DangerBorder    = Color(160, 70, 70, 200)
T.DangerText      = Color(255, 180, 180)

-- Opens another tool rather than confirming or dismissing: the admin button.
T.AccentFill       = Color(60, 120, 180, 200)
T.AccentFillHover  = Color(100, 160, 180, 255)
T.AccentGloss      = Color(100, 160, 200, 80)
T.AccentGlossHover = Color(140, 200, 200, 80)
T.AccentGlow       = Color(100, 160, 220)
T.AccentBorder     = Color(100, 160, 220, 200)

-- Opens the customization panel. Neither confirming, destructive, nor owner-only, so it is
-- its own role. Every other right-click entry reuses a role that already existed — Sell is
-- Warning, Buy is Positive, Equip is the category accent — so the menu moves with the theme
-- instead of carrying nine private literals.
T.ModifyFill      = Color(140, 100, 200, 255)
T.ModifyFillHover = Color(170, 100, 230, 255)
T.ModifyBorder    = Color(180, 140, 240, 200)

-- Dismiss / cancel
T.NeutralFill       = Color(65, 65, 65, 255)
T.NeutralFillHover  = Color(80, 80, 80, 255)
T.NeutralGloss      = Color(80, 80, 80, 80)
T.NeutralGlossHover = Color(95, 95, 95, 80)
T.NeutralBorder     = Color(120, 120, 120, 200)
T.NeutralText       = Color(220, 220, 220, 255)

-- ============================================================================
-- DERIVED VARIANTS
--
-- Every button family above spells out six colours - fill, fill-hovered, sheen,
-- sheen-hovered, glow, border - and they are all the same colour. Confirm is green; its
-- border is a lighter green, its sheen a lighter green at low alpha, its glow a brighter
-- green. Six knobs describing one decision.
--
-- Worse, they were six SEPARATE knobs, so setting a fill without its sheen was not just
-- possible but the default outcome. That is exactly how the category button ended up black
-- with a blue top half.
--
-- So: one editable colour per family, and the variants follow it.
--
-- The offsets are MEASURED from the values above rather than written out here. Those values
-- are the design; this just records how far each variant sits from its base and reapplies
-- that when the base moves. Until a base is touched, every variant reproduces its shipped
-- value exactly - the measurement is against itself.
-- ============================================================================

local DERIVED = {}   -- [variantKey] = { base = <key>, dr, dg, db, da }

T.Derived = {}       -- set of variant keys, for the editor to skip

local function Derive(base, ...)
	local b = T[base]

	for _, key in ipairs({ ... }) do
		local v = T[key]
		if v then
			DERIVED[key] = {
				base = base,
				dr = v.r - b.r, dg = v.g - b.g, db = v.b - b.b, da = v.a - b.a,
			}
			T.Derived[key] = true
		end
	end
end

Derive("PositiveFill", "PositiveFillHover", "PositiveGloss", "PositiveGlossHover",
	"PositiveGlow", "PositiveBorder")
Derive("WarningFill", "WarningFillHover", "WarningGloss", "WarningGlossHover", "WarningBorder")
Derive("NeutralFill", "NeutralFillHover", "NeutralGloss", "NeutralGlossHover", "NeutralBorder")
Derive("AccentFill", "AccentFillHover", "AccentGloss", "AccentGlossHover", "AccentGlow",
	"AccentBorder")
Derive("SelectFill", "SelectGloss", "SelectGlow", "SelectBorder")
Derive("ControlFill", "ControlFillHover", "ControlGloss", "ControlGlossHover",
	"ControlBorder", "ControlBorderHover")
Derive("CategoryFill", "CategoryGloss", "CategoryGlow", "CategoryBorder")
Derive("CategoryIdleFill", "CategoryIdleFillHover", "CategoryIdleGloss",
	"CategoryIdleGlossHover", "CategoryIdleBorder", "CategoryIdleBorderHover")
Derive("GoldFill", "GoldFillHover", "GoldBorder", "GoldDivider")
Derive("DangerFill", "DangerFillHover", "DangerBorder")
Derive("ModifyFill", "ModifyFillHover", "ModifyBorder")

-- The shipped offsets, copied before anything can edit them.
--
-- A preset may set a variant by hand, and SetPreset turns that into the variant's new
-- relationship to its base — otherwise SyncDerived would overwrite it a frame later. That
-- edits DERIVED permanently, so without a copy of the originals, leaving a preset would keep
-- its relationships and reproduce its look in the default's colours.
--
-- Built here rather than beside DERIVED because every Derive() call above has to have run.
local SHIPPED_DERIVED = {}
for k, d in pairs(DERIVED) do
	SHIPPED_DERIVED[k] = { dr = d.dr, dg = d.dg, db = d.db, da = d.da }
end

-- In place, like everything else that touches these tables.
local function RestoreShippedOffsets()
	for k, s in pairs(SHIPPED_DERIVED) do
		local d = DERIVED[k]
		d.dr, d.dg, d.db, d.da = s.dr, s.dg, s.db, s.da
	end
end

-- NOT derived, deliberately: GoldText, GoldLabel, DangerText, NeutralText.
--
-- They are label colours, and a label has to stay readable against its fill. Offsetting text
-- from the fill means darkening a button darkens its text with it, and the two meet in the
-- middle as something illegible. Contrast is the one relationship that must not be preserved
-- when the base moves.

-- Recomputes every variant from its base, in place.
--
-- In place matters for the same reason it does everywhere else here: the widget style tables
-- hold references to these exact Color tables, so replacing one would leave the styles
-- pointing at the old value.
function T.SyncDerived()
	for key, d in pairs(DERIVED) do
		local b, v = T[d.base], T[key]
		v.r = math.Clamp(b.r + d.dr, 0, 255)
		v.g = math.Clamp(b.g + d.dg, 0, 255)
		v.b = math.Clamp(b.b + d.db, 0, 255)
		v.a = math.Clamp(b.a + d.da, 0, 255)
	end
end

-- Re-measures one variant's offset from its base.
--
-- Called when someone edits a variant directly in the editor's advanced view. Without it,
-- their change would survive exactly until the next time the base moved and SyncDerived
-- overwrote it — a setting that silently undoes itself is worse than one that is not offered.
--
-- Re-measuring instead means a hand-edited variant becomes the new relationship: move the
-- base afterwards and the edit travels with it.
function T.RemeasureDerived(key)
	local d = DERIVED[key]
	if not d then return end

	local b, v = T[d.base], T[key]
	d.dr, d.dg, d.db, d.da = v.r - b.r, v.g - b.g, v.b - b.b, v.a - b.a
end

function T.IsDerived(key) return DERIVED[key] ~= nil end

-- ============================================================================
-- ITEM CARD
--
-- The border is the card's whole state readout - equipped, owned, affordable, not - so
-- these four are the most load-bearing colours in the shop for telling at a glance what you
-- are looking at, and the first place a colour-vision problem would bite.
-- ============================================================================

T.CardBG       = Color(35, 35, 40, 255)
T.CardEquipped = Color(200, 170, 50, 255)
T.CardOwned    = Color(60, 140, 200, 255)
T.CardQueued   = Color(180, 40, 40, 255)    -- pending removal
T.CardBorder   = Color(70, 70, 75, 200)     -- no particular state
T.CardHover    = Color(90, 90, 95, 180)     -- alpha scaled by hover
T.CardLabelBG  = Color(18, 18, 22)

-- Badge pill only. These are NOT border states — affordability shows in the badge while the
-- border is showing ownership, and the two are independent.
T.CardCanBuy   = Color(50, 160, 70, 220)
T.CardCantBuy  = Color(160, 50, 50, 220)

-- The right-click menu is translucent, so it keeps its own entry - it sits over the item
-- grid rather than over the world, and the alpha is the point. The confirm dialog's body
-- folded into FrameBG with every other window.
T.CardMenuBG   = Color(40, 40, 45, 250)
T.MenuRowText  = Color(200, 200, 200, 255)  -- right-click menu entry, not hovered


-- The Inspector's price readout. Green when you can afford it, red when you cannot — the
-- only place in the shop where a colour reports a fact about the player rather than naming a
-- surface, which is why it is not derived from anything.
T.PriceAfford = Color(100, 255, 100, 255)
T.PriceCant   = Color(255, 100, 100, 255)

T.BadgeGloss  = Color(255, 255, 255, 20)    -- sheen across the top of a card badge
T.IconAdmin   = Color(255, 220, 80, 230)    -- admin-only item marker
T.IconGroup   = Color(200, 200, 200, 180)   -- group-restricted item marker

-- ============================================================================
-- TEXT
-- ============================================================================

-- Body text. Whatever sits on FrameBG, a row, a card, or an unfilled control.
--
-- This is the one that follows the body, so a preset with a light body moves it dark. The
-- two below exist because they do NOT follow it -- see each.
T.Text = Color(255, 255, 255, 255)

-- Text drawn on the header bar: the window title and the header glyph buttons.
--
-- Split from Text because the header is a different surface from the body and does not have
-- to share its brightness. The default look happens to make both white, which is exactly why
-- one token served for so long -- but PointShop 1 is a light body under a slate header, and
-- there the two must disagree or the title vanishes into the bar.
T.HeaderText = Color(255, 255, 255, 255)

-- Text drawn on top of a saturated fill: card price badges, the card's name strip, anything
-- sitting on Positive/Danger/Gold and friends.
--
-- Split for the same reason and it is the stronger case: those fills are chosen for their
-- own meaning, so the text on them tracks the FILL, not the theme. It stays light whether
-- the body around it is dark or light.
T.OnFill = Color(255, 255, 255, 255)

-- Category tab text, one per state.
--
-- All three ship as plain white, which is what UI.Tab drew before it could distinguish the
-- states at all — so their existing changes nothing. They matter for a look whose tab strip
-- is the same surface as the body: with no fill to mark the active tab, the weight of the
-- text is carrying the selection alongside the underline.
T.TabIdle   = Color(255, 255, 255, 255)
T.TabHover  = Color(255, 255, 255, 255)
T.TabActive = Color(255, 255, 255, 255)

T.TextDim      = Color(200, 220, 255)   -- status strip, section labels
T.PointsText   = Color(255, 255, 0, 255) -- the balance in the shop header
T.Shadow       = Color(0, 0, 0, 180)
T.ShadowStrong = Color(0, 0, 0, 200)

-- ============================================================================
-- HELPERS
-- ============================================================================

-- Blends `a` toward `b` by `frac` and writes the result into `target`, which the caller
-- owns and reuses. Returns target so it can be passed straight to a draw call.
--
-- Takes a target rather than returning a fresh Color because every caller is a paint
-- function. A shared scratch pool inside this file would be the obvious alternative and is
-- a trap: two panels painting in the same frame would hand the same table to two draw
-- calls, and the second write would silently repaint the first.
function T.Shade(target, a, b, frac)
	target.r = a.r + (b.r - a.r) * frac
	target.g = a.g + (b.g - a.g) * frac
	target.b = a.b + (b.b - a.b) * frac
	target.a = a.a + (b.a - a.a) * frac
	return target
end

-- Same colour at a different alpha, for the hover halos whose opacity is the only thing
-- that animates.
function T.Alpha(target, col, alpha)
	target.r = col.r
	target.g = col.g
	target.b = col.b
	target.a = alpha
	return target
end

-- ============================================================================
-- WIDGET STYLES
--
-- Each entry holds REFERENCES to the Colors above, not copies. That is what makes live
-- theming work: the editor writes new channel values into a palette Color in place, and
-- every style pointing at it paints the new colour on the next frame. Rebuilding these
-- tables with fresh Colors would break that silently - the styles would keep the old ones.
--
-- Non-colour fields (radius, lerp speed, glow strength) live here too, because they are
-- what actually distinguishes one instance of an archetype from another.
-- ============================================================================

T.Selectable = {
	-- Skin and bodygroup pickers in the customization panel.
	Value = {
		radius = "RadiusSm", lerp = 8,
		activeFill = T.SelectFill, activeGloss = T.SelectGloss,
		activeGlow = T.SelectGlow, glowBase = 50, glowRange = 50,
		activeBorder = T.SelectBorder,
		fill  = T.ControlFill,  fillHover  = T.ControlFillHover,
		gloss = T.ControlGloss, glossHover = T.ControlGlossHover,
		border = T.ControlBorder, borderHover = T.ControlBorderHover,
	},
	-- Category strip in the shop menu.
	Category = {
		radius = "RadiusMd", lerp = 8,
		activeFill = T.CategoryFill, activeGloss = T.CategoryGloss,
		activeGlow = T.CategoryGlow, glowBase = 100, glowRange = 50,
		activeBorder = T.CategoryBorder,
		fill  = T.CategoryIdleFill,  fillHover  = T.CategoryIdleFillHover,
		gloss = T.CategoryIdleGloss, glossHover = T.CategoryIdleGlossHover,
		border = T.CategoryIdleBorder, borderHover = T.CategoryIdleBorderHover,
	},
}

-- `gloss` and `glow` are optional - a style without them simply skips those layers, which
-- is how the gold and danger buttons stay flat while the rest have a sheen.
T.Action = {
	Positive = {
		radius = "RadiusMd", lerp = 10, font = "PS_DefaultBold",
		fill = T.PositiveFill, fillHover = T.PositiveFillHover,
		gloss = T.PositiveGloss, glossHover = T.PositiveGlossHover,
		glow = T.PositiveGlow, glowLayers = { 80, 40 },
		border = T.PositiveBorder, text = T.OnFill, shadow = T.ShadowStrong,
	},
	Warning = {
		radius = "RadiusSm", lerp = 10, font = "PS_Default",
		fill = T.WarningFill, fillHover = T.WarningFillHover,
		gloss = T.WarningGloss, glossHover = T.WarningGlossHover,
		border = T.WarningBorder, text = T.OnFill, shadow = T.Shadow,
	},
	Gold = {
		radius = "RadiusSm", lerp = 10, font = "PS_Default",
		fill = T.GoldFill, fillHover = T.GoldFillHover,
		border = T.GoldBorder, text = T.GoldText, shadow = T.Shadow,
	},
	Danger = {
		radius = "RadiusSm", lerp = 10, font = "PS_Default",
		fill = T.DangerFill, fillHover = T.DangerFillHover,
		border = T.DangerBorder, text = T.DangerText, shadow = T.Shadow,
	},
	Neutral = {
		radius = "RadiusSm", lerp = 10, font = "PS_Default",
		fill = T.NeutralFill, fillHover = T.NeutralFillHover,
		gloss = T.NeutralGloss, glossHover = T.NeutralGlossHover,
		border = T.NeutralBorder, text = T.NeutralText, shadow = T.Shadow,
	},
	-- Neutral-but-important: the admin button in the shop header. Blue rather than grey
	-- because it opens another tool rather than dismissing something.
	-- Opens the customization panel. Neither confirming, destructive, nor owner-only, so it
	-- is its own role rather than borrowed from one of those.
	Modify = {
		radius = "RadiusSm", lerp = 10, font = "PS_Default",
		fill = T.ModifyFill, fillHover = T.ModifyFillHover,
		border = T.ModifyBorder, text = T.OnFill, shadow = T.Shadow,
	},
	Accent = {
		radius = "RadiusMd", lerp = 10, font = "PS_Default",
		fill = T.AccentFill, fillHover = T.AccentFillHover,
		gloss = T.AccentGloss, glossHover = T.AccentGlossHover,
		glow = T.AccentGlow, glowLayers = { 100 },
		border = T.AccentBorder, text = T.OnFill, shadow = T.Shadow,
	},
}

-- ============================================================================
-- PAINTERS
--
-- The real panels and the theme editor's mockup both call these. That is the point: a
-- mockup that redrew the widgets itself would drift from the shop the first time either
-- side was touched, and the drift would be invisible until someone noticed the preview was
-- lying. Sharing the paint code makes that impossible rather than merely unlikely.
--
-- Scratch colours are file-scope and shared across painters, which is safe only because
-- every write below is consumed by its draw call before the next write happens. Do not
-- hold one of these past a draw call.
-- ============================================================================

local sFill   = Color(0, 0, 0)
local sGloss  = Color(0, 0, 0)
local sBorder = Color(0, 0, 0)
local sGlow   = Color(0, 0, 0)

-- Advances and returns the panel's own hover animation. Stored on the panel rather than
-- passed in, so a caller only has to hand over the style.
local function HoverAlpha(panel, speed)
	panel._hoverAlpha = Lerp(FrameTime() * speed, panel._hoverAlpha or 0, panel:IsHovered() and 1 or 0)
	return panel._hoverAlpha
end

-- Resolves a style's corner radius.
--
-- Styles name a metric ("RadiusSm") rather than holding a number, because a style table is
-- built once at load: a baked copy could never follow a metric change, so squaring the
-- corners for one look would leave every button still rounded. A raw number is still accepted
-- for anything that genuinely wants a fixed corner.
local function StyleRadius(style)
	local r = style.radius
	if isstring(r) then return T.Metrics[r] or 0 end
	return r or 0
end

-- A button that is either selected or not: value buttons, category buttons.
-- How a style marks its active state.
--
-- "fill" repaints the whole button in the active colour, which is what every style shipped
-- with and stays the default for anything that does not say otherwise.
--
-- "underline" leaves the button looking idle and draws a bar along its bottom edge instead.
-- That is a genuinely different structure, not a different colour, which is why it could not
-- be a palette entry -- and it is how a tab strip marks its selection when the strip is the
-- same surface as the body behind it, with no fill available to distinguish anything.
function T.PaintSelectable(panel, w, h, isActive, style)
	local hover = HoverAlpha(panel, style.lerp)
	local r = StyleRadius(style)

	if isActive and style.activeMode == "underline" then
		-- Idle body: an underlined tab is not filled, so it paints exactly as an inactive one
		-- and the bar carries the whole signal.
		draw.RoundedBox(r, 0, 0, w, h, T.Shade(sFill, style.fill, style.fillHover, hover))
		draw.RoundedBox(r, 0, 0, w, h / 2, T.Shade(sGloss, style.gloss, style.glossHover, hover))

		surface.SetDrawColor(T.Shade(sBorder, style.border, style.borderHover, hover))
		surface.DrawOutlinedRect(0, 0, w, h)

		local uh = T.Metrics.UnderlineH
		if uh > 0 then
			surface.SetDrawColor(style.activeFill)
			surface.DrawRect(0, h - uh, w, uh)
		end

		return
	end

	if isActive then
		draw.RoundedBox(r, 0, 0, w, h, style.activeFill)
		draw.RoundedBox(r, 0, 0, w, h / 2, style.activeGloss)

		-- Only the halo's opacity animates, so this is an alpha change rather than a blend.
		surface.SetDrawColor(T.Alpha(sGlow, style.activeGlow, style.glowBase + hover * style.glowRange))
		surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)

		surface.SetDrawColor(style.activeBorder)
	else
		draw.RoundedBox(r, 0, 0, w, h, T.Shade(sFill, style.fill, style.fillHover, hover))
		draw.RoundedBox(r, 0, 0, w, h / 2, T.Shade(sGloss, style.gloss, style.glossHover, hover))

		surface.SetDrawColor(T.Shade(sBorder, style.border, style.borderHover, hover))
	end

	surface.DrawOutlinedRect(0, 0, w, h)
end

-- Multiplies a scratch colour's alpha in place. Used for the disabled state, which is the
-- same colours at reduced opacity rather than a second palette.
local function Fade(col, mul)
	col.a = col.a * mul
	return col
end

-- A labelled action button. Caller passes the label so the style stays reusable.
--
-- Honours the panel's enabled state. Admin's Take Item and Give Item both stay on screen
-- after they have been used — disabling the button rather than closing the window, so an
-- admin clearing an inventory does not pay a server round trip per item — and they need to
-- read as spent. Same colours at 30% alpha, and no hover animation, since a disabled control
-- that still lights up under the cursor is claiming it will do something.
function T.PaintAction(panel, w, h, style, label)
	local enabled = panel:IsEnabled()
	local hover = enabled and HoverAlpha(panel, style.lerp) or 0
	local dim = enabled and 1 or 0.3
	local r = StyleRadius(style)

	draw.RoundedBox(r, 0, 0, w, h, Fade(T.Shade(sFill, style.fill, style.fillHover, hover), dim))

	if style.gloss then
		draw.RoundedBox(r, 0, 0, w, h / 2, Fade(T.Shade(sGloss, style.gloss, style.glossHover, hover), dim))
	end

	-- Concentric halos, each one step further out and fainter than the last.
	if style.glow and hover > 0 then
		for i = 1, #style.glowLayers do
			surface.SetDrawColor(T.Alpha(sGlow, style.glow, hover * style.glowLayers[i]))
			surface.DrawOutlinedRect(-i, -i, w + i * 2, h + i * 2)
		end
	end

	surface.SetDrawColor(Fade(T.Alpha(sBorder, style.border, style.border.a or 255), dim))
	surface.DrawOutlinedRect(0, 0, w, h)

	if label then
		draw.SimpleText(label, style.font, w / 2 + 1, h / 2 + 1,
			Fade(T.Alpha(sGloss, style.shadow, style.shadow.a or 255), dim), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(label, style.font, w / 2, h / 2,
			Fade(T.Alpha(sFill, style.text, style.text.a or 255), dim), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- Window body plus its border.
--
-- Every panel in the shop drew this by hand: rounded body, then two outlined rects one pixel
-- apart at alpha 100 and 50. The doubled outline is not decoration — a single hard line
-- aliases badly against whatever is behind a floating window, and the fainter second pass
-- softens it.
--
-- There used to be a black gradient between the two. It was removed: it drew a hard bar
-- across the bottom of anything taller than ~675px, and it meant the body colour was never
-- the colour anyone set.
-- `body` overrides FrameBG for a caller that genuinely needs a different surface. Nothing in
-- the shop does today — every window shares FrameBG — but a translucent popup or an embedded
-- panel would, and the border recipe stays shared either way.
function T.PaintFrame(w, h, body)
	draw.RoundedBox(T.Metrics.Radius, 0, 0, w, h, body or T.FrameBG)

	surface.SetDrawColor(T.Alpha(sBorder, T.Accent, 100))
	surface.DrawOutlinedRect(0, 0, w, h)
	surface.SetDrawColor(T.Alpha(sBorder, T.Accent, 50))
	surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
end

-- Header bar: flat background, accent stripe along the top, left-aligned title.
function T.PaintHeader(w, h, title)
	surface.SetDrawColor(T.HeaderBG)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(T.Accent)
	surface.DrawRect(0, 0, w, T.Metrics.HeaderRule)

	if title then
		draw.SimpleText(title, "PS_LargeTitle", 15, h / 2, T.HeaderText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function T.PaintScrollTrack(w, h)
	draw.RoundedBox(T.Metrics.RadiusSm, 0, 0, w, h, T.ScrollTrack)
end

function T.PaintScrollGrip(panel, w, h)
	local col = panel:IsHovered() and T.ScrollGripHover or T.ScrollGrip
	draw.RoundedBox(T.Metrics.RadiusSm, 2, 0, w - 4, h, col)
end

-- List row. `index` drives the alternating stripe; nil for a list that does not alternate.
function T.PaintRow(panel, w, h, index, selected)
	local col

	if selected then
		col = T.RowHover
	elseif panel:IsHovered() then
		col = T.RowHover
	elseif index and index % 2 == 0 then
		col = T.RowAlt
	else
		col = T.RowBG
	end

	draw.RoundedBox(T.Metrics.RadiusSm, 0, 0, w, h, col)
end

-- Panel body: rounded background with a single-pixel accent along the top edge.
function T.PaintPanelBody(w, h)
	draw.RoundedBox(T.Metrics.RadiusSm, 0, 0, w, h, T.PanelBG)
	surface.SetDrawColor(T.Alpha(sBorder, T.Accent, 80))
	surface.DrawRect(0, 0, w, 1)
end

-- Status strip across the top of a panel: a gradient that fades downward, an accent rule
-- under it, and centred text with a shadow.
--
-- The fade's end alpha is passed explicitly rather than running to zero. The ramp is
-- 150 down to 150 - barH * 1.5, which for a 35px bar stops at 97.5 - so it never reaches
-- transparent inside the bar, and letting it fade out fully would be a different look.
function T.PaintStatusStrip(w, barH, text)
	PS_DrawScrimFade(0, 0, w, barH, T.StatusBar, 150, 150 - (barH * 1.5))

	surface.SetDrawColor(T.Alpha(sBorder, T.Accent, 150))
	surface.DrawRect(10, barH, w - 20, 2)

	if text then
		draw.SimpleText(text, "PS_Default", w / 2 + 1, 16, T.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(text, "PS_Default", w / 2, 15, T.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

-- Item card. `state` is one of "Equipped", "Owned", "CanBuy", "CantBuy", or nil for a card
-- with no state, which falls back to the plain border.
--
-- The doubled outline is not decoration: the outer pass at 40% alpha softens the edge so a
-- saturated border does not alias into a hard jagged line against the card behind it.
function T.PaintItemCard(panel, w, h, state, label)
	local labelH = 38

	draw.RoundedBox(T.Metrics.RadiusMd, 0, 0, w, h, T.CardBG)

	local border = state and T["Card" .. state]
	local alpha

	if border then
		alpha = border.a or 255
	else
		-- No state: a plain border that brightens under the cursor, so an unowned card the
		-- player is pointing at still reads as the one they have picked out.
		local hover = HoverAlpha(panel, 8)
		if hover > 0 then
			border, alpha = T.CardHover, (T.CardHover.a or 255) * hover
		else
			border, alpha = T.CardBorder, T.CardBorder.a or 255
		end
	end

	surface.SetDrawColor(T.Alpha(sBorder, border, alpha * 0.4))
	surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)
	surface.SetDrawColor(T.Alpha(sBorder, border, alpha))
	surface.DrawOutlinedRect(0, 0, w, h)

	-- A queued item gets a second border inside the first. Removal is destructive and
	-- irreversible from the player's side, so it is worth more than a colour change.
	if state == "Queued" then
		surface.SetDrawColor(T.Alpha(sBorder, T.CardQueued, 120))
		surface.DrawOutlinedRect(2, 2, w - 4, h - 4)
	end

	if label then
		PS_DrawScrimFade(1, h - labelH, w - 2, labelH, T.CardLabelBG, 230)
		draw.SimpleText(label, "PS_ItemText", w / 2 + 1, h - labelH / 2 + 1, T.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(label, "PS_ItemText", w / 2, h - labelH / 2, T.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- ============================================================================
-- PERSISTENCE
--
-- Three layers, applied in order, each overriding the one before:
--
--   1. SHIPPED   - the palette written above. Every client has this, always. It is the
--                  look the shop has out of the box, and the floor everything else sits
--                  on: nothing can remove it, so there is always something valid to draw.
--   2. SERVER    - one main default the server sends on join (pointshop/sv_theme.lua).
--                  This is how a server has a house look without shipping a modified
--                  addon. Absent on a server that has not set one.
--   3. CUSTOM    - the player's own picks, from their config file.
--
-- The config file holds BOTH the defaults it was handed and the custom colours, in
-- separate sections. Keeping the defaults in the file rather than only in memory means the
-- player's copy records what they were customising away from, so "reset" is meaningful
-- even after the server's default changes underneath them.
--
-- Same file shape as pointshop/ps_item_defaults.lua: JSON under data/pointshop/, parse
-- guarded by pcall, and anything unreadable falls back quietly. A theme is cosmetic - it
-- must never be able to stop someone opening the shop.
-- ============================================================================

local DATA_PATH = "pointshop/theme.json"

-- Snapshot of the shipped values, taken before anything can overwrite them. A copy, not
-- references - referencing the live Colors would make this track the very edits it exists
-- to undo.
local DEFAULTS = {}

-- Only entries that are actually Colors are themeable; the style tables and the painters
-- live on the same table and must not be walked into.
local function IsColourKey(k, v)
	return istable(v) and v.r ~= nil and v.g ~= nil and v.b ~= nil and isstring(k)
end

for k, v in pairs(T) do
	if IsColourKey(k, v) then
		DEFAULTS[k] = { v.r, v.g, v.b, v.a }
	end
end

-- ============================================================================
-- PRESETS
-- ============================================================================
--
-- A named set of colours and metrics applied as a LAYER, not as a bulk write.
--
-- The distinction matters. Writing a preset straight into the player's `custom` would mark
-- every value as personally chosen, and `custom` is deliberately only the difference from
-- the base so that a player keeps tracking changes the owner makes. Bulk-writing would
-- freeze their whole palette at the moment they picked a preset.
--
-- So the order is: shipped defaults, then the preset, then the server default, then the
-- player's own edits on top. Changing preset moves the base and leaves their edits intact.
--
-- Metrics ride along because a look is not only colour -- PointShop 1 has square corners and
-- a shorter header, and neither is a Color.
T.Presets = T.Presets or {}

local METRIC_DEFAULTS = {}
for k, v in pairs(T.Metrics) do METRIC_DEFAULTS[k] = v end

-- ============================================================================
-- RESOLUTION SCALING
--
-- Every metric above is a pixel count authored against a reference screen. Left alone,
-- that is the whole per-resolution problem: a 50px header and a 208px card are half the
-- screen on 768p and a postage stamp on 2160p, so the shop shrinks as the monitor grows.
--
-- So the authored numbers are a BASE, and T.Metrics holds them multiplied by a scale taken
-- from the screen height. Height rather than width, because scaling on width stretches the
-- UI on an ultrawide, where the extra pixels are beside the window and not inside it.
--
-- At the reference height the scale is exactly 1 and every number is the value written
-- above -- so the shipped look on a 1080p screen is untouched by any of this.
--
-- Presets and the owner write the BASE. Nothing writes T.Metrics directly any more, and
-- T.Metrics keeps its table identity because panels hold a reference to it.
-- ============================================================================

local METRIC_BASE = {}
for k, v in pairs(METRIC_DEFAULTS) do METRIC_BASE[k] = v end

-- Not pixel counts, so scaling them would be meaningless or harmful: a fraction of the
-- screen is already resolution-relative, a column count is a count, and the scale controls
-- themselves obviously cannot scale.
local UNSCALED = {
	FrameWScale = true, FrameHScale = true,
	CategoryMinCols = true, CategoryMaxCols = true,
	CardMinCols = true, CardMaxCols = true,
	RefH = true, ScaleMin = true, ScaleMax = true,
}

function T.Scale()
	local ref = METRIC_BASE.RefH
	if not ref or ref <= 0 then return 1 end

	return math.Clamp(ScrH() / ref, METRIC_BASE.ScaleMin or 0.5, METRIC_BASE.ScaleMax or 3)
end

-- Writes the scaled values into T.Metrics IN PLACE.
--
-- In place for the same reason everything else here is: panels take
-- `local M = PS.Theme.Metrics` and hold that reference, so replacing the table would leave
-- them reading the old one forever.
--
-- Rounded, because these become panel sizes and positions, and a control on a half pixel
-- smears its own border.
function T.Rescale()
	local s = T.Scale()

	for k, v in pairs(METRIC_BASE) do
		if UNSCALED[k] then
			T.Metrics[k] = v
		else
			T.Metrics[k] = math.Round(v * s)
		end
	end

	-- Text is sized in pixels too, so it moves with everything else.
	if T.BuildFonts then T.BuildFonts() end
end

local activePreset = nil

-- A preset id read from the save file whose preset has not registered yet.
--
-- T.Load runs at the bottom of this file, and anything registering a preset -- another
-- file here, a gamemode, an addon -- loads after that. Without this the saved choice would
-- be dropped on every join and the player would silently get the shipped look back.
local pendingPreset = nil

function T.RegisterPreset(id, def)
	if not isstring(id) or not istable(def) then return end
	T.Presets[id] = def

	if pendingPreset == id then
		pendingPreset = nil
		T.SetPreset(id)
	end
end

function T.GetPreset()
	return activePreset
end

-- Metrics are written IN PLACE for the same reason the Colors are: panels take
-- `local M = PS.Theme.Metrics` and hold that reference, so replacing the table would leave
-- them reading the old one.
local function ApplyMetrics(preset)
	for k, v in pairs(METRIC_DEFAULTS) do METRIC_BASE[k] = v end

	if preset and istable(preset.metrics) then
		for k, v in pairs(preset.metrics) do
			if METRIC_DEFAULTS[k] ~= nil and isnumber(v) then METRIC_BASE[k] = v end
		end
	end

	T.Rescale()
end

-- ============================================================================
-- FONTS
--
-- Sizes are pixel counts like every metric, so they scale with the screen too. Without
-- this the resolution work is half done: at 2x the panels double and the labels stay 13px,
-- giving a correctly sized shop full of undersized text.
--
-- surface.CreateFont bakes the size at creation, and there is no draw-time size argument,
-- so scaling means re-creating each font. Calling it again with the same name redefines
-- that font, and every draw site refers to fonts by NAME -- so nothing downstream has to
-- know this happened. It is not cheap, which is why it runs on a scale change and never
-- per frame.
--
-- These lived at the top of DPointShopMenu.lua, which is the wrong file for something every
-- panel draws with -- and load-bearing for panels that are autoloaded by the engine rather
-- than included after it.
-- ============================================================================

local SANS = system.IsLinux() and "Arial" or "Tahoma"

T.Fonts = {
	{ "PS_Heading",        "coolvetica", 64 },
	{ "PS_Heading2",       "coolvetica", 24 },
	{ "PS_Heading3",       "coolvetica", 19 },
	{ "PS_Default",        SANS,   13, 500 },
	{ "PS_DefaultBold",    SANS,   13, 800 },
	{ "PS_Heading1",       SANS,   18, 500 },
	{ "PS_Heading1Bold",   SANS,   18, 800 },
	{ "PS_ButtonText1",    "Roboto", 22, 700 },
	{ "PS_ItemText",       SANS,   11, 500 },
	{ "PS_LargeTitle",     "Roboto", 32, 500 },
	{ "PS_CategoryButton", "Roboto", 14, 600 },
}

function T.BuildFonts()
	local s = T.Scale()

	for _, f in ipairs(T.Fonts) do
		local name, face, size, weight = f[1], f[2], f[3], f[4]

		surface.CreateFont(name, {
			font      = face,

			-- Floored at 1: a zero-size font is a silent draw of nothing, and the clamps on
			-- Scale should already prevent it -- should, not will, since a look sets them.
			size      = math.max(1, math.Round(size * s)),
			weight    = weight,
			antialias = true,
		})
	end
end
-- The server's house sizes, once they have arrived. nil until then.
local serverMetrics = nil

-- Applied after T.Load, since Load runs ApplyMetrics for the preset and would otherwise
-- overwrite these a moment later.
--
-- Clamped to something sane rather than trusted. This arrives over the network from a player
-- who passed an owner check, which makes it trusted enough to store but not trusted enough to
-- be allowed to produce a shop 8 pixels wide that nobody can then open to fix it.
local METRIC_BOUNDS = {
	FrameWScale = { 0, 1 },   FrameHScale  = { 0, 1 },
	FrameWOffset = { -4000, 4000 }, FrameHOffset = { -4000, 4000 },
	FrameWMin = { 320, 4000 }, FrameWMax = { 320, 4000 },
	FrameHMin = { 240, 4000 }, FrameHMax = { 240, 4000 },
}

local function ApplyServerMetrics()
	if not istable(serverMetrics) then return end

	for k, v in pairs(serverMetrics) do
		if METRIC_DEFAULTS[k] ~= nil and isnumber(v) then
			local b = METRIC_BOUNDS[k]
			METRIC_BASE[k] = b and math.Clamp(v, b[1], b[2]) or v
		end
	end

	-- A max below its min would make math.Clamp return the max and silently inverts the
	-- intent, so the pair is straightened rather than obeyed.
	if METRIC_BASE.FrameWMax < METRIC_BASE.FrameWMin then METRIC_BASE.FrameWMax = METRIC_BASE.FrameWMin end
	if METRIC_BASE.FrameHMax < METRIC_BASE.FrameHMin then METRIC_BASE.FrameHMax = METRIC_BASE.FrameHMin end

	T.Rescale()
end

-- The widget styles as shipped, so a preset's changes to them can be undone.
--
-- Shallow per style: the values include references to Color tables (activeFill IS
-- T.CategoryFill, not a copy of it), and those references must be preserved exactly. Copying
-- the colours instead would sever every style from the palette and freeze it at load.
local STYLE_DEFAULTS = {}
for name, style in pairs(T.Selectable) do
	local snap = {}
	for k, v in pairs(style) do snap[k] = v end
	STYLE_DEFAULTS[name] = snap
end

-- Applies a preset's style block, having first restored every style to shipped.
--
-- Restoring writes the snapshot back and then clears any key the snapshot does not have, so
-- a mode a previous preset switched on does not survive into one that never mentions it.
--
-- Colour-valued keys are given as TOKEN NAMES ("TextDim") rather than literals, so they
-- resolve to the live Color table and keep tracking the palette -- including the player's own
-- edits on top of the preset. A literal would be a dead copy.
local function ApplyStyles(preset)
	for name, snap in pairs(STYLE_DEFAULTS) do
		local style = T.Selectable[name]

		for k in pairs(style) do
			if snap[k] == nil then style[k] = nil end
		end
		for k, v in pairs(snap) do style[k] = v end
	end

	if not (preset and istable(preset.styles)) then return end

	for name, keys in pairs(preset.styles) do
		local style = T.Selectable[name]
		if istable(style) and istable(keys) then
			for k, v in pairs(keys) do
				-- A string naming a palette entry resolves to that live Color; any other
				-- string is a plain value. That is what separates text = "TabIdle" from
				-- activeMode = "underline" and radius = "RadiusSm" without either needing
				-- to be tagged.
				if isstring(v) and T[v] ~= nil then
					style[k] = T[v]
				else
					style[k] = v
				end
			end
		end
	end
end

-- Writes values into the existing Color tables in place.
--
-- In place is load-bearing, not a micro-optimisation: every widget style holds a reference
-- to these exact tables, so replacing one would leave the styles pointing at the old table
-- and the change would appear to do nothing.
-- The write half, without the resync.
--
-- Split out for SetPreset, which has to write, then re-measure the variants the preset set by
-- hand, and only then sync — syncing in between would overwrite those variants with the
-- shipped offsets, which is the thing being avoided.
local function WriteColours(tbl)
	if not istable(tbl) then return end

	for k, v in pairs(tbl) do
		local c = T[k]
		if c and DEFAULTS[k] and istable(v) then
			c.r = math.Clamp(tonumber(v[1]) or c.r, 0, 255)
			c.g = math.Clamp(tonumber(v[2]) or c.g, 0, 255)
			c.b = math.Clamp(tonumber(v[3]) or c.b, 0, 255)
			c.a = math.Clamp(tonumber(v[4]) or c.a, 0, 255)
		end
	end
end

function T.Apply(tbl)
	if not istable(tbl) then return end

	WriteColours(tbl)

	-- A base may have moved, so the variants that follow it are now stale.
	T.SyncDerived()
end

-- The server's main default, once it has arrived. nil on a server that has not set one.
local serverDefault = nil

-- Layers 1 and 2 together: what this player sees before any of their own choices. This is
-- what "reset" means and what `custom` is measured against.
local function ResolvedDefault()
	local out = {}
	for k, v in pairs(DEFAULTS) do
		out[k] = { v[1], v[2], v[3], v[4] }
	end

	-- The preset sits between the shipped values and the server's, so an owner who has set
	-- a house colour keeps it whichever preset a player picks.
	local preset = activePreset and T.Presets[activePreset]
	if preset and istable(preset.colours) then
		for k, v in pairs(preset.colours) do
			if out[k] and istable(v) then
				out[k] = { v[1], v[2], v[3], v[4] }
			end
		end
	end

	if istable(serverDefault) then
		for k, v in pairs(serverDefault) do
			if out[k] and istable(v) then
				out[k] = { v[1], v[2], v[3], v[4] }
			end
		end
	end

	return out
end

function T.ResetToDefaults()
	ApplyMetrics(activePreset and T.Presets[activePreset])
	T.Apply(ResolvedDefault())
end

-- Only the entries that actually differ from the resolved default.
--
-- Storing the difference rather than a full snapshot is what keeps a player tracking the
-- server's look: if the owner changes a colour the player never touched, they get the new
-- one. A full snapshot would silently freeze every colour at whatever it was the first
-- time they hit Save.
local function CustomOnly()
	local base = ResolvedDefault()
	local out = {}

	for k, b in pairs(base) do
		local c = T[k]
		if c.r ~= b[1] or c.g ~= b[2] or c.b ~= b[3] or c.a ~= b[4] then
			out[k] = { c.r, c.g, c.b, c.a }
		end
	end

	return out
end

-- Switch preset. nil goes back to the shipped look.
--
-- The player's own edits survive, because they are stored as a difference and re-resolved
-- against the new base -- which is also the one surprising part: a colour they changed to
-- exactly what the old preset had will now read as a deliberate choice and stay put.
function T.SetPreset(id)
	if id and not T.Presets[id] then return false end

	local custom = CustomOnly()
	activePreset = id

	local preset = id and T.Presets[id]

	ApplyMetrics(preset)
	ApplyServerMetrics()
	ApplyStyles(preset)

	-- Offsets first, and unconditionally: leaving a preset, or moving between two of them,
	-- must not inherit the relationships the previous one measured.
	RestoreShippedOffsets()

	-- Write, then re-measure, then sync -- in that order.
	--
	-- The shipped offsets were measured against a dark palette. A light preset that sets, say,
	-- CategoryIdleBorder by hand would otherwise have it recomputed as fill + 30 a moment
	-- later, which on a 232 fill clamps to white and disappears. Re-measuring makes the
	-- preset's own value the relationship, so the sync below reproduces it exactly and any
	-- later move of the base still carries it along.
	WriteColours(ResolvedDefault())

	if preset and istable(preset.colours) then
		for k in pairs(preset.colours) do
			if DERIVED[k] then T.RemeasureDerived(k) end
		end
	end

	T.SyncDerived()

	-- The player's own edits go on last, as always. Safe to use the syncing Apply here: the
	-- offsets are correct by this point.
	T.Apply(custom)

	hook.Run("PS_PresetChanged", id)
	return true
end

-- Where each panel was last dragged to, keyed by panel. Lives in this file rather than one
-- of its own because it is the same thing: the client's own record of how they like the UI.
-- One store means one place to look and one thing to reset.
T.Panels = {}

-- The palette exactly as it looks right now, in the shape Apply and the server default
-- both take. Walks DEFAULTS rather than T so the style tables and painters that live on
-- the same table are not walked into.
function T.Snapshot()
	local out = {}
	for k in pairs(DEFAULTS) do
		local c = T[k]
		out[k] = { c.r, c.g, c.b, c.a }
	end
	return out
end

-- The sizing metrics only, for an owner pushing a house size without pushing every other
-- number a look happens to have set.
local FRAME_KEYS = {
	"FrameWScale", "FrameWOffset", "FrameWMin", "FrameWMax",
	"FrameHScale", "FrameHOffset", "FrameHMin", "FrameHMax",
}

-- Reads the BASE, not T.Metrics.
--
-- T.Metrics holds values already multiplied by this client's screen scale. Sending
-- those as a server default would bake one owner's monitor into everyone else's shop,
-- and then scale them a second time on arrival -- an owner on 1440p would hand every
-- player a window a third too large, and a 4K owner two thirds.
function T.FrameMetrics()
	local out = {}
	for _, k in ipairs(FRAME_KEYS) do out[k] = METRIC_BASE[k] end
	return out
end

-- Authored value of one metric, for a UI that edits it. Editors must read and write
-- the base: writing T.Metrics works until the next Rescale silently reverts it.
function T.BaseMetric(k)
	return METRIC_BASE[k]
end

function T.SetBaseMetric(k, v)
	if METRIC_DEFAULTS[k] == nil or not isnumber(v) then return end
	METRIC_BASE[k] = v
	T.Rescale()
end

function T.Save()
	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end

	file.Write(DATA_PATH, util.TableToJSON({
		defaults = ResolvedDefault(),
		custom   = CustomOnly(),
		panels   = T.Panels,
		preset   = activePreset,
	}, true))
end

-- Writes ONLY the panel positions, leaving whatever palette is on disk alone.
--
-- Not T.Save(), which would commit the live palette -- and the live palette can be an
-- unsaved experiment, since the appearance menu applies edits immediately and only persists
-- them on Save. Dragging a window should not decide that.
function T.SavePanels()
	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end

	local disk = {}
	if file.Exists(DATA_PATH, "DATA") then
		local ok, tbl = pcall(util.JSONToTable, file.Read(DATA_PATH, "DATA") or "")
		if ok and istable(tbl) then disk = tbl end
	end

	disk.panels = T.Panels
	file.Write(DATA_PATH, util.TableToJSON(disk, true))
end

-- Reapplies all three layers from scratch. Called on load and whenever the server's default
-- arrives or changes, so a new server default reaches every colour the player has not
-- personally overridden.
function T.Load()
	T.Apply(DEFAULTS)

	if istable(serverDefault) then T.Apply(serverDefault) end

	if not file.Exists(DATA_PATH, "DATA") then return end

	local raw = file.Read(DATA_PATH, "DATA")
	if not raw or raw == "" then return end

	local ok, tbl = pcall(util.JSONToTable, raw)
	if not (ok and istable(tbl)) then
		ErrorNoHalt("[PointShop] Could not parse " .. DATA_PATH .. ", using defaults.\n")
		return
	end

	-- Preset first: it is a layer under `custom`, so it has to be in place before the
	-- player's own edits are resolved against it.
	--
	-- Silently ignored if the preset no longer exists -- an addon that registered one may
	-- have been removed, and that should give the player the shipped look rather than an
	-- error every time the shop opens.
	if isstring(tbl.preset) then
		if T.Presets[tbl.preset] then
			activePreset = tbl.preset
			ApplyMetrics(T.Presets[activePreset])
			ApplyServerMetrics()
			T.Apply(ResolvedDefault())
		else
			-- Not registered yet, or gone. Held for RegisterPreset to pick up; if nothing
			-- ever claims it the player just gets the shipped look, which is the right
			-- outcome for a preset whose addon was removed.
			pendingPreset = tbl.preset
		end
	end

	-- Only `custom` is applied. The `defaults` section in the file is a record of what the
	-- player was customising away from - applying it would pin them to a stale copy of a
	-- server default that has since moved on.
	T.Apply(tbl.custom)

	if istable(tbl.panels) then T.Panels = tbl.panels end
end

-- The server's house look: colours, and now sizes.
--
-- Two accepted shapes, because the old one is already on disk on live servers:
--
--   { FrameBG = {...}, Accent = {...} }                  legacy, colours at the top level
--   { colours = { ... }, metrics = { ... } }             current
--
-- Told apart by the presence of a `colours` key, which no palette can collide with since
-- every colour key is capitalised. A server that never upgrades keeps working untouched.
--
-- Metrics are a separate concern from the colour layering below them: the palette resolves
-- through DEFAULTS -> preset -> serverDefault -> custom because a player edits colours, but
-- nobody edits a metric per-player yet, so the server's sizes simply sit on top of whatever
-- the preset asked for.
function T.SetServerDefault(tbl)
	if not istable(tbl) then return end

	if istable(tbl.colours) then
		serverDefault = tbl.colours
		serverMetrics = istable(tbl.metrics) and tbl.metrics or nil
	else
		serverDefault = tbl
		serverMetrics = nil
	end

	T.Load()

	-- Again, unconditionally. T.Load applies these inside its saved-preset branch, but it
	-- early-returns when the player has no theme.json at all and never reaches it -- which
	-- is every player on their first join, exactly the ones a house size is for.
	ApplyServerMetrics()

	-- Sizes are applied to panels when they are built, so anything already open is still
	-- holding the old ones. Same signal a preset change sends, for the same reason.
	hook.Run("PS_PresetChanged", activePreset)
end

T.Rescale()
T.Load()

-- A player changing video settings changes the scale, and every panel already built is
-- holding sizes from the old resolution. Cheap to watch: two comparisons a frame, and the
-- work only happens on an actual change.
local lastW, lastH = ScrW(), ScrH()
hook.Add("Think", "PS_ThemeWatchResolution", function()
	if ScrW() == lastW and ScrH() == lastH then return end
	lastW, lastH = ScrW(), ScrH()

	T.Rescale()
	hook.Run("PS_PresetChanged", T.GetPreset())
end)

net.Receive("PS_Theme_Default", function()
	local ok, tbl = pcall(util.JSONToTable, net.ReadString())
	if ok and istable(tbl) then T.SetServerDefault(tbl) end
end)
