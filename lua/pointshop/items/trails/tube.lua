ITEM.Name = 'Tube Trail'
ITEM.Price = 150
ITEM.Material = 'trails/tube.vmt'
ITEM.TYPE = "trail"

function ITEM:OnEquip(ply, modifications)
	SafeRemoveEntity(ply.TubeTrail)
	ply.TubeTrail = util.SpriteTrail(ply, 0, modifications.color or Color(255, 255, 255, 255), false, 15, 1, 4, 0.125, self.Material)
end

function ITEM:OnHolster(ply)
	SafeRemoveEntity(ply.TubeTrail)
end

function ITEM:Modify(modifications)
	if CLIENT then
		local panel = vgui.Create("PSItemCustomizationPanel")
		panel:SetItem(self)
		if PS and PS.ToggleMenu then PS:ToggleMenu() end
	end
end

function ITEM:OnModify(ply, modifications)
	SafeRemoveEntity(ply.TubeTrail)
	self:OnEquip(ply, modifications)
end
