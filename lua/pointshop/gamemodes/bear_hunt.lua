--[[
	PointShop gamemode profile - Bear Hunt

	Selected automatically by engine.ActiveGamemode(). See sh_gamemodes.lua for the
	contract; this file is data.
]]--

return {
	-- Teams are CHOSEN and HELD for the round. You pick victims and stay a victim; the bear
	-- pool is drawn before the round starts. A team like that is a thing you can own items
	-- for, so the categories' own AllowedTeams apply exactly as they always have.
	--
	-- This file exists to say that explicitly rather than by omission. Without it Bear Hunt
	-- would still gate correctly -- a missing profile changes nothing -- but then the two
	-- gamemodes would differ by one file existing, and the reason for the difference would
	-- live only in the file that is there.
	teamGating = true,
}
