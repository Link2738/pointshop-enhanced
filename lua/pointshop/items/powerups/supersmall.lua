ITEM.Name = 'Super Small'
ITEM.Price = 1000
ITEM.Model = 'models/props_junk/garbage_glassbottle003a.mdl'
ITEM.NoPreview = true
smallsize = 0.8
function ITEM:OnEquip(ply, modifications)
	local team = ply:Team()

	if (team == 2) then 
		ply:SetModelScale(0.9, 1)
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