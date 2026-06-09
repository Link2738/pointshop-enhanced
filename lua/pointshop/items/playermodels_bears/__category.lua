CATEGORY.Name = 'Bear Models'
CATEGORY.Icon = 'user'
CATEGORY.Order = 10
CATEGORY.AllowedTeams = { 2, 3 }  -- TEAM_BEAR, TEAM_INFTBEAR

function CATEGORY:CanPlayerSee(ply)
	if not self.AllowedTeams or #self.AllowedTeams == 0 then return true end
	for _, tid in ipairs(self.AllowedTeams) do
		if ply:Team() == tid then return true end
	end
	return false
end
