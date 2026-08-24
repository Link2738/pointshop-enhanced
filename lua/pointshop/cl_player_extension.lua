local Player = FindMetaTable('Player')

-- items

function Player:PS_GetItems()
	return self.PS_Items or {}
end

function Player:PS_HasItem(item_id)
	if not self.PS_Items then return false end
	return self.PS_Items[item_id] and true or false
end

function Player:PS_HasItemEquipped(item_id)
	if not self:PS_HasItem(item_id) then return false end
	
	return self.PS_Items[item_id].Equipped or false
end

function Player:PS_BuyItem(item_id)
	if self:PS_HasItem(item_id) then return false end
	if not self:PS_HasPoints(PS.Config.CalculateBuyPrice(self, PS.Items[item_id])) then return false end

	-- Include any try-before-you-buy customization staged from the Inspector
	local ITEM = PS.Items[item_id]
	local pendingKey = (ITEM and ITEM.TYPE or "accessory") .. "_" .. item_id
	local pending = PS_PendingCustomizationData and PS_PendingCustomizationData[pendingKey]

	net.Start('PS_BuyItem')
		net.WriteString(item_id)
		net.WriteBool(pending ~= nil)
		if pending then net.WriteTable(pending) end
	net.SendToServer()

	if pending then PS_PendingCustomizationData[pendingKey] = nil end
end

function Player:PS_SellItem(item_id)
	if not self:PS_HasItem(item_id) then return false end
	
	net.Start('PS_SellItem')
		net.WriteString(item_id)
	net.SendToServer()
end

function Player:PS_EquipItem(item_id)
	if not self:PS_HasItem(item_id) then return false end
	
	net.Start('PS_EquipItem')
		net.WriteString(item_id)
	net.SendToServer()
end

function Player:PS_HolsterItem(item_id)
	if not self:PS_HasItem(item_id) then return false end

	net.Start('PS_HolsterItem')
		net.WriteString(item_id)
	net.SendToServer()
end

-- points

function Player:PS_GetPoints()
	return self.PS_Points or 0
end

function Player:PS_HasPoints(points)
	return self:PS_GetPoints() >= points
end

-- clientside models
-- Universal model coloring function
-- Universal player model coloring function
-- Both of these take a copy of the incoming colour rather than using it directly.
-- The alpha fixup below used to write into the caller's table, and callers pass
-- mods.color straight in — so applying a colour quietly rewrote the stored
-- customization data as a side effect.
--
-- The colour is also stashed on the entity as a plain field instead of installing a
-- closure over GetPlayerColor. The old version replaced the method on every call, so
-- each apply allocated a fresh closure that permanently shadowed the real method and
-- kept its captured colour alive.
local function CopyColor(c)
	if not c then return Color(255, 255, 255, 255) end
	local a = c.a or 255
	if a == 0 then a = 255 end
	return Color(c.r or 255, c.g or 255, c.b or 255, a)
end

-- REMOVED: InstallColorCache, which shadowed SetColor per model so PostPlayerDraw could
-- read cached modulation values instead of querying the entity each frame.
--
-- It only ever saved one engine call per accessory per frame — the allocation that made
-- the read expensive was already gone once the draw path moved to Entity:GetColor4Part,
-- which returns the channels as plain numbers.
--
-- What it cost was correctness. The cache had to be installed at construction to be
-- trustworthy, and there are at least four places that build a clientside accessory model:
-- PS_AddClientsideModel here, the hover model in cl_init.lua, and two in
-- DPointShopInspector. Any model born from the others had no cache, so the draw path saw
-- no colour and rendered it neutral — accessories that simply would not tint.
--
-- Covering four creation sites with a per-entity method shadow to save one accessor call
-- is the wrong trade. The draw path reads the colour directly again.
local function StorePlayerColor(ent, col)
	ent.PS_AppliedColor = Vector(col.r / 255, col.g / 255, col.b / 255)
	if not ent.PS_GetPlayerColorHooked then
		ent.PS_GetPlayerColorHooked = true
		ent.GetPlayerColor = function(self)
			return self.PS_AppliedColor or Vector(1, 1, 1)
		end
	end
end

function PS:ApplyColorToPlayerModel(ply, color)
	if not IsValid(ply) or not ply.SetColor then return end
	local col = CopyColor(color)
	ply:SetColor(col)
	StorePlayerColor(ply, col)
end

function PS:ApplyColorToModel(model, color, useColor2Proxy)
	if not IsValid(model) then return end
	local col = CopyColor(color)

	if useColor2Proxy and model.SetColor2 then
		model:SetColor2(Vector(col.r/255, col.g/255, col.b/255))
		model:SetColor(Color(255, 255, 255, col.a))
	else
		if col.a < 255 then
			model:SetRenderMode(RENDERMODE_TRANSCOLOR)
		else
			model:SetRenderMode(RENDERMODE_NORMAL)
		end
		model:SetColor(col)
	end

	StorePlayerColor(model, col)
end

function Player:PS_AddClientsideModel(item_id)
	if not PS.Items[item_id] then return false end
	local ITEM = PS.Items[item_id]

	-- Dedupe: remove any existing clientsidemodels for this player that use the same model path
	if PS and PS.ClientsideModels and PS.ClientsideModels[self] then
		for k, v in pairs(PS.ClientsideModels[self]) do
			if IsValid(v) and v.GetModel and v:GetModel() == ITEM.Model then
				-- Only remove preview models; don't remove the equipped authoritative model
				if v.__ps_preview then
					v:Remove()
					PS.ClientsideModels[self][k] = nil
				end
			end
		end
	end
	
	-- If a model already exists for this player+item, remove it so we replace it
	if PS.ClientsideModels[self] then
		-- Direct key match (string or number)
		if PS.ClientsideModels[self][item_id] and IsValid(PS.ClientsideModels[self][item_id]) then
			PS.ClientsideModels[self][item_id]:Remove()
			PS.ClientsideModels[self][item_id] = nil
		end
		local nid = tonumber(item_id)
		if nid and PS.ClientsideModels[self][nid] and IsValid(PS.ClientsideModels[self][nid]) then
			PS.ClientsideModels[self][nid]:Remove()
			PS.ClientsideModels[self][nid] = nil
		end
		-- Fallback: check if any existing clientsidemodel uses the same model path
		for k, v in pairs(PS.ClientsideModels[self]) do
			if IsValid(v) and v.GetModel and v:GetModel() == ITEM.Model then
				v:Remove()
				PS.ClientsideModels[self][k] = nil
			end
		end
	end
	local modifications = self.PS_Items and self.PS_Items[item_id] and self.PS_Items[item_id].Modifiers or nil
	-- Fallback: if the player's PS_Items doesn't contain modifiers yet (race condition),
	-- try the temporary PS_AccessoryCustomizations cache populated from server broadcasts.
	if not modifications and PS_AccessoryCustomizations and PS_AccessoryCustomizations[self] and ITEM and ITEM.Model then
		local key = tostring(ITEM.Model)
		if PS_AccessoryCustomizations[self][key] then
			modifications = PS_AccessoryCustomizations[self][key]
		end
	end
	local mdl = ClientsideModel(ITEM.Model, RENDERGROUP_OPAQUE)
	-- ClientsideModel returns NULL when the model isn't present on this client — the
	-- missing-FastDL-content case. Calling :SetNoDraw on that throws and takes out the
	-- rest of the handler, so the player ends up with no accessories at all rather than
	-- just missing the one broken model.
	if not IsValid(mdl) then
		if PS and PS.Config and PS.Config.Debug then
			print("[PS] ClientsideModel failed for " .. tostring(ITEM.Model) .. " (missing content?)")
		end
		return false
	end

	mdl:SetNoDraw(true)
	mdl.PS_Modifications = modifications -- Store modifications on the model
	if not PS.ClientsideModels[self] then PS.ClientsideModels[self] = {} end
	PS.ClientsideModels[self][item_id] = mdl
	-- Apply color immediately if available
	local useColor2 = ITEM.UseColor2Proxy or false
	if modifications and modifications.color then
		PS:ApplyColorToModel(mdl, modifications.color, useColor2)
	else
		PS:ApplyColorToModel(mdl, Color(255,255,255,255), useColor2)
	end
	-- Post-initialization hook for further logic
	hook.Run("PS_PostClientsideModelInit", mdl, item_id, self)
end

function Player:PS_RemoveClientsideModel(item_id)
	if not PS.Items[item_id] then return false end
	if not PS.ClientsideModels[self] then return false end
	local mdl = PS.ClientsideModels[self][item_id]
	if mdl and IsValid(mdl) then
		mdl:Remove()
	end
	PS.ClientsideModels[self][item_id] = nil
end

function Player:PS_RefreshEquippedItems()
	-- Refresh all currently equipped items by locally recreating clientside models
	-- Does NOT send net messages to server (avoids net storm of holster+equip per item)
	if not self.PS_Items then return end
	
	for item_id, itemData in pairs(self.PS_Items) do
		if itemData.Equipped and PS.Items[item_id] then
			-- Remove existing clientside model
			if self.PS_RemoveClientsideModel then
				self:PS_RemoveClientsideModel(item_id)
			end
		end
	end
	
	-- Recreate after a short delay to let removals process
	timer.Simple(0.1, function()
		if not IsValid(self) or not self.PS_Items then return end
		for item_id, itemData in pairs(self.PS_Items) do
			if itemData.Equipped and PS.Items[item_id] then
				if self.PS_AddClientsideModel then
					self:PS_AddClientsideModel(item_id)
				end
			end
		end
	end)
end
