ITEM.Name = 'Super Small'
ITEM.Price = 1000
ITEM.Model = 'models/props_junk/garbage_glassbottle003a.mdl'
ITEM.NoPreview = true
-- local, not a global.
--
-- Without the `local` this leaks a name called `smallsize` into the shared global table for
-- every addon on the server, where anything else using that word would collide with it.
--
-- Note the branch below does nothing: both arms scale to 0.8. Left alone deliberately -- this
-- file is shared by both gamemodes on this server, so the numbers are gameplay and not
-- something to tidy while fixing a scoping bug.
local smallsize = 0.8

function ITEM:OnEquip(ply, modifications)
	local team = ply:Team()

	if (team == 2) then
		ply:SetModelScale(0.8, 1)
	else
		ply:SetModelScale(smallsize, 1)
	end
	-- Always reset hull to default size
	ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72))
	ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 45))
end

function ITEM:OnHolster(ply)

	ply:SetModelScale(1, 1)
	ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 72))
	ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 45))

end