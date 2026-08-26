--[[
	PointShop gamemode profile - Hide and Seek

	Selected automatically by engine.ActiveGamemode(). See sh_gamemodes.lua for the
	contract; this file is data.
]]--

return {
	-- Roles are ASSIGNED and CHURN. You start hiding, and the moment somebody touches you
	-- you are seeking, for the rest of the round.
	--
	-- Nothing can be gated on a team like that. Gating means the shop strips and swaps your
	-- model the instant your role changes, so getting caught would visibly transform you --
	-- and this gamemode's one rule is that being caught changes your role, not your body.
	teamGating = false,

	categories = {
		-- Seeker models are Bear Hunt content: they exist so a bear is recognisable on
		-- sight, which is a job the outline does here instead. Registering them would put
		-- a category in the shop whose entire purpose this gamemode has already solved
		-- another way, and would let a hider buy the thing that used to mean "hunting you".
		playermodels_bears = false,
	},
}
