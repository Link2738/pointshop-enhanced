local BASE = include("pointshop/sh_accessory_base.lua") or {}

ITEM.Name = 'Sims Plumbob'
ITEM.Price = 100
ITEM.Model = 'models/griim/sims/plumbob.mdl'
ITEM.Attachment = 'eyes'
ITEM.AdminOnly = true
ITEM.TYPE = 'accessory'
ITEM.UseColor2Proxy = false


ITEM.DefaultModifications = {
	scale = 0.75,
	offsetX = -3,
	offsetY = 0,
	offsetZ = 18,
	rotation = 0,
	axis = "Right",
	axisDeg = 0,
	color = Color(131, 255, 0, 255)
}
-- Inherit base functions
for k, v in pairs(BASE) do
	ITEM[k] = v
end