ITEM.Name = 'Plasma Trail'
ITEM.Price = 150
ITEM.Material = 'trails/plasma.vmt'
ITEM.TYPE = "trail"

function ITEM:OnEquip(ply, modifications)
	SafeRemoveEntity(ply.PlasmaTrail)
	ply.PlasmaTrail = util.SpriteTrail(ply, 0, modifications.color or Color(255, 255, 255, 255), false, 15, 1, 4, 0.125, self.Material)
end

function ITEM:OnHolster(ply)
	SafeRemoveEntity(ply.PlasmaTrail)
end

function ITEM:Modify(modifications)
	if CLIENT then
		local panel = vgui.Create("PSItemCustomizationPanel")
		panel:SetItem(self)
		if PS and PS.ToggleMenu then PS:ToggleMenu() end
	end
end

function ITEM:OnModify(ply, modifications)
	SafeRemoveEntity(ply.PlasmaTrail)
	self:OnEquip(ply, modifications)
end
