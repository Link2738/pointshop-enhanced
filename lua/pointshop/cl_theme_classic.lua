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

local BODY      = { 232, 232, 232, 255 }   -- :107, the content panel
local CARD      = { 250, 250, 250, 255 }
local OUTLINE   = { 218, 218, 218, 255 }   -- :127, the tab button outline

-- PS1's text is grey on grey, never black. Three weights, from :136-138.
local INK       = { 105, 105, 105, 255 }   -- active / primary
local INK_MID   = { 120, 120, 120, 255 }   -- hover
local INK_SOFT  = { 140, 140, 140, 255 }   -- idle

T.RegisterPreset("classic", {
	name = "Classic",

	metrics = {
		HeaderH  = 48,   -- :459
		Radius   = 0,    -- nothing in that file is rounded
		RadiusSm = 0,
		Margin   = 16,   -- title baseline, :462
		IconBtn  = 32,   -- close button, :76-77
		ButtonH  = 28,   -- tab strip, :88
	},

	colours = {
		-- The header keeps its slate and its white text; everything below it goes light.
		HeaderBG   = SLATE,
		HeaderText = { 255, 255, 255, 255 },
		PointsText = { 255, 255, 255, 255 },   -- PS1's balance is white, not yellow (:468)

		FrameBG        = BODY,
		MenuCategoryBG = BODY,

		-- No alternating stripe in PS1. Rows are the body until hovered.
		RowBG    = BODY,
		RowAlt   = BODY,
		RowHover = { 222, 222, 222, 255 },

		-- Body text goes dark, which is the whole reason Text was split from HeaderText.
		Text     = INK,
		TextDim  = INK_SOFT,
		MenuRowText = INK_MID,

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

		CategoryIdleFill        = BODY,
		CategoryIdleFillHover   = { 240, 240, 240, 255 },
		CategoryIdleGloss       = { 255, 255, 255,  40 },
		CategoryIdleGlossHover  = { 255, 255, 255,  70 },
		CategoryIdleBorder      = OUTLINE,
		CategoryIdleBorderHover = { 200, 200, 200, 255 },

		SelectFill   = SLATE,
		SelectGloss  = { 100, 130, 160,  80 },
		SelectGlow   = SLATE_HI,
		SelectBorder = SLATE,

		-- Controls are outlined boxes on the body, the way PS1's buttons are.
		ControlFill        = { 240, 240, 240, 255 },
		ControlFillHover   = { 248, 248, 248, 255 },
		ControlGloss       = { 255, 255, 255,  60 },
		ControlGlossHover  = { 255, 255, 255,  90 },
		ControlBorder      = OUTLINE,
		ControlBorderHover = { 190, 190, 190, 255 },

		-- Cards are near-white with a hairline. The label strip under each keeps taking its
		-- colour from the item's state (owned / affordable / not), which is where the mauve
		-- in a real PS1 screenshot comes from -- that is CardCantBuy over a light card, not a
		-- label colour, so it is deliberately not overridden here.
		CardBG      = CARD,
		CardBorder  = OUTLINE,
		CardHover   = { 150, 150, 150, 180 },
		CardLabelBG = { 200, 200, 200, 255 },
		CardOwned   = SLATE,
		CardMenuBG  = { 245, 245, 245, 250 },

		-- Scroll furniture off blue and onto the greys.
		ScrollTrack     = { 220, 220, 220, 200 },
		ScrollGrip      = { 170, 170, 170, 255 },
		ScrollGripHover = { 140, 140, 140, 255 },

		StatusBar = SLATE,

		AccentFill       = SLATE,
		AccentFillHover  = SLATE_HI,
		AccentGloss      = { 100, 130, 160,  80 },
		AccentGlossHover = { 130, 160, 190,  80 },
		AccentGlow       = SLATE_HI,
		AccentBorder     = SLATE,

		-- The action colours keep their meaning but darken, because they now sit on light and
		-- carry OnFill's white text. The originals were picked to glow against a dark body and
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
		NeutralFill        = { 225, 225, 225, 255 },
		NeutralFillHover   = { 235, 235, 235, 255 },
		NeutralBorder      = OUTLINE,
		NeutralText        = INK,

		-- Prices sit on the light card, so the dark-theme neons go to readable versions.
		PriceAfford = {  40, 130,  55, 255 },
		PriceCant   = { 170,  50,  50, 255 },
	},
})

--[[
	Still not reachable from a preset, and left undone rather than faked:

	PS1's active tab has NO fill -- it is the same grey text on the same light body as the
	others, marked only by a 3px slate bar along its bottom edge (:131-132). PaintSelectable
	has one shape, fill plus border, so "active" here is a filled slate tab instead. That is
	the last visible difference between this preset and the real thing, and it needs an
	underline style in PaintSelectable rather than any colour.

	Category icons are the other one: PS1 puts a 16px icon left of every tab label (:141-146).
	That is a per-category asset and a change to UI.Tab, not a palette entry.

	Both are step 4.
]]--
