--[[
	pointshop/cl_theme_crimson.lua

	The server's own look, as a preset.

	Built over the DEFAULT rather than over Classic. Classic is a different shop -- square
	corners, a fixed 800x640, light surfaces, a slate header -- and taking this look there
	would have dragged all of that with it. This changes colours and the window size and
	nothing else, so radii, gaps, button heights and every other metric stay where the
	default put them.

	Only the entries that actually differ from the default are listed. Everything absent is
	deliberately absent: a preset that restates a default value freezes it, so the next time
	the shipped palette moves this look would silently stop tracking it.

	WHAT IT IS

	Dark red surfaces, a red category strip, and a black accent. Three families carry it:

		surfaces    FrameBG / PanelBG / ListBG, near-black reds at three depths
		bar         StatusBar, the one bright red -- it paints the header of every window
		            and the status strips under them
		categories  the whole Category and CategoryIdle set, red rather than the default blue

	Accent is black here, which is worth knowing before changing it: it draws the window
	outline, the panel top edge and the strip rule, so it is the colour of every hairline in
	the UI at once.
]]--

local T = PS.Theme

-- The reds, named by the job rather than the shade, so a retune moves them together.
local BODY     = {  90,   0,   0, 255 }   -- window body
local BOX      = {  49,   0,   0, 255 }   -- a box on the body
local BOX_DEEP = {  39,   0,   0, 255 }   -- the options column, one step further in
local BAR      = { 188,   0,   0, 255 }   -- header bars and status strips

local CAT      = { 154,   0,   0, 255 }   -- category button, active
local CAT_IDLE = {  93,   0,   2, 255 }   -- category button, idle
local RED      = { 255,   0,   0, 255 }   -- the pure red the category variants are cut from

T.RegisterPreset("crimson", {
	name = "Crimson",

	metrics = {
		-- 865 wide, and the screen less 356 tall.
		--
		-- Same shape as the default -- a fixed width, an inset height -- just different
		-- numbers. The clamps are wide on purpose: they are here to stop something absurd at
		-- the extremes, not to second-guess the size above.
		FrameWScale  = 0,
		FrameWOffset = 865,
		FrameWMin    = 240,
		FrameWMax    = 2200,

		FrameHScale  = 1,
		FrameHOffset = -356,
		FrameHMin    = 600,
		FrameHMax    = 2200,
	},

	colours = {
		-- Surfaces, deepest last. Three separate entries because they sit at three depths
		-- and the difference between them is what reads as depth at all.
		FrameBG = BODY,
		PanelBG = BOX,
		ListBG  = BOX_DEEP,

		-- The bar across the top of every window, and the status strips beneath them. Bright,
		-- because it is the only surface here that is meant to be looked at rather than sat
		-- on.
		StatusBar = BAR,

		-- Black. Every hairline in the UI: window outline, panel top edge, strip rule.
		Accent = { 0, 0, 0, 255 },

		-- The category strip, red instead of the default blue.
		--
		-- Variants are written out rather than left to derive. The derived offsets are
		-- measured against the default's blue, and these do not sit at the same distances
		-- from their base -- the gloss and glow go to pure red while the fill stays dark, so
		-- deriving them would have produced a duller strip than this.
		CategoryFill   = CAT,
		CategoryGloss  = { 255, 0, 0, 100 },
		CategoryGlow   = RED,
		CategoryBorder = { 255, 0, 0, 200 },

		CategoryIdleFill        = CAT_IDLE,
		CategoryIdleFillHover   = RED,
		CategoryIdleGloss       = { 255, 0, 0,  60 },
		CategoryIdleGlossHover  = { 255, 0, 0,  60 },
		CategoryIdleBorder      = { 148, 0, 0, 150 },
		CategoryIdleBorderHover = { 241, 0, 0, 250 },

		-- The selected value button's edge. Left blue deliberately: skin and bodygroup
		-- pickers are the one place in the shop where a selection has to be unmistakable,
		-- and a red edge on a red panel is not.
		SelectBorder = { 0, 93, 255, 200 },
	},
})
