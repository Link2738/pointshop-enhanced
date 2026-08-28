local PANEL = {}

function PANEL:Init()
	self:SetModel(LocalPlayer():GetModel())
	self:FrameModel()
end

-- How far back the camera sits, as a multiple of the model's own size.
--
-- One knob rather than three magic numbers in the expression below. Larger pulls back; the
-- shape of the framing -- the angle it looks from -- stays the same, because that is what the
-- ratio between the three components decides and the zoom should not change it.
PANEL.FrameZoom = 1.85

function PANEL:SetFrameZoom(f)
	self.FrameZoom = f or 1
	self:FrameModel()
end

-- Points the camera at whatever model is currently set.
--
-- Its own function because SetOutfit can change the model after Init, and a camera framed
-- around a citizen does not frame a headcrab. The distance comes from the render bounds, so
-- a tall model backs the camera off on its own.
function PANEL:FrameModel()
	if not IsValid(self.Entity) then return end

	local mins, maxs = self.Entity:GetRenderBounds()
	local reach = mins:Distance(maxs) * self.FrameZoom

	self:SetCamPos(reach * Vector(0.30, 0.30, 0.25) + Vector(0, 0, 15))
	self:SetLookAt((maxs + mins) / 2)
end

-- ============================================================================
-- PREVIEWING AN OUTFIT NOBODY IS WEARING
--
-- Without an outfit this panel shows the local player: their model, and the accessories in
-- PS.ClientsideModels, drawn with the customization the shop has stored for them. That is
-- what the shop menu and the customization panel want, and it is unchanged.
--
-- With one, it shows a set that exists only as data -- a saved loadout, which the player may
-- not be wearing and may never wear. Three things follow:
--
--   the model comes from the outfit, not from LocalPlayer
--   the accessories are entities this panel creates and owns, not the shared table
--   each one draws with the OUTFIT's modifiers, passed as the fifth argument to
--   ModifyClientsideModel, which the accessory base already accepts and only falls back
--   from when it is absent
--
-- The entities are the reason this needs care rather than cleverness: they are ClientsideModels,
-- they are not parented to anything that will clean them up, and a panel that previews eight
-- loadouts in a row leaks eight outfits unless it removes its own on the way out.
-- ============================================================================

function PANEL:ClearOutfitModels()
	for _, ent in pairs(self.OutfitModels or {}) do
		if IsValid(ent) then ent:Remove() end
	end
	self.OutfitModels = {}
end

-- outfit = { model, colour, useColor2, items = { { id = ..., mods = ... }, ... } }
-- Passing nil returns the panel to showing the local player.
function PANEL:SetOutfit(outfit)
	self:ClearOutfitModels()
	self.Outfit = outfit

	if not outfit then
		self:SetModel(LocalPlayer():GetModel())
		self:FrameModel()
		return
	end

	self:SetModel(outfit.model or LocalPlayer():GetModel())
	self:FrameModel()

	if IsValid(self.Entity) and outfit.colour then
		PS:ApplyColorToModel(self.Entity, outfit.colour, outfit.useColor2)
	end

	for _, entry in ipairs(outfit.items or {}) do
		local ITEM = PS.Items[entry.id]

		-- Playermodels and weapons have no model to hang on the character -- the first IS the
		-- character and is handled above, the second is not drawn at all.
		if ITEM and ITEM.Model and (ITEM.Attachment or ITEM.Bone) then
			local ent = ClientsideModel(ITEM.Model, RENDERGROUP_BOTH)
			if IsValid(ent) then
				ent:SetNoDraw(true)
				self.OutfitModels[entry.id] = ent
			end
		end
	end
end

function PANEL:OnRemove()
	self:ClearOutfitModels()
end

function PANEL:Paint()
	if ( !IsValid( self.Entity ) ) then return end

	local x, y = self:LocalToScreen( 0, 0 )

	self:LayoutEntity( self.Entity )

	local ang = self.aLookAngle
	if ( !ang ) then
		ang = (self.vLookatPos-self.vCamPos):Angle()
	end

	local w, h = self:GetSize()
	cam.Start3D( self.vCamPos, ang, self.fFOV, x, y, w, h, 5, 4096 )
	cam.IgnoreZ( true )

	render.SuppressEngineLighting( true )
	render.SetLightingOrigin( self.Entity:GetPos() )
	render.ResetModelLighting( self.colAmbientLight.r/255, self.colAmbientLight.g/255, self.colAmbientLight.b/255 )
	render.SetColorModulation( self.colColor.r/255, self.colColor.g/255, self.colColor.b/255 )
	render.SetBlend( self.colColor.a/255 )

	for i=0, 6 do
		local col = self.DirectionalLight[ i ]
		if ( col ) then
			render.SetModelLighting( i, col.r/255, col.g/255, col.b/255 )
		end
	end

	self.Entity:DrawModel()

	self:DrawOtherModels()
	
	render.SuppressEngineLighting( false )
	cam.IgnoreZ( false )
	cam.End3D()

	self.LastPaint = RealTime()
end

-- Positions one accessory on the previewed body and draws it.
--
-- Shared by both sources, because the attachment and bone maths is the same question whoever
-- is asking: where on this model does this item sit. Only where the entity and the modifiers
-- come from differs.
function PANEL:DrawAccessory(ITEM, model, mods)
	if not IsValid(model) then return end
	if not ITEM.Attachment and not ITEM.Bone then return end

	local pos, ang = Vector(), Angle()

	if ITEM.Attachment then
		local attach_id = self.Entity:LookupAttachment(ITEM.Attachment)
		if not attach_id then return end

		local attach = self.Entity:GetAttachment(attach_id)
		if not attach then return end

		pos, ang = attach.Pos, attach.Ang
	else
		local bone_id = self.Entity:LookupBone(ITEM.Bone)
		if not bone_id then return end

		pos, ang = self.Entity:GetBonePosition(bone_id)
	end

	-- The fifth argument is the whole point. Given, the item draws with THESE settings;
	-- omitted, the accessory base falls back to whatever the player has stored for it, which
	-- is what a loadout preview must not show.
	model, pos, ang = ITEM:ModifyClientsideModel(LocalPlayer(), model, pos, ang, mods)

	model:SetPos(pos)
	model:SetAngles(ang)
	model:DrawModel()
end

function PANEL:DrawOtherModels()
	local ply = LocalPlayer()

	-- An outfit was set, so this panel is showing a saved look rather than a worn one. Its own
	-- entities, its own modifiers, and the shared table is not consulted at all.
	if self.Outfit then
		for _, entry in ipairs(self.Outfit.items or {}) do
			local ITEM = PS.Items[entry.id]
			if ITEM then
				self:DrawAccessory(ITEM, self.OutfitModels[entry.id], entry.mods)
			end
		end
		return
	end

	if PS.ClientsideModels[ply] then
		for item_id, model in pairs(PS.ClientsideModels[ply]) do
			local ITEM = PS.Items[item_id]
			
			if not ITEM.Attachment and not ITEM.Bone then PS.ClientsideModels[ply][item_id] = nil continue end
			
			local pos = Vector()
			local ang = Angle()
			
			if ITEM.Attachment then
				local attach_id = self.Entity:LookupAttachment(ITEM.Attachment)
				if not attach_id then continue end
				
				local attach = self.Entity:GetAttachment(attach_id)
				
				if not attach then continue end
				
				pos = attach.Pos
				ang = attach.Ang
			else
				local bone_id = self.Entity:LookupBone(ITEM.Bone)
				if not bone_id then continue end
				
				pos, ang = self.Entity:GetBonePosition(bone_id)
			end
			
			model, pos, ang = ITEM:ModifyClientsideModel(ply, model, pos, ang)
			
			model:SetPos(pos)
			model:SetAngles(ang)
			
			model:DrawModel()
		end
	end
	
	if PS.HoverModel then
		local ITEM = PS.Items[PS.HoverModel]
		
		if ITEM.NoPreview then return end -- don't show
		if ITEM.WeaponClass then return end -- hack for weapons
		
		if not ITEM.Attachment and not ITEM.Bone then -- must be a playermodel?
			self:SetModel(ITEM.Model)
		else
			local model = PS.HoverModelClientsideModel
			
			local pos = Vector()
			local ang = Angle()
			
			if ITEM.Attachment then
				local attach_id = self.Entity:LookupAttachment(ITEM.Attachment)
				if not attach_id then return end
				
				local attach = self.Entity:GetAttachment(attach_id)
				
				if not attach then return end
				
				pos = attach.Pos
				ang = attach.Ang
			else
				local bone_id = self.Entity:LookupBone(ITEM.Bone)
				if not bone_id then return end
				
				pos, ang = self.Entity:GetBonePosition(bone_id)
			end
			
			model, pos, ang = ITEM:ModifyClientsideModel(ply, model, pos, ang)
			
			model:SetPos(pos)
			model:SetAngles(ang)
			
			model:DrawModel()
		end
	else
		local currentModel = LocalPlayer():GetModel()
		if self._lastNonHoverModel ~= currentModel then
			self:SetModel(currentModel)
			self._lastNonHoverModel = currentModel
		end
	end
end

vgui.Register('DPointShopPreview', PANEL, 'DModelPanel')
