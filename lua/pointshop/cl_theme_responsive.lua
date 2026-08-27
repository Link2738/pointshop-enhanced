--[[
	pointshop/cl_theme_responsive.lua

	Sizes the shop as a share of the screen instead of a fixed width.

	Colour-free on purpose: this is a LOOK that only touches geometry, which is the clearest
	demonstration that the two are independent. Pick it alongside whatever palette you like --
	the shipped one, Classic, or your own edits -- and only the window's proportions change.

	Why it is not the default: a fixed 900 is predictable and is what the shop has always
	been. A share of the screen is better on a monitor far from 16:9 and worse if you want the
	same window everywhere, and that is a preference rather than a correctness question, so it
	is offered rather than imposed.
]]--

local T = PS.Theme

T.RegisterPreset("responsive", {
	name = "Responsive size",

	metrics = {
		-- 62% of the width, floored at 760 so a small screen still fits two card columns and
		-- capped at 1400 so an ultrawide does not get a shop the width of the desk.
		FrameWScale  = 0.62,
		FrameWOffset = 0,
		FrameWMin    = 760,
		FrameWMax    = 1400,

		-- 82% of the height. The cap is lower than the width's because vertical sprawl costs
		-- more: the category strip and header stay put while only the item grid grows.
		FrameHScale  = 0.82,
		FrameHOffset = 0,
		FrameHMin    = 560,
		FrameHMax    = 980,
	},
})
