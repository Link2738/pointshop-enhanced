CATEGORY.Name = 'Victim Models'
CATEGORY.Icon = 'user'
CATEGORY.Order = 11
CATEGORY.AllowedTeams = { 1 }  -- TEAM_VICTIMS

function CATEGORY:CanPlayerSee(ply)
	if not self.AllowedTeams or #self.AllowedTeams == 0 then return true end
	for _, tid in ipairs(self.AllowedTeams) do
		if ply:Team() == tid then return true end
	end
	return false
end
