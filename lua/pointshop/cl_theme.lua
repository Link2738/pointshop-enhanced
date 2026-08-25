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

T.PanelBG   = Color(30, 30, 35, 255)   -- panel body
T.StatusBar = Color(20, 40, 60)        -- status strip gradient base

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

-- Dismiss / cancel
T.NeutralFill       = Color(65, 65, 65, 255)
T.NeutralFillHover  = Color(80, 80, 80, 255)
T.NeutralGloss      = Color(80, 80, 80, 80)
T.NeutralGlossHover = Color(95, 95, 95, 80)
T.NeutralBorder     = Color(120, 120, 120, 200)
T.NeutralText       = Color(220, 220, 220, 255)

-- ============================================================================
-- TEXT
-- ============================================================================

T.Text         = Color(255, 255, 255, 255)
T.TextDim      = Color(200, 220, 255)   -- status strip, section labels
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
