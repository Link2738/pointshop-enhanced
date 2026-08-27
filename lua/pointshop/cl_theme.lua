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

-- The appearance editor's options column: a box, with its own colour and its own edge.
--
-- Its own entry rather than PanelBG, because PanelBG is ALSO what the appearance window
-- itself paints with -- so a box painted in it is invisible against the thing it sits on,
-- by construction. A box needs a colour nothing around it shares.
--
-- Ships as the window body with a fully transparent edge, which is what the column looked
-- like before it was a box at all: unchanged on the shipped theme, a real box for any look
-- that gives it a value.
T.ListBG     = Color(40, 40, 45, 255)
T.ListBorder = Color(0, 0, 0, 0)

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
	-- 915 wide, and as tall as the screen less 200.
	--
	-- Two different shapes on purpose. Width is fixed because a shop wider than about this
	-- stops being scannable -- the eye has to travel a row it cannot take in. Height is an
	-- inset because vertical space is the thing a taller screen actually has more of, and a
	-- longer grid is straightforwardly more useful.
	--
	-- These eight are NOT scaled -- they are the size the player asked for, and everything
	-- else is measured against the width they produce. See T.Scale.
	FrameWScale  = 0,
	FrameWOffset = 915,
	FrameWMin    = 640,
	FrameWMax    = 1400,

	FrameHScale  = 1,
	FrameHOffset = -200,
	FrameHMin    = 600,
	FrameHMax    = 900,

	-- ========================================================================
	-- SCALING
	--
	-- Every number above is authored against a shop RefW pixels wide, and multiplied by
	-- actualWidth/RefW at runtime. 915 is the shipped default width, so a player who never
	-- touches the size gets exactly the values written here.
	--
	-- The window is the reference, not the screen. Someone who makes their shop bigger wants
	-- bigger buttons and text in it; someone who keeps it at 915 on a 4K monitor asked for a
	-- 915 window and gets normally proportioned controls in it. Resolution reaches this only
	-- through a size that was chosen as a share of the screen -- which is the case where
	-- following the monitor is the point.
	--
	-- The clamps stop both extremes: below ScaleMin the text stops being readable, above
	-- ScaleMax the chrome eats the content it is wrapped around.
	-- ========================================================================
	RefW     = 915,
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

-- Whether the appearance editor reveals the derived variants.
--
-- Declared here rather than springing into existence the first time the editor's checkbox is
-- ticked. It lives on the theme table and is read by BuildShopSections, so the theme file is
-- the wrong place for it to be undeclared -- nil happens to be the right default, which is
-- exactly why nobody noticed it had no home.
T.ShowAdvanced = false

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

-- T.IsDerived(key) lived here and nothing ever called it. The editor asks PS.Theme.Derived
-- directly, which is the set it was wrapping.

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

-- Text drawn on top of a fill, rather than on a body surface.
--
-- Two entries, not one. They were briefly the same token and that was wrong: a button's
-- fill is a saturated action colour picked for its meaning, while an item card's name strip
-- is a quiet surface picked to sit under a model. One value cannot be right on both -- white
-- on a green Confirm button is correct and white on a pale grey name strip is invisible.
--
-- Both ship white, which is what the single token was, so the shipped look is unmoved.
T.ButtonText = Color(255, 255, 255, 255)   -- on Positive / Warning / Accent / Modify fills
T.CardText   = Color(255, 255, 255, 255)   -- item name strip and the price badge

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
		border = T.PositiveBorder, text = T.ButtonText, shadow = T.ShadowStrong,
	},
	Warning = {
		radius = "RadiusSm", lerp = 10, font = "PS_Default",
		fill = T.WarningFill, fillHover = T.WarningFillHover,
		gloss = T.WarningGloss, glossHover = T.WarningGlossHover,
		border = T.WarningBorder, text = T.ButtonText, shadow = T.Shadow,
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
		border = T.ModifyBorder, text = T.ButtonText, shadow = T.Shadow,
	},
	Accent = {
		radius = "RadiusMd", lerp = 10, font = "PS_Default",
		fill = T.AccentFill, fillHover = T.AccentFillHover,
		gloss = T.AccentGloss, glossHover = T.AccentGlossHover,
		glow = T.AccentGlow, glowLayers = { 100 },
		border = T.AccentBorder, text = T.ButtonText, shadow = T.Shadow,
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
-- The options column in the appearance editor. Box, then edge.
function T.PaintListBox(w, h)
	draw.RoundedBox(T.Metrics.RadiusSm, 0, 0, w, h, T.ListBG)

	if T.ListBorder.a > 0 then
		surface.SetDrawColor(T.ListBorder)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
end

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

-- Never scaled.
--
-- The frame metrics because they ARE the scale's input -- scaling them by a number derived
-- from themselves is circular, and the window is the size the player asked for, not a size
-- to then adjust. Column counts because they are counts. The scale controls for the obvious
-- reason.
local UNSCALED = {
	FrameWScale = true, FrameWOffset = true, FrameWMin = true, FrameWMax = true,
	FrameHScale = true, FrameHOffset = true, FrameHMin = true, FrameHMax = true,

	CategoryMinCols = true, CategoryMaxCols = true,
	CardMinCols = true, CardMaxCols = true,

	RefW = true, ScaleMin = true, ScaleMax = true,
}

-- How big everything is, relative to the window it is in.
--
-- Taken from the shop's WIDTH, not the screen's height. A player sets the window size they
-- want and the buttons, text and boxes follow it -- which is what "bigger window" means to
-- the person asking for one, and it removes resolution from the question entirely.
--
-- Screen resolution still reaches this, just indirectly and only when asked for: a window set
-- to a share of the screen gets wider on a bigger monitor and everything in it grows to suit,
-- while a window set to a fixed 915 stays 915 with normal-sized controls on any monitor. Both
-- are what was asked for.
--
-- Width rather than height because the width is what the grids divide, and because the
-- shipped default width is a plain number while the default height is screen-derived -- a
-- reference has to be something that does not move.
--
-- Reads the BASE, so nothing here depends on the scaled output.
function T.Scale()
	local ref = METRIC_BASE.RefW
	if not ref or ref <= 0 then return 1 end

	local w = math.Clamp(
		ScrW() * METRIC_BASE.FrameWScale + METRIC_BASE.FrameWOffset,
		METRIC_BASE.FrameWMin, METRIC_BASE.FrameWMax)

	local s = math.Clamp(math.min(w, ScrW()) / ref,
		METRIC_BASE.ScaleMin or 0.5, METRIC_BASE.ScaleMax or 3)

	-- Quantised to 5% steps.
	--
	-- The scale used to move only when the monitor did, which is rare. It now moves whenever
	-- the window width does -- so dragging a size slider would produce a different scale on
	-- every tick, and every one of those rebuilds eleven fonts. That is the per-frame
	-- surface.CreateFont problem arriving through a new door.
	--
	-- Steps make it a staircase instead: a drag crosses a handful of values rather than
	-- hundreds, fonts rebuild a handful of times, and the sizes in between were sub-pixel
	-- differences nobody could see anyway.
	return math.Round(s * 20) / 20
end

-- Writes the scaled values into T.Metrics IN PLACE.
--
-- In place for the same reason everything else here is: panels take
-- `local M = PS.Theme.Metrics` and hold that reference, so replacing the table would leave
-- them reading the old one forever.
--
-- Rounded, because these become panel sizes and positions, and a control on a half pixel
-- smears its own border.
-- The scale the fonts were last built at. nil until the first build.
local lastFontScale = nil

function T.Rescale()
	local s = T.Scale()

	for k, v in pairs(METRIC_BASE) do
		if UNSCALED[k] then
			T.Metrics[k] = v
		else
			T.Metrics[k] = math.Round(v * s)
		end
	end

	-- Text is sized in pixels too, so it moves with everything else -- but ONLY when the
	-- scale actually changed.
	--
	-- Rescale runs on every metric write, and a metric write happens on every tick of a
	-- slider drag and eight times over when the layout panel restores on close. Rebuilding
	-- eleven fonts each time is exactly what BuildFonts documents as the thing never to do:
	-- surface.CreateFont is not cheap and re-creating fonts at frame rate leaves the UI
	-- drawing with handles that are being replaced underneath it.
	--
	-- The scale only moves when the window size does, so almost every Rescale skips this.
	if s ~= lastFontScale and T.BuildFonts then
		lastFontScale = s
		T.BuildFonts()
	end
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
-- Metrics the player has changed by hand, as a difference from what the preset gives.
--
-- Same shape and same reasoning as `custom` for colours: storing only the difference means
-- a player who set a window width still tracks every other change a look or an owner makes,
-- instead of freezing a whole snapshot at the moment they touched one slider.
local customMetrics = {}

-- Declared here, assigned further down where the server default lives. ApplyMetrics has to
-- be able to lay the house sizes down BETWEEN the shipped values and the preset's, and it is
-- defined above that code.
local serverMetrics = nil
local ApplyServerLayer

-- Order is shipped defaults, then the server's house size, then the look, then the player.
--
-- The house size was applied AFTER all of this, which meant it did not fill in a size for a
-- look that had no opinion -- it overrode every look that did. An owner who saved a size
-- while sitting on Classic gave Classic's window to Default as well, and switching between
-- the two changed the colours and left the geometry where it was.
--
-- A house size is what you get before choosing; choosing is more specific, so it wins.
local function ApplyMetrics(preset)
	for k, v in pairs(METRIC_DEFAULTS) do METRIC_BASE[k] = v end

	if ApplyServerLayer then ApplyServerLayer() end

	if preset and istable(preset.metrics) then
		for k, v in pairs(preset.metrics) do
			if METRIC_DEFAULTS[k] ~= nil and isnumber(v) then METRIC_BASE[k] = v end
		end
	end

	-- The player's own edits sit above the preset, the way custom colours do.
	for k, v in pairs(customMetrics) do
		if METRIC_DEFAULTS[k] ~= nil and isnumber(v) then METRIC_BASE[k] = v end
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

-- The house size for the look currently selected.
--
-- Stored per look, because a size is only meaningful next to the look it was chosen for. It
-- was stored globally, so an owner tuning Classic's window and saving handed that window to
-- Default as well -- and the only way back was a console command, which is not a fix, it is
-- an apology.
function ApplyServerLayer()
	if not istable(serverMetrics) then return end

	local mine = serverMetrics[activePreset or ""]
	if not istable(mine) then return end

	for k, v in pairs(mine) do
		if METRIC_DEFAULTS[k] ~= nil and isnumber(v) then
			local b = METRIC_BOUNDS[k]
			METRIC_BASE[k] = b and math.Clamp(v, b[1], b[2]) or v
		end
	end

	-- A max below its min would make math.Clamp return the max and silently inverts the
	-- intent, so the pair is straightened rather than obeyed.
	if METRIC_BASE.FrameWMax < METRIC_BASE.FrameWMin then METRIC_BASE.FrameWMax = METRIC_BASE.FrameWMin end
	if METRIC_BASE.FrameHMax < METRIC_BASE.FrameHMin then METRIC_BASE.FrameHMax = METRIC_BASE.FrameHMin end
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

-- The owner's colours, per look: { [""] = {...}, classic = {...} }.
--
-- Per look for the same reason the sizes are. An owner editing Classic is editing Classic,
-- not declaring a palette for every look on the server -- which is what a single table did,
-- and it meant a house palette saved while sitting on the default look painted itself over
-- Classic on every client that connected.
local serverDefault = nil

-- What the owner has published for the look currently selected, or nil.
local function ServerColoursForLook()
	if not istable(serverDefault) then return nil end

	local mine = serverDefault[activePreset or ""]
	return istable(mine) and mine or nil
end

-- Layers 1 and 2 together: what this player sees before any of their own choices. This is
-- what "reset" means and what `custom` is measured against.
local function ResolvedDefault()
	local out = {}
	for k, v in pairs(DEFAULTS) do
		out[k] = { v[1], v[2], v[3], v[4] }
	end

	-- The look's own definition, then the owner's edits to THAT look on top.
	--
	-- Both are about the same look now, so the order between them is simply
	-- shipped-then-changed: the file says what Classic is, the owner says how this server's
	-- Classic differs, and a player's own edits go above both in SetPreset.
	--
	-- It used to be one house palette applied to every look, ordered before them. That is why
	-- an owner saving while on the default look published the default look and painted it over
	-- Classic on every client that connected -- a whole palette does not tint a look, it
	-- replaces one.
	local preset = activePreset and T.Presets[activePreset]
	if preset and istable(preset.colours) then
		for k, v in pairs(preset.colours) do
			if out[k] and istable(v) then
				out[k] = { v[1], v[2], v[3], v[4] }
			end
		end
	end

	local house = ServerColoursForLook()
	if house then
		for k, v in pairs(house) do
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
-- ============================================================================
-- THE THREE LOOKS
--
-- Default and Classic are READ ONLY. Nothing a player does alters them, so picking one
-- always produces exactly that look, on any machine, at any time.
--
-- Custom is the single writable slot. Editing anything while on a read-only look does not
-- refuse and does not silently modify it -- it copies what is currently on screen into
-- Custom and switches you there, so the edit lands somewhere it is allowed to live and you
-- carry on from the look you were already looking at.
--
-- Custom holds a WHOLE palette rather than a difference from something. A difference only
-- means anything relative to a base, and this one is seeded from whichever look you happened
-- to be on -- so storing a diff would leave a palette that changes meaning depending on what
-- was selected when you saved it.
-- ============================================================================

local CUSTOM = "custom"

local customPalette = nil   -- colour entries, or nil when nothing has been customised
local customFrame   = nil   -- the frame metrics that went with it

-- Which look Custom was seeded from this session, if it was seeded this session. Only used
-- to decide whether saving needs to warn about replacing what is already stored.
local seededFrom = nil

function T.CustomExists() return customPalette ~= nil end
function T.CustomWasSeeded() return seededFrom ~= nil end
-- CustomOnly() lived here: it measured the palette's difference from the resolved base.
-- Custom now stores a whole palette rather than a difference, because a difference only
-- means something relative to a base and Custom is seeded from whichever look you were on.

-- Called before any edit lands.
--
-- If the current look is read-only, this copies what is on screen into Custom and switches
-- there, so the edit has somewhere legal to go and the player continues from the look they
-- were already looking at rather than being dumped onto a blank palette.
--
-- Returns true if it moved, so a caller can tell the player why the selector just changed
-- under them.
function T.BeginEdit()
	if activePreset == CUSTOM then return false end

	-- The owner is editing this look for the server, so the edit belongs to the look and is
	-- not diverted anywhere. Publishing it is a separate, deliberate act.
	if T.EditingLook then return false end

	seededFrom   = activePreset or ""
	customPalette = T.Snapshot()
	customFrame   = T.FrameMetrics()
	activePreset  = CUSTOM

	-- No repaint needed: the palette already holds exactly these values, which is the point
	-- of seeding from them. Only the selector and anything watching the look need telling.
	hook.Run("PS_PresetChanged", CUSTOM)
	return true
end
-- Switch look. nil goes back to the shipped one.
--
-- Each look keeps its own customisations. Leaving one files the current edits under its
-- name; arriving at another unpacks whatever was filed under that one, or nothing if it has
-- never been touched -- which is what makes a freshly chosen look actually look like itself.
-- Going back returns the edits you left there.
function T.SetPreset(id)
	-- CUSTOM is a slot rather than a registered preset, so it is not in T.Presets.
	if id and id ~= CUSTOM and not T.Presets[id] then return false end

	activePreset = id

	-- Choosing a look explicitly ends any seeded session: from here on Custom is whatever is
	-- stored, not something derived from where you happened to be.
	seededFrom = nil

	-- Only Custom carries edits. The read-only looks take none, which is what makes them
	-- reproducible.
	local custom = {}
	customMetrics = {}

	if id == CUSTOM then
		custom = customPalette or {}
		customMetrics = customFrame and table.Copy(customFrame) or {}
	end

	local preset = id ~= CUSTOM and id and T.Presets[id] or nil


	ApplyMetrics(preset)
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

-- Sets one metric on the look that is currently selected.
--
-- A size is NOT a palette edit, and treating it as one is what made adjusting Classic's
-- window turn it into Default. It went through BeginEdit, which switches the active look to
-- Custom -- and Custom has no preset colour layer, so the instant a size slider moved,
-- Classic's colours stopped being applied. Moving a window edge changed the theme.
--
-- The two are edited from different places by different people for different reasons: colours
-- from the appearance panel by any player, sizes from the owner's layout panel. Only the
-- first has any business converting anyone to Custom.
--
-- Recorded in customMetrics so the change survives a rescale, and written to whichever look
-- is selected when the panel saves.
function T.SetBaseMetric(k, v)
	if METRIC_DEFAULTS[k] == nil or not isnumber(v) then return end

	METRIC_BASE[k] = v
	customMetrics[k] = v

	T.Rescale()
end

-- Puts a set of metrics back without recording them as choices, and rescales once.
--
-- Reverting is not editing. Writing a revert through SetBaseMetric marked every restored
-- value as a deliberate customisation -- so cancelling out of the layout panel left the size
-- pinned as if it had been chosen, above whatever the preset said. It also rescaled once per
-- key, eight times for a frame size, each one a full pass over every metric.
function T.RestoreBaseMetrics(tbl)
	if not istable(tbl) then return end

	for k, v in pairs(tbl) do
		if METRIC_DEFAULTS[k] ~= nil and isnumber(v) then
			METRIC_BASE[k] = v
			customMetrics[k] = nil
		end
	end

	T.Rescale()
end

-- Reads what is on disk, so a write can change one part of it.
local function ReadStored()
	if not file.Exists(DATA_PATH, "DATA") then return {} end

	local raw = file.Read(DATA_PATH, "DATA")
	if not raw or raw == "" then return {} end

	local ok, tbl = pcall(util.JSONToTable, raw)
	return (ok and istable(tbl)) and tbl or {}
end

-- Writes the file back with `changes` applied over what was already there.
--
-- Every save goes through here, and every save names only the keys it is about. Sizes and
-- colours live in one file and must not disturb each other: saving a window size rewriting
-- the palette is not a hypothetical, it is what deleted one.
local function WriteStored(changes)
	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end

	local stored = ReadStored()
	for k, v in pairs(changes) do stored[k] = v end

	file.Write(DATA_PATH, util.TableToJSON(stored, true))
end

-- Colours only.
function T.SaveColours()
	if activePreset == CUSTOM then
		customPalette = T.Snapshot()
		seededFrom    = nil
	end

	WriteStored({
		custom   = customPalette,

		-- The look the player has chosen travels with the palette, because it is what decides
		-- which palette applies. Sizes have no opinion about it.
		preset   = activePreset,

		-- A record of what the customs were measured against. Never applied on load; kept so
		-- a palette can be read by eye against the base it came from.
		defaults = ResolvedDefault(),
	})
end

-- Sizes only.
function T.SaveMetrics()
	if activePreset == CUSTOM then
		customFrame = T.FrameMetrics()
	end

	WriteStored({ metrics = customFrame })
end

-- Both. Kept because the appearance panel's Save means "commit what I am looking at", which
-- is the whole thing -- but it is still two section writes rather than one whole-file write,
-- so it cannot clear anything it does not name.
function T.Save()
	T.SaveColours()
	T.SaveMetrics()
end

-- Writes ONLY the panel positions, leaving whatever palette is on disk alone.
--
-- Not T.Save(), which would commit the live palette -- and the live palette can be an
-- unsaved experiment, since the appearance menu applies edits immediately and only persists
-- them on Save. Dragging a window should not decide that.
function T.SavePanels()
	WriteStored({ panels = T.Panels })
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
	-- The Custom slot: a whole palette, filtered to keys that still exist.
	if istable(tbl.custom) then
		customPalette = {}
		for k, v in pairs(tbl.custom) do
			if DEFAULTS[k] and istable(v) then customPalette[k] = v end
		end
		if not next(customPalette) then customPalette = nil end
	end

	if istable(tbl.metrics) then
		customFrame = {}
		for k, v in pairs(tbl.metrics) do
			if METRIC_DEFAULTS[k] ~= nil and isnumber(v) then customFrame[k] = v end
		end
		if not next(customFrame) then customFrame = nil end
	end
	-- The saved look. SetPreset does the whole job -- picks the layers, applies the Custom
	-- slot if that is what was selected, and leaves the read-only looks untouched by it.
	if isstring(tbl.preset) then
		if tbl.preset == CUSTOM or T.Presets[tbl.preset] then
			T.SetPreset(tbl.preset)
		else
			-- Not registered yet, or gone. Held for RegisterPreset to pick up; if nothing
			-- ever claims it the player just gets the shipped look, which is the right
			-- outcome for a preset whose addon was removed.
			pendingPreset = tbl.preset
		end
	end

	if istable(tbl.panels) then T.Panels = tbl.panels end
end

-- What the owner has published: per-look colours, per-look sizes, and the icon offsets.
--
--   { colours = { [""] = {...}, classic = {...} },
--     metrics = { [""] = {...}, classic = {...} } }
--
-- An ABSENT section means "leave that alone", never "clear it": a panel sends the sections it
-- is about, so the layout panel saving a size must not delete the palette. An EMPTY section
-- is a clear, which is the difference that lets one be undone.
--
-- Colours and sizes are keyed by look. Unkeyed entries are dropped rather than guessed at:
-- there is no way to know which look they were authored on, and applying them to every look
-- is precisely the bug the keying fixes.
local function KeyedByLook(tbl)
	local out = {}
	for k, v in pairs(tbl) do
		if isstring(k) and istable(v) then out[k] = v end
	end
	return next(out) and out or nil
end

function T.SetServerDefault(tbl)
	if not istable(tbl) then return end

	if istable(tbl.colours) then serverDefault = KeyedByLook(tbl.colours) end
	if istable(tbl.metrics) then serverMetrics = KeyedByLook(tbl.metrics) end

	T.Load()

	-- Unconditionally. T.Load applies metrics inside its saved-look branch, but it early-
	-- returns for a player with no theme.json at all and never reaches it -- which is every
	-- player on their first join, exactly the ones a house size is for.
	ApplyMetrics(activePreset and T.Presets[activePreset] or nil)

	-- Sizes are applied to panels when they are built, so anything already open is still
	-- holding the old ones. Same signal a preset change sends, for the same reason.
	hook.Run("PS_PresetChanged", activePreset)
end

T.Rescale()
T.Load()

-- ============================================================================
-- AUTHORING A LOOK
--
-- An owner edits a look and publishes it. There is no console command and nothing gets
-- pasted back into source: a look's colours are owner data, and this addon already keeps
-- owner data in data/ behind a gated net message. This is that, for looks.
--
-- Two console commands used to do this job -- one to make edits land on the selected look
-- instead of diverting to Custom, one to print the result for hand-copying into a file. The
-- printing was the tell. A value nobody can save is not configuration, and the paste step
-- was the absence of persistence dressed up as a safety property.
-- ============================================================================

-- While true, edits apply to the selected look rather than moving the player to Custom.
--
-- Set by the appearance panel's owner-only toggle, never persisted: it describes what the
-- person at the keyboard is doing right now, not anything about the server.
T.EditingLook = false

-- What this client has changed the current look to, as a difference from the shipped
-- definition. This is what gets published.
--
-- The difference, not the whole palette: a look file restating every default cannot inherit a
-- later change to one, and ninety-odd values would bury the six that were actually moved.
function T.LookOverrides()
	local out = {}

	local shipped = {}
	for k, v in pairs(DEFAULTS) do shipped[k] = v end

	local preset = activePreset and T.Presets[activePreset]
	if preset and istable(preset.colours) then
		for k, v in pairs(preset.colours) do
			if shipped[k] then shipped[k] = v end
		end
	end

	for k, base in pairs(shipped) do
		local c = T[k]
		if c.r ~= base[1] or c.g ~= base[2] or c.b ~= base[3] or c.a ~= base[4] then
			out[k] = { c.r, c.g, c.b, c.a }
		end
	end

	return out
end

-- Publishes this look's overrides to the server, for everyone.
--
-- Keyed by the look being edited, so editing Classic changes this server's Classic and leaves
-- every other look alone.
function T.PublishLook()
	net.Start("PS_Theme_SetDefault")
		net.WriteString(util.TableToJSON({
			colours = { [activePreset or ""] = T.LookOverrides() },
		}))
	net.SendToServer()
end


-- A resolution change still matters, but only for the sizes that ask about the screen.
--
-- A window set to a fixed width does not move when the monitor changes, and neither does
-- anything measured against it. A window set to a share of the screen does, and everything in
-- it has to follow -- so this rescales and reflows rather than trying to work out which case
-- it is.
--
-- Cheap to watch: two comparisons a frame, and the work only happens on an actual change.
local lastW, lastH = ScrW(), ScrH()
hook.Add("Think", "PS_ThemeWatchResolution", function()
	if ScrW() == lastW and ScrH() == lastH then return end
	lastW, lastH = ScrW(), ScrH()

	T.Rescale()
	hook.Run("PS_PresetChanged", T.GetPreset())
end)

-- ============================================================================
-- SERVER THEME, CACHED AND HASH-CHECKED
--
-- The server's canonical sizes and colours change rarely and are identical for everyone, so
-- sending them to every player on every join is a transfer whose usual result is "you already
-- had this". Instead the server offers a hash; a client whose cache matches says nothing.
--
-- The cache is a plain file. Corruption, truncation, or an owner changing something all show
-- up the same way -- the hash does not match -- and are answered the same way, by asking for
-- the real thing.
-- ============================================================================

local CACHE_PATH = "pointshop/theme_server.json"

local function ReadCache()
	if not file.Exists(CACHE_PATH, "DATA") then return nil end

	local raw = file.Read(CACHE_PATH, "DATA")
	if not raw or raw == "" then return nil end

	local ok, tbl = pcall(util.JSONToTable, raw)
	return (ok and istable(tbl)) and tbl or nil
end

local function WriteCache(tbl)
	if not file.IsDir("pointshop", "DATA") then file.CreateDir("pointshop") end
	file.Write(CACHE_PATH, util.TableToJSON(tbl))
end

-- The server has told us what it holds. Use what we have, or ask.
net.Receive("PS_Theme_Hash", function()
	local wanted = net.ReadString()

	-- Empty means the server publishes nothing. The cache has to be cleared for that, or a
	-- theme an owner has since removed would outlive the removal on every client that still
	-- had it on disk.
	if wanted == "" then
		if file.Exists(CACHE_PATH, "DATA") then file.Delete(CACHE_PATH) end
		return
	end

	local cached = ReadCache()
	if cached and PS.ThemeSync.Hash(cached) == wanted then
		T.SetServerDefault(cached)
		return
	end

	net.Start("PS_Theme_Request")
	net.SendToServer()
end)

-- The payload itself: either the answer to the request above, or pushed because an owner
-- just changed something.
net.Receive("PS_Theme_Default", function()
	local ok, tbl = pcall(util.JSONToTable, net.ReadString())
	if not (ok and istable(tbl)) then return end

	WriteCache(tbl)
	T.SetServerDefault(tbl)
end)
