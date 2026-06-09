PS_ITEM_EQUIP = 1
PS_ITEM_HOLSTER = 2
PS_ITEM_MODIFY = 3

local Player = FindMetaTable('Player')

function Player:PS_PlayerSpawn()
	if not self:PS_CanPerformAction() then return end

	-- TTT ( and others ) Fix
	if TEAM_SPECTATOR ~= nil and self:Team() == TEAM_SPECTATOR then return end
	if TEAM_SPEC ~= nil and self:Team() == TEAM_SPEC then return end

	-- Murder Spectator Fix (they don't specify the above enums when making teams)
	-- https://github.com/mechanicalmind/murder/blob/master/gamemode/sv_spectate.lua#L15
	if self.Spectating then return end

	timer.Simple(1, function()
		if !IsValid(self) then return end
		for item_id, item in pairs(self.PS_Items) do
			local ITEM = PS.Items[item_id]
			if item.Equipped then
				-- Skip (but keep equipped) playermodel items from wrong-team categories
				-- so only the model matching the player's current team gets applied
				local cat_name = ITEM.Category
				local CATEGORY = PS:FindCategoryByName(cat_name)
				if CATEGORY and CATEGORY.AllowedTeams and #CATEGORY.AllowedTeams > 0 then
					local teamAllowed = false
					for _, tid in ipairs(CATEGORY.AllowedTeams) do
						if self:Team() == tid then teamAllowed = true break end
					end
					if not teamAllowed then
						continue  -- stays equipped in data, just not applied this spawn
					end
				end

				-- If modifiers are empty, try loading saved customization (SQL/provider)
				if (not item.Modifiers) or (type(item.Modifiers) == "table" and next(item.Modifiers) == nil) then
					-- Determine item type to load correct customization backend
					local isPlayermodel = ITEM.TYPE == "playermodel" or (ITEM.Bodygroups ~= nil) or (ITEM.ApplyModelSettings ~= nil)
					local isAccessory = ITEM.Attachment or ITEM.Bone or ITEM.TYPE == "accessory"
					
					-- Load accessory customizations (only for accessories)
					if isAccessory and ITEM.Model and PS_GetAccessoryCustomization then
						local saved = PS_GetAccessoryCustomization(self, ITEM.Model)
						if saved and type(saved) == "table" and next(saved) ~= nil then
							self.PS_Items[item_id].Modifiers = saved
							if PS and PS.SavePlayerItem then
								pcall(function() PS:SavePlayerItem(self, item_id, self.PS_Items[item_id]) end)
							end
						end
					end
					-- Load playermodel customizations (only for playermodels)
					if isPlayermodel and PS_GetPlayerModelCustomization then
						local saved = PS_GetPlayerModelCustomization(self, item_id)
						if saved and type(saved) == "table" and next(saved) ~= nil then
							self.PS_Items[item_id].Modifiers = saved
							if PS and PS.SavePlayerItem then
								pcall(function() PS:SavePlayerItem(self, item_id, self.PS_Items[item_id]) end)
							end
						end
					end
				end
				ITEM:OnEquip(self, item.Modifiers)
			end
		end
	end)
end

function Player:PS_PlayerDeath()
	for item_id, item in pairs(self.PS_Items) do
		if item.Equipped then
			local ITEM = PS.Items[item_id]
			ITEM:OnHolster(self, item.Modifiers)
		end
	end
end

function Player:PS_PlayerInitialSpawn()
	self.PS_Points = 0
	self.PS_Items = {}
	self.PS_DataLoaded = false

	-- Load data immediately (database queries are async)
	-- Don't send initial state - let client show "Loading..." until real data arrives
	self:PS_LoadData()
	-- SendClientsideModels will be called after data loads in PS_LoadData callback

	if PS.Config.NotifyOnJoin then
		if PS.Config.ShopKey ~= '' then
			timer.Simple(5, function() -- Give them time to load up
				if !IsValid(self) then return end
				self:PS_Notify('Press ' .. PS.Config.ShopKey .. ' to open PointShop!')
			end)
		end

		if PS.Config.ShopCommand ~= '' then
			timer.Simple(5, function() -- Give them time to load up
				if !IsValid(self) then return end
				self:PS_Notify('Type ' .. PS.Config.ShopCommand .. ' in console to open PointShop!')
			end)
		end

		if PS.Config.ShopChatCommand ~= '' then
			timer.Simple(5, function() -- Give them time to load up
				if !IsValid(self) then return end
				self:PS_Notify('Type ' .. PS.Config.ShopChatCommand .. ' in chat to open PointShop!')
			end)
		end

		timer.Simple(10, function() -- Give them time to load up
			if !IsValid(self) then return end
			self:PS_Notify('You have ' .. self:PS_GetPoints() .. ' ' .. PS.Config.PointsName .. ' to spend!')
		end)
	end

	if PS.Config.PointsOverTime then
		timer.Create('PS_PointsOverTime_' .. self:SteamID64(), PS.Config.PointsOverTimeDelay * 60, 0, function()
			if !IsValid(self) then return end
			self:PS_GivePoints(PS.Config.PointsOverTimeAmount)
			self:PS_Notify("You've been given ", PS.Config.PointsOverTimeAmount, " ", PS.Config.PointsName, " for playing on the server!")
		end)
	end
end

function Player:PS_PlayerDisconnected()
	PS.ClientsideModels[self] = nil

	if timer.Exists('PS_PointsOverTime_' .. self:SteamID64()) then
		timer.Destroy('PS_PointsOverTime_' .. self:SteamID64())
	end
end

function Player:PS_Save()
	PS:SetPlayerData(self, self.PS_Points, self.PS_Items)
end

function Player:PS_LoadData()
	self.PS_Points = 0
	self.PS_Items = {}

	PS:GetPlayerData(self, function(points, items)
		self.PS_Points = points
		self.PS_Items = items
		self.PS_DataLoaded = true

		-- Small delay to ensure player entity is networked to client before sending data
		timer.Simple(0.1, function()
			if not IsValid(self) then return end
			self:PS_SendPoints()
			self:PS_SendItems()
			-- Ensure clients receive clientsidemodel info after items are loaded
			self:PS_SendClientsideModels()
		end)
	end)
end

function Player:PS_CanPerformAction(itemname)
	local allowed = true
	local itemexcept = false
	if itemname then itemexcept = PS.Items[itemname].Except end

	if (self.IsSpec and self:IsSpec()) and not itemexcept then allowed = false end
	if not self:Alive() and not itemexcept then allowed = false end


	if not allowed then
		self:PS_Notify('You\'re not allowed to do that at the moment!')
	end

	return allowed
end

-- points

function Player:PS_GivePoints(points)
	self.PS_Points = self.PS_Points + points
	PS:GivePlayerPoints(self, points)
	self:PS_SendPoints()
end

function Player:PS_TakePoints(points)
	self.PS_Points = self.PS_Points - points >= 0 and self.PS_Points - points or 0
	PS:SetPlayerPoints(self, self.PS_Points)
	self:PS_SendPoints()
end

function Player:PS_SetPoints(points)
	self.PS_Points = points
	PS:SetPlayerPoints(self, points)
	self:PS_SendPoints()
end

function Player:PS_GetPoints()
	return self.PS_Points and self.PS_Points or 0
end

function Player:PS_HasPoints(points)
	return self.PS_Points >= points
end

-- give/take items

function Player:PS_GiveItem(item_id)
	if not PS.Items[item_id] then return false end

	self.PS_Items[item_id] = { Modifiers = {}, Equipped = false }

	PS:GivePlayerItem(self, item_id, self.PS_Items[item_id])

	self:PS_SendItems()

	return true
end

function Player:PS_TakeItem(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end

	self.PS_Items[item_id] = nil

	PS:TakePlayerItem(self, item_id)

	self:PS_SendItems()

	return true
end

-- buy/sell items

function Player:PS_BuyItem(item_id)
	if not self.PS_DataLoaded then return false end
	local ITEM = PS.Items[item_id]
	if not ITEM then return false end

	-- Prevent buying items the player already owns
	if self:PS_HasItem(item_id) then
		self:PS_Notify('You already own this item!')
		return false
	end

	local points = math.max(0, PS.Config.CalculateBuyPrice(self, ITEM))

	if not self:PS_HasPoints(points) then return false end
	if not self:PS_CanPerformAction(item_id) then return end

	if ITEM.AdminOnly and not self:IsAdmin() then
		self:PS_Notify('This item is Admin only!')
		return false
	end

	if ITEM.AllowedUserGroups and #ITEM.AllowedUserGroups > 0 then
		if not table.HasValue(ITEM.AllowedUserGroups, self:PS_GetUsergroup()) then
			self:PS_Notify('You\'re not in the right group to buy this item!')
			return false
		end
	end

	local cat_name = ITEM.Category
	local CATEGORY = PS:FindCategoryByName(cat_name)

	if CATEGORY then
		if CATEGORY.AllowedUserGroups and #CATEGORY.AllowedUserGroups > 0 then
			if not table.HasValue(CATEGORY.AllowedUserGroups, self:PS_GetUsergroup()) then
				self:PS_Notify('You\'re not in the right group to buy this item!')
				return false
			end
		end

		if CATEGORY.CanPlayerSee then
			if not CATEGORY:CanPlayerSee(self) then
				self:PS_Notify('You\'re not allowed to buy this item!')
				return false
			end
		end
	end

	if ITEM.CanPlayerBuy then -- should exist but we'll check anyway
		local allowed, message
		if ( type(ITEM.CanPlayerBuy) == "function" ) then
			allowed, message = ITEM:CanPlayerBuy(self)
		elseif ( type(ITEM.CanPlayerBuy) == "boolean" ) then
			allowed = ITEM.CanPlayerBuy
		end

		if not allowed then
			self:PS_Notify(message or 'You\'re not allowed to buy this item!')
			return false
		end
	end

	self:PS_TakePoints(points)

	self:PS_Notify('Bought ', ITEM.Name, ' for ', points, ' ', PS.Config.PointsName)

	ITEM:OnBuy(self)
	
	hook.Call( "PS_ItemPurchased", nil, self, item_id )

	if ITEM.SingleUse then
		self:PS_Notify('Single use item. You\'ll have to buy this item again next time!')
		return
	end

	self:PS_GiveItem(item_id)
	self:PS_EquipItem(item_id)
end

function Player:PS_SellItem(item_id)
	if not self.PS_DataLoaded then return false end
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end

	local ITEM = PS.Items[item_id]

	if ITEM.CanPlayerSell then -- should exist but we'll check anyway
		local allowed, message
		if ( type(ITEM.CanPlayerSell) == "function" ) then
			allowed, message = ITEM:CanPlayerSell(self)
		elseif ( type(ITEM.CanPlayerSell) == "boolean" ) then
			allowed = ITEM.CanPlayerSell
		end

		if not allowed then
			self:PS_Notify(message or 'You\'re not allowed to sell this item!')
			return false
		end
	end

	local points = math.max(0, PS.Config.CalculateSellPrice(self, ITEM))
	self:PS_GivePoints(points)

	if self.PS_Items[item_id] and self.PS_Items[item_id].Equipped then
		ITEM:OnHolster(self)
	end
	ITEM:OnSell(self)
	
	hook.Call( "PS_ItemSold", nil, self, item_id )

	self:PS_Notify('Sold ', ITEM.Name, ' for ', points, ' ', PS.Config.PointsName)

	return self:PS_TakeItem(item_id)
end

function Player:PS_HasItem(item_id)
	return self.PS_Items[item_id] or false
end

function Player:PS_HasItemEquipped(item_id)
	if not self:PS_HasItem(item_id) then return false end

	return self.PS_Items[item_id].Equipped or false
end

function Player:PS_NumItemsEquippedFromCategory(cat_name)
	local count = 0

	for item_id, item in pairs(self.PS_Items) do
		local ITEM = PS.Items[item_id]
		if ITEM.Category == cat_name and item.Equipped then
			count = count + 1
		end
	end

	return count
end

-- equip/hoster items

function Player:PS_EquipItem(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if not self:PS_CanPerformAction(item_id) then return false end

	local ITEM = PS.Items[item_id]

	local allowed, message
	if type(ITEM.CanPlayerEquip) == 'function' then
		allowed, message = ITEM:CanPlayerEquip(self)
	elseif type(ITEM.CanPlayerEquip) == 'boolean' then
		allowed = ITEM.CanPlayerEquip
	else
		allowed = true
	end

	if not allowed then
		self:PS_Notify(message or 'You\'re not allowed to equip this item!')
		return false
	end

	local cat_name = ITEM.Category
	local CATEGORY = PS:FindCategoryByName(cat_name)

	-- Enforce team restriction from category (e.g. bear models vs victim models)
	if CATEGORY and CATEGORY.AllowedTeams and #CATEGORY.AllowedTeams > 0 then
		local teamAllowed = false
		for _, tid in ipairs(CATEGORY.AllowedTeams) do
			if self:Team() == tid then teamAllowed = true break end
		end
		if not teamAllowed then
			self:PS_Notify('You\'re not on the right team to equip this item!')
			return false
		end
	end

	if CATEGORY and CATEGORY.AllowedEquipped > -1 then
		if self:PS_NumItemsEquippedFromCategory(cat_name) + 1 > CATEGORY.AllowedEquipped then
			self:PS_Notify('Only ' .. CATEGORY.AllowedEquipped .. ' item' .. (CATEGORY.AllowedEquipped == 1 and '' or 's') .. ' can be equipped from this category!')
			return false
		end
	end

	if PS.Items[item_id].Slot then
		for id, item in pairs(self.PS_Items) do
			if item_id ~= id and PS.Items[id].Slot and PS.Items[id].Slot == PS.Items[item_id].Slot and self.PS_Items[id].Equipped then
				self:PS_HolsterItem(id)
			end
		end
	end
	
	-- Unequip other playermodels that share any AllowedTeams overlap
	-- e.g. equipping any victim model holsters all other equipped victim models,
	-- across all victim tabs (normal, VIP, reserved, etc.)
	if ITEM.TYPE == "playermodel" and CATEGORY then
		-- Build a set of the new item's allowed teams for fast lookup
		local newTeams = {}
		if CATEGORY.AllowedTeams then
			for _, tid in ipairs(CATEGORY.AllowedTeams) do newTeams[tid] = true end
		end

		for id, item in pairs(self.PS_Items) do
			if item_id ~= id and PS.Items[id] and PS.Items[id].TYPE == "playermodel" and self.PS_Items[id].Equipped then
				local otherCategory = PS:FindCategoryByName(PS.Items[id].Category)
				if otherCategory then
					-- Holster if teams overlap (same team group) OR same category name
					local overlap = false
					if otherCategory.AllowedTeams then
						for _, tid in ipairs(otherCategory.AllowedTeams) do
							if newTeams[tid] then overlap = true break end
						end
					end
					if overlap or otherCategory.Name == CATEGORY.Name then
						self:PS_HolsterItem(id)
					end
				end
			end
		end
	end


	if CATEGORY and CATEGORY.SharedCategories then
		local ConCatCats = CATEGORY.Name
		for p, c in pairs( CATEGORY.SharedCategories ) do
			if p ~= #CATEGORY.SharedCategories then
				ConCatCats = ConCatCats .. ', ' .. c
			else
				if #CATEGORY.SharedCategories ~= 1 then
					ConCatCats = ConCatCats .. ', and ' .. c
				else
					ConCatCats = ConCatCats .. ' and ' .. c
				end
			end
		end
		local NumEquipped = self.PS_NumItemsEquippedFromCategory
		for id, item in pairs(self.PS_Items) do
			if not self:PS_HasItemEquipped(id) then continue end
			local CatName = PS.Items[id].Category
			local Cat = PS:FindCategoryByName( CatName )
			if not Cat.SharedCategories then continue end
			for _, SharedCategory in pairs( Cat.SharedCategories ) do
				if SharedCategory == CATEGORY.Name then
					if Cat.AllowedEquipped > -1 and CATEGORY.AllowedEquipped > -1 then
						if NumEquipped(self,CatName) + NumEquipped(self,CATEGORY.Name) + 1 > Cat.AllowedEquipped then
							self:PS_Notify('Only ' .. Cat.AllowedEquipped .. ' item'.. (Cat.AllowedEquipped == 1 and '' or 's') ..' can be equipped over ' .. ConCatCats .. '!')
							return false
						end
					end
				end
			end
		end
	end

	self.PS_Items[item_id].Equipped = true

	ITEM:OnEquip(self, self.PS_Items[item_id].Modifiers)

	self:PS_Notify('Equipped ', ITEM.Name, '.')
	
	hook.Call( "PS_ItemUpdated", nil, self, item_id, PS_ITEM_EQUIP )

	PS:SavePlayerItem(self, item_id, self.PS_Items[item_id])

	self:PS_SendItems()
end

function Player:PS_HolsterItem(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if not self:PS_CanPerformAction(item_id) then return false end

	local ITEM = PS.Items[item_id]

	local allowed, message
	if type(ITEM.CanPlayerHolster) == 'function' then
		allowed, message = ITEM:CanPlayerHolster(self)
	elseif type(ITEM.CanPlayerHolster) == 'boolean' then
		allowed = ITEM.CanPlayerHolster
	else
		allowed = true
	end

	if not allowed then
		self:PS_Notify(message or 'You\'re not allowed to holster this item!')
		return false
	end

	self.PS_Items[item_id].Equipped = false

	ITEM:OnHolster(self)

	self:PS_Notify('Holstered ', ITEM.Name, '.')
	
	hook.Call( "PS_ItemUpdated", nil, self, item_id, PS_ITEM_HOLSTER )

	PS:SavePlayerItem(self, item_id, self.PS_Items[item_id])

	self:PS_SendItems()
end


local function Sanitize( modifications ) -- default when item has no SanitizeTable; clamps both fields against abuse
	local out = {}
	if isstring(modifications.text) then
		out.text = string.sub(modifications.text, 1, 256)
	end
	if modifications.color then
		out.color = Color(
			math.Clamp(math.floor(modifications.color.r or 255), 0, 255),
			math.Clamp(math.floor(modifications.color.g or 255), 0, 255),
			math.Clamp(math.floor(modifications.color.b or 255), 0, 255)
		)
	end
	return out
end

function Player:PS_ModifyItem(item_id, modifications)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if type(modifications) ~= "table" then return false end
	if not self:PS_CanPerformAction(item_id) then return false end
	
	local ITEM = PS.Items[item_id]

	-- This if block helps prevent someone from sending a table full of random junk that will fill up the server's RAM, be networked to every player, and be stored in the database
	if ITEM.SanitizeTable then 
		modifications = ITEM:SanitizeTable(modifications)
	else
		modifications = Sanitize(modifications)
	end

	for key, value in pairs(modifications) do
		self.PS_Items[item_id].Modifiers[key] = value
	end

	ITEM:OnModify(self, self.PS_Items[item_id].Modifiers)

	hook.Call( "PS_ItemUpdated", nil, self, item_id, PS_ITEM_MODIFY, modifications )
	
	PS:SavePlayerItem(self, item_id, self.PS_Items[item_id])

	self:PS_SendItems()
end

-- clientside Models

function Player:PS_AddClientsideModel(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end

	net.Start('PS_AddClientsideModel')
		net.WriteEntity(self)
		net.WriteString(item_id)
	net.Broadcast()

	if not PS.ClientsideModels[self] then PS.ClientsideModels[self] = {} end

	PS.ClientsideModels[self][item_id] = item_id
end

function Player:PS_RemoveClientsideModel(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if not PS.ClientsideModels[self] or not PS.ClientsideModels[self][item_id] then return false end

	net.Start('PS_RemoveClientsideModel')
		net.WriteEntity(self)
		net.WriteString(item_id)
	net.Broadcast()

	PS.ClientsideModels[self][item_id] = nil
end

-- menu stuff

function Player:PS_ToggleMenu(show)
	net.Start('PS_ToggleMenu')
	net.Send(self)
end

-- send stuff

function Player:PS_SendPoints()
	net.Start('PS_Points')
		net.WriteEntity(self)
		net.WriteInt(self.PS_Points, 32)
	net.Send(self)  -- Send only to this player (privacy + efficiency)
end

function Player:PS_SendItems()
	net.Start('PS_Items')
		net.WriteEntity(self)
		net.WriteTable(self.PS_Items)
	net.Send(self)  -- Send only to item owner (other clients get PS_AddClientsideModel messages)
end

function Player:PS_SendClientsideModels()
	-- Convert entity keys to EntIndex for reliable net serialization
	local data = {}
	for ply, items in pairs(PS.ClientsideModels) do
		if IsValid(ply) then
			data[ply:EntIndex()] = items
		end
	end
	net.Start('PS_SendClientsideModels')
		net.WriteTable(data)
	net.Send(self)
end

-- notifications

function Player:PS_Notify(...)
	local str = table.concat({...}, '')

	net.Start('PS_SendNotification')
		net.WriteString(str)
	net.Send(self)
end

-- net receiver for data requests
util.AddNetworkString('PS_RequestData')
net.Receive('PS_RequestData', function(len, ply)
	if not IsValid(ply) then return end
	
	-- Send fresh points and items data
	ply:PS_SendPoints()
	ply:PS_SendItems()
end)

-- Team change handler: re-apply correct team's playermodel
hook.Add("OnPlayerChangedTeam", "PS_ReapplyTeamModel", function(ply, oldTeam, newTeam)
	if not IsValid(ply) or not ply.PS_Items or not ply:Alive() then return end
	
	-- Delay slightly to ensure team change is fully processed
	timer.Simple(0.1, function()
		if not IsValid(ply) or not ply:Alive() then return end
		
		-- Re-apply all equipped items (only the correct team's model will actually apply)
		for item_id, item_data in pairs(ply.PS_Items) do
			if item_data.Equipped then
				local ITEM = PS.Items[item_id]
				if ITEM and ITEM.TYPE == "playermodel" then
					local cat_name = ITEM.Category
					local CATEGORY = PS:FindCategoryByName(cat_name)
					
					-- Check if this model is for the new team
					if CATEGORY and CATEGORY.AllowedTeams and #CATEGORY.AllowedTeams > 0 then
						local teamAllowed = false
						for _, tid in ipairs(CATEGORY.AllowedTeams) do
							if newTeam == tid then
								teamAllowed = true
								break
							end
						end
						
						-- If this model matches the new team, apply it
						if teamAllowed then
							ITEM:OnEquip(ply, item_data.Modifiers)
							
							if PS.Config.Debug then
								print("[PS] Team change: Applied " .. ITEM.Name .. " to " .. ply:Nick() .. " (team " .. oldTeam .. " -> " .. newTeam .. ")")
							end
							break -- Only apply one playermodel
						end
					end
				end
			end
		end
	end)
end)
