local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'Jump Pack'
ITEM.Price = 1000
ITEM.Model = 'models/xqm/jetengine.mdl'
ITEM.Bone = 'ValveBiped.Bip01_Spine2'
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false
-- Default customization values
ITEM.DefaultModifications = {
	scale = 0.5,
	offsetX = 6,
	offsetY = 5,
	offsetZ = 0,
	rotation = 0,
	axis = "Right",
	axisDeg = 0,
	color = Color(255, 255, 255, 255)
}

-- Inherit base functions
for k, v in pairs(BASE) do
	ITEM[k] = v
end



-- Override Move for jump boost
function ITEM:Move(pl, modifications, ply, data)
	if pl ~= ply then return end
	local bdata = data:GetButtons()
	if bit.band(bdata, IN_JUMP) > 0 then
		data:SetVelocity(data:GetVelocity() + Vector(0,0,100)*FrameTime())
	end
end
