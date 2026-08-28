--[[
	pointshop/cl_theme_classic.lua

	The PointShop 1 look, as a preset.

	PS1 IS A LIGHT SHOP. Worth stating flatly, because reading its source misleads: the frame's
	own Paint fills 40,40,40 and then a docked container paints 232,232,232 over essentially
	all of it, so the dark is a substrate that never reaches the screen. Every visible surface
	is light. The only dark thing in the window is the header bar.

	Values below come from a screenshot of the real thing plus
	pointshop-1.3.2/lua/pointshop/vgui/DPointShopMenu.lua for the exact numbers. Line refs
	point into that file.

		header bar     52,73,94     slate, 48 tall, white text     (:458-459, :462)
		everything else 232,232,232 light grey                     (:107)
		cards          near-white with a thin grey outline
		outline        218,218,218                                 (:127)
		tab text       140 idle / 120 hover / 105 active           (:136-138)
		active tab     3px slate underline, no fill                (:131-132)
		corners        square -- every surface is DrawRect

	The preview pane is light too. An earlier read of the DockMargin(0,0,320,0) at :91
	suggested a dark strip on the right; the screenshot shows it is the same grey as the body,
	separated by a hairline.
]]--

local T = PS.Theme

-- The one saturated colour in the whole window. Header fill, active-tab underline, and
-- anything that needs to read as "selected".
local SLATE     = {  52,  73,  94, 255 }
local SLATE_HI  = {  72,  99, 126, 255 }

-- The same blue carried down into the light half of the theme.
--
-- SLATE_PALE is the header's hue at high lightness, so the scrollbar's backing box reads
-- as belonging to the header rather than as another grey. SLATE_MID sits between them for
-- the grip, which has to be visible against the pale box without matching the header and
-- looking like a piece of it that came loose.
local SLATE_PALE = { 198, 210, 222, 255 }
-- Softer again, for large areas. A panel filling half the window at the track's saturation
-- stops being a tint and becomes the theme's main colour.
local SLATE_TINT = { 218, 227, 236, 255 }
local SLATE_MID  = { 112, 136, 160, 255 }

-- A light theme has no glow and no sheen to separate its surfaces, so the separation has to
-- come from tone and from lines. A first pass put five surfaces between 232 and 250 -- a 7%
-- spread -- and the panel read as one white sheet with text floating on it.
--
-- So: a ladder with real steps, recessed to raised, and outlines dark enough to be seen.
-- PS1's own 218 line was drawn on its 232 body and is genuinely faint; it gets away with it
-- because it has almost no nested panels. Ours has rows inside panels inside frames, and at
-- that depth a 6% line is not a line.
local BODY      = { 226, 226, 226, 255 }   -- window ground (:107 is 232, one step up from here)
local RAISED    = { 236, 236, 236, 255 }   -- panel bodies and list rows sitting on the ground
local CARD      = { 250, 250, 250, 255 }   -- the top of the stack
local OUTLINE   = { 188, 188, 188, 255 }   -- PS1 used 218; too faint once panels nest
local OUTLINE_HI = { 160, 160, 160, 255 }

-- PS1's text is grey on grey, never black. Three weights, from :136-138.
local INK       = { 105, 105, 105, 255 }   -- active / primary
local INK_MID   = { 120, 120, 120, 255 }   -- hover
local INK_SOFT  = { 140, 140, 140, 255 }   -- idle

T.RegisterPreset("classic", {
	name = "Classic",

	metrics = {
		-- 800x640 at the reference resolution.
		--
		-- A fixed size rather than a share of the screen, because that is what this look is --
		-- the same box on every monitor. It still grows with the screen: every metric is
		-- multiplied by ScrH()/RefH, so this is 800x640 at 1080p, 1067x853 at 1440p and
		-- 1600x1280 at 2160p. Fixed means fixed in proportion, not fixed in pixels.
		--
		-- The clamps are scaled too, so they are deliberately wide: they exist to stop an
		-- absurd result at the extremes, not to second-guess the size above.
		FrameWScale  = 0,
		FrameWOffset = 800,
		FrameWMin    = 600,
		FrameWMax    = 1600,

		FrameHScale  = 0,
		FrameHOffset = 640,
		FrameHMin    = 320,
		FrameHMax    = 1100,

		HeaderH  = 48,   -- :459
		Radius   = 0,    -- nothing in that file is rounded
		RadiusSm = 0,
		RadiusMd = 0,
		Margin   = 16,   -- title baseline, :462
		IconBtn  = 32,   -- close button, :76-77
		IconInset = 8,   -- close sits at w-40 with a 32 button, :77
		ButtonH  = 28,   -- tab strip, :88

		-- No accent stripe: the header is already the accent colour, so a 3px bar of it on
		-- top of it is three invisible pixels.
		HeaderRule = 0,

		-- PS1's tabs are one row of text-width buttons, not a wrapped grid of wide ones.
		-- Narrower target and a higher column ceiling is how that shape falls out of the same
		-- flow layout.
		CategoryBtnH = 28,
		CategoryW    = 150,
		CategoryMaxCols = 8,

		-- Cards are smaller and tighter than the modern grid's.
		CardW   = 150,
		CardMin = 110,
		CardMax = 160,
	},

	-- The active tab: no fill, a slate bar underneath, and three text weights carrying the
	-- rest. This is the piece that needed PaintSelectable to grow a mode and UI.Tab to stop
	-- hardcoding one text colour -- it is not expressible as a palette entry.
	styles = {
		Category = {
			activeMode = "underline",
			text       = "TabIdle",
			textHover  = "TabHover",
			textActive = "TabActive",
		},
	},

	colours = {
		-- The header keeps its slate and its white text; everything below it goes light.
		HeaderText = { 255, 255, 255, 255 },
		PointsText = { 255, 255, 255, 255 },   -- PS1's balance is white, not yellow (:468)

		FrameBG        = BODY,
		PanelBG        = RAISED,

		-- The options column, as an actual box: slate tint with an edge, sitting on the
		-- grey window body so the two cannot be mistaken for each other.
		ListBG         = SLATE_TINT,
		ListBorder     = OUTLINE,

		-- No alternating stripe in PS1. Rows are the body until hovered.
		RowBG    = RAISED,
		RowAlt   = { 231, 231, 231, 255 },
		RowHover = { 244, 244, 244, 255 },

		-- Body text goes dark, which is the whole reason Text was split from HeaderText.
		Text     = INK,
		TextDim  = INK_SOFT,
		MenuRowText = INK_MID,

		-- Category buttons are light with dark writing here, so their text follows the body
		-- rather than the shipped white. Without this the strip's labels are white on grey.
		CategoryText = INK,

		-- The three tab weights, :136-138. With no fill on the active tab these carry the
		-- selection as much as the underline does.
		TabIdle   = INK_SOFT,
		TabHover  = INK_MID,
		TabActive = INK,

		-- Shadows are for dark themes. On light they read as smudge, so they go to nothing --
		-- alpha 0 rather than removing the draws, since a preset can only move colours.
		Shadow       = { 0, 0, 0, 0 },
		ShadowStrong = { 0, 0, 0, 0 },

		-- The accent stops being blue: PS1 draws the active tab's underline with the header
		-- colour (:131-132), so accent and header are the same slate.
		Accent = SLATE,

		-- Tabs are text on the body with an outline. The "active" state carries the slate,
		-- since PaintSelectable cannot draw an underline yet -- see the note at the bottom.
		CategoryFill   = SLATE,
		CategoryGloss  = {  72,  99, 126, 100 },
		CategoryGlow   = SLATE_HI,
		CategoryBorder = SLATE,

		CategoryIdleFill        = RAISED,
		CategoryIdleFillHover   = { 246, 246, 246, 255 },
		CategoryIdleGloss       = { 255, 255, 255,  40 },
		CategoryIdleGlossHover  = { 255, 255, 255,  70 },
		CategoryIdleBorder      = OUTLINE,
		CategoryIdleBorderHover = OUTLINE_HI,

		SelectFill   = SLATE,
		SelectGloss  = { 100, 130, 160,  80 },
		SelectGlow   = SLATE_HI,
		SelectBorder = SLATE,

		-- Controls are outlined boxes on the body, the way PS1's buttons are.
		ControlFill        = { 242, 242, 242, 255 },
		ControlFillHover   = { 250, 250, 250, 255 },
		ControlGloss       = { 255, 255, 255,  60 },
		ControlGlossHover  = { 255, 255, 255,  90 },
		ControlBorder      = OUTLINE,
		ControlBorderHover = OUTLINE_HI,

		-- Cards are near-white with a hairline. The label strip under each keeps taking its
		-- colour from the item's state (owned / affordable / not), which is where the mauve
		-- in a real PS1 screenshot comes from -- that is CardCantBuy over a light card, not a
		-- label colour, so it is deliberately not overridden here.
		CardBG      = CARD,
		CardBorder  = OUTLINE,
		CardHover   = { 150, 150, 150, 180 },
		-- Mid grey, not light. The label carries CardText, so a strip near the
		-- card's own value leaves the item name invisible -- which is what a 200 strip on a
		-- 250 card did. PS1's own labels were mid-toned for the same reason.
		CardLabelBG = { 150, 150, 150, 255 },

		-- The two text-on-fill entries pull apart here, which is the whole reason they are
		-- separate: the buttons keep white on their saturated colours, while the item name
		-- sits on a quiet grey strip where white is the one thing that will not read.
		ButtonText = { 255, 255, 255, 255 },
		CardText   = {  35,  35,  35, 255 },
		CardOwned   = SLATE,
		CardMenuBG  = RAISED,

		-- Scroll furniture stays in the header's hue rather than going grey.
		--
		-- The track is a real box behind the grip -- RadiusSm is 0 here, so it is a square
		-- panel the full height of the bar -- and a grey one read as a gap in the window.
		-- In pale slate it reads as part of the same object as the header.
		ScrollTrack     = SLATE_PALE,
		ScrollGrip      = SLATE_MID,
		ScrollGripHover = SLATE,

		StatusBar = SLATE,

		AccentFill       = SLATE,
		AccentFillHover  = SLATE_HI,
		AccentGloss      = { 100, 130, 160,  80 },
		AccentGlossHover = { 130, 160, 190,  80 },
		AccentGlow       = SLATE_HI,
		AccentBorder     = SLATE,

		-- The action colours keep their meaning but darken, because they now sit on light and
		-- carry ButtonText's white. The originals were picked to glow against a dark body and
		-- read as pastel here.
		PositiveFill       = {  60, 130,  75, 255 },
		PositiveFillHover  = {  70, 155,  90, 255 },
		PositiveBorder     = {  50, 110,  65, 255 },
		WarningFill        = { 190, 125,  40, 255 },
		WarningFillHover   = { 210, 145,  50, 255 },
		WarningBorder      = { 160, 105,  35, 255 },
		DangerFill         = { 175,  60,  60, 255 },
		DangerFillHover    = { 200,  70,  70, 255 },
		DangerBorder       = { 145,  50,  50, 255 },
		-- Mid slate rather than PS1's near-white, because dismiss buttons carry ButtonText
		-- now and ButtonText is white here -- it also writes on the green, orange and red
		-- fills below, where white is the only thing that reads. A light grey dismiss button
		-- was invisible; darkening the button is the side of that trade that costs nothing.
		NeutralFill        = SLATE_MID,
		NeutralFillHover   = SLATE_HI,
		NeutralBorder      = OUTLINE_HI,

		-- Prices sit on the light card, so the dark-theme neons go to readable versions.
		PriceAfford = {  40, 130,  55, 255 },
		PriceCant   = { 170,  50,  50, 255 },
	},
})

--[[
	What is still not PS1, and why:

	Category icons. PS1 puts a 16px icon left of every tab label (:141-146). That is a
	per-category asset rather than a setting -- every category would need one declared -- so it
	is the one remaining difference that is content, not configuration.
]]--
