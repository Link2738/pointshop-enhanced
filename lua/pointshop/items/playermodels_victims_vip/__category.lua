CATEGORY.Name = 'VIP Victim Models'
CATEGORY.Icon = 'star'
CATEGORY.Order = 12
CATEGORY.AllowedTeams = { 1 }  -- TEAM_VICTIMS

function CATEGORY:CanPlayerSee(ply)
	if self.AllowedTeams and #self.AllowedTeams > 0 then
		local validTeam = false
		for _, tid in ipairs(self.AllowedTeams) do
			if ply:Team() == tid then
				validTeam = true
				break
			end
		end
		if not validTeam then return false end
	end
	if PS and PS.Config and PS.Config.IsVIP then
		return PS.Config.IsVIP(ply)
	end
	return false
end
