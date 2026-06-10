-- Disable right-click on the medicinal vape SWEP.
-- Uses a deferred patch so this runs after the Workshop addon's weapon is registered,
-- regardless of addon load order.

local function patchMedicinalVape()
	local swep = weapons.GetStored( "weapon_vape_medicinal" )
	if swep then
		swep.SecondaryAttack = function() end
	end
end

if SERVER then
	-- On server, weapon tables are populated during startup; defer one tick.
	timer.Simple( 0, patchMedicinalVape )
end

if CLIENT then
	-- On client, weapon tables aren't ready until the player entity exists.
	hook.Add( "InitPostEntity", "PatchMedicinalVapeRMB", function()
		patchMedicinalVape()
		hook.Remove( "InitPostEntity", "PatchMedicinalVapeRMB" )
	end )
end
