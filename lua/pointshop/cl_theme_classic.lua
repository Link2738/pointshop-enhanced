--[[
	pointshop/cl_theme_classic.lua

	The PointShop 1 look, as a preset.

	Values here were read out of pointshop-1.3.2/lua/pointshop/vgui/DPointShopMenu.lua rather
	than remembered, because remembering it got the layout wrong once already. Line references
	below point into that file.

	What PS1 actually is, which is not what it is usually described as:

		frame body   40,40,40      dark, not light  (PANEL:Paint, :454)
		header bar   52,73,94      slate, 48 tall   (:458-459, BGColor1)
		content pad  232,232,232   light            (createBtn, :107)
		corners      square        every surface is DrawRect

	The light grey is the CONTENT panel inside a dark frame, not the frame. So this is a dark
	theme with a slate header and one light region -- which is why most of our palette
	survives it untouched.
]]--

local T = PS.Theme

-- The slate. One colour doing three jobs in PS1: the header fill, the active category's
-- underline, and the only saturated thing on screen.
local SLATE   = { 52, 73, 94, 255 }
local BODY    = { 40, 40, 40, 255 }

-- A lighter slate for the states that need to read as "the same colour, but lit". PS1 had no
-- hover states to speak of, so these are ours -- kept inside the same hue so the preset does
-- not smuggle a second accent in.
local SLATE_HI  = { 72, 99, 126, 255 }
local SLATE_DIM = { 44, 62, 80, 255 }

T.RegisterPreset("classic", {
	name = "Classic",

	metrics = {
		-- 48, from the header DrawRect at :459. Ours is 50; the two pixels are visible when
		-- the header sits against a square corner.
		HeaderH  = 48,

		-- The whole point. PS1 draws every surface with DrawRect and has no rounded corner
		-- anywhere in the file.
		Radius   = 0,
		RadiusSm = 0,

		-- Title baseline is x=16 (:462), not our 10.
		Margin   = 16,

		-- Close button is 32x32 at (w-40, 8) (:76-77). 32 with a 48 header leaves 8 above and
		-- below, which is what that -40/8 pair produces.
		IconBtn  = 32,

		-- The tab strip is 28 tall (:88). Ours already is.
		ButtonH  = 28,
	},

	colours = {
		FrameBG  = BODY,
		HeaderBG = SLATE,

		-- Rows are the frame in PS1 -- there is no alternating stripe in that file. Flattening
		-- them to the body colour is closer than keeping our two-tone banding.
		RowBG    = BODY,
		RowAlt   = BODY,
		RowHover = { 57, 56, 54, 255 },   -- BGColor3, the one hover-ish tone PS1 defines

		-- The accent stops being blue and becomes the slate, because in PS1 the underline
		-- beneath the active category is drawn with BGColor1 -- the header colour (:131-132).
		Accent = SLATE,

		-- Category buttons follow the accent to the slate. The idle set stays neutral-dark:
		-- PS1's idle categories are grey text on light, which this preset cannot reach yet
		-- (see the note at the bottom of this file).
		CategoryFill   = SLATE,
		CategoryGloss  = { 72, 99, 126, 100 },
		CategoryGlow   = SLATE_HI,
		CategoryBorder = { 92, 119, 146, 200 },

		CategoryIdleFill        = { 48, 48, 48, 255 },
		CategoryIdleFillHover   = { 57, 56, 54, 255 },
		CategoryIdleGloss       = { 62, 62, 62, 60 },
		CategoryIdleGlossHover  = { 72, 72, 72, 60 },
		CategoryIdleBorder      = { 70, 70, 70, 150 },
		CategoryIdleBorderHover = { 70, 70, 70, 250 },

		-- Selection and the accent-styled buttons move onto the slate for the same reason.
		SelectFill   = SLATE,
		SelectGloss  = { 100, 130, 160, 80 },
		SelectGlow   = SLATE_HI,
		SelectBorder = { 100, 130, 160, 200 },

		AccentFill       = { 52, 73, 94, 200 },
		AccentFillHover  = SLATE_HI,
		AccentGloss      = { 100, 130, 160, 80 },
		AccentGlossHover = { 130, 160, 190, 80 },
		AccentGlow       = SLATE_HI,
		AccentBorder     = { 100, 130, 160, 200 },

		-- Controls flatten. PS1's are outlined rectangles, so the fill sits near the body and
		-- the border does the work.
		ControlFill        = { 48, 48, 48, 255 },
		ControlFillHover   = { 62, 62, 62, 255 },
		ControlGloss       = { 62, 62, 62, 50 },
		ControlGlossHover  = { 80, 80, 80, 50 },
		ControlBorder      = { 90, 90, 90, 150 },
		ControlBorderHover = { 90, 90, 90, 250 },

		-- 218,218,218 is PS1's outline colour for the tab buttons (:127). Reused here as the
		-- card border so items read as outlined boxes rather than raised cards.
		CardBG     = { 35, 35, 35, 255 },
		CardBorder = { 90, 90, 90, 200 },
		CardHover  = { 218, 218, 218, 120 },
		CardLabelBG = { 22, 22, 22, 255 },
		CardOwned  = SLATE_HI,

		-- Scroll furniture follows the accent off blue.
		ScrollTrack     = { 30, 30, 30, 200 },
		ScrollGrip      = SLATE,
		ScrollGripHover = SLATE_HI,

		-- The status strip's gradient base is a surface, not an accent, so it tracks the
		-- slate rather than staying navy.
		StatusBar = SLATE_DIM,

		-- The category strip. PS1's is the light panel; ours cannot go light yet, so it sits
		-- one step off the body the way PS1's sits one step off its frame.
		MenuCategoryBG = { 34, 34, 34, 255 },

		-- Header text in PS1 is plain white and the balance is white too, not yellow
		-- (:462, :468). The yellow is ours.
		PointsText = { 255, 255, 255, 255 },
		TextDim    = { 200, 205, 215, 255 },
	},
})

--[[
	Not reachable from a preset, and deliberately left undone rather than faked:

	PS1's category strip is grey text on 232,232,232 with a 218 outline and a 3px slate
	underline on the active one (:107, :127-138). A preset can move any colour, but every
	category button takes its text from PS.Theme.Text -- the single global white, set in
	UI.Tab (cl_ui.lua) -- so turning the strip light turns its labels invisible.

	The fix is one token: give UI.Tab its own CategoryText rather than borrowing Text, at
	which point the light strip is just three more entries above. Same for the underline,
	which needs PaintSelectable to grow an underline style. Both are step 4 -- the things a
	preset cannot reach -- not preset work.
]]--
