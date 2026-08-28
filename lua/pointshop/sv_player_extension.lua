PS_ITEM_EQUIP = 1
PS_ITEM_HOLSTER = 2
PS_ITEM_MODIFY = 3

local Player = FindMetaTable('Player')

-- ============================================================================
-- PLAYERMODEL RESOLUTION
--
-- One function decides which playermodel a player wears. Spawn, team change and holster all
-- call it rather than each running their own search.
--
-- They used to run three near-identical loops over the equipped items, each with its own
-- hand-rolled copy of the AllowedTeams check, and each doing something different when no
-- model matched: spawn skipped, team change did nothing at all, holster restored a snapshot.
-- The system only held together because two of those three happened to cover the third's
-- gap — a death holstered everything, and a respawn refused wrong-team models — so a stale
-- _PS_ActivePlayerModel was never reachable in practice. It worked, but nothing in the
-- team-change path said why, and closing either cover would have opened it.
-- ============================================================================

-- Fills in saved customization for an item whose modifiers are empty.
local function LoadModifiers(ply, item_id, item)
	if item.Modifiers and next(item.Modifiers) ~= nil then return item.Modifiers end
	if not PS_GetCustomization then return item.Modifiers end

	local saved = PS_GetCustomization(ply, item_id)
	if not (saved and type(saved) == "table" and next(saved) ~= nil) then return item.Modifiers end

	ply.PS_Items[item_id].Modifiers = saved
	if PS and PS.SavePlayerItem then
		pcall(function() PS:SavePlayerItem(ply, item_id, ply.PS_Items[item_id]) end)
	end

	return saved
end

-- The equipped playermodel valid for this player's team right now, or nil.
--
-- Sorted rather than raw pairs(): a player with two models valid for the same team used to
-- get whichever the hash order surfaced first, which is stable within a session and not
-- across them. Same input, same model.
local function FindTeamModel(ply)
	local ids = {}
	for item_id, item in pairs(ply.PS_Items or {}) do
		local ITEM = PS.Items[item_id]
		if ITEM and item.Equipped and ITEM.TYPE == "playermodel" and PS:CanEquipForTeam(ply, ITEM) then
			ids[#ids + 1] = item_id
		end
	end

	if #ids == 0 then return nil end

	table.sort(ids)
	return PS.Items[ids[1]], ids[1]
end

-- Applies the right playermodel, or hands the decision back to the gamemode.
--
-- The `else` branch is the part that was missing. Clearing the flag matters as much as
-- setting it: it is what the ModelFix timer reads to decide whether a non-team model is
-- legitimate, so a flag left pointing at a model the player is no longer allowed to wear is
-- a hole waiting for its covers to be removed.
function Player:PS_ResolvePlayerModel()
	local ITEM, item_id = FindTeamModel(self)

	if ITEM then
		ITEM:OnEquip(self, LoadModifiers(self, item_id, self.PS_Items[item_id]))
		return true
	end

	self._PS_ActivePlayerModel = nil
	hook.Run("PlayerSetModel", self)
	return false
end

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

			-- An item deleted from the server while a player still owns it leaves ITEM
			-- nil. Without this the next line errors and aborts the WHOLE loop, so one
			-- stale entry means the player spawns with nothing equipped at all.
			--
			-- Playermodels are skipped here and resolved once below: which one applies
			-- depends on the player's team, so it is a choice between items rather than a
			-- decision each item can make for itself.
			if ITEM and item.Equipped and ITEM.TYPE ~= "playermodel" then
				ITEM:OnEquip(self, LoadModifiers(self, item_id, item))
			end
		end

		self:PS_ResolvePlayerModel()
	end)
end

function Player:PS_PlayerDeath()
	for item_id, item in pairs(self.PS_Items) do
		if item.Equipped then
			local ITEM = PS.Items[item_id]
			if ITEM then ITEM:OnHolster(self, item.Modifiers) end
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
	if itemname and PS.Items[itemname] then itemexcept = PS.Items[itemname].Except end

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

	self:PS_SendItemDelta(PS_DELTA_ADD, item_id)

	return true
end

function Player:PS_TakeItem(item_id)
	-- Deliberately does NOT require PS.Items[item_id] to exist.
	--
	-- Ownership is the authority here, and that's what PS_HasItem checks. Gating removal
	-- on a live item definition made an item whose Lua file had been deleted permanently
	-- unremovable: the row stayed in the player's inventory and in storage, and nothing
	-- — admin panel or otherwise — could reach it.
	--
	-- The sell path (PS_SellItem) resolves and validates ITEM before it gets here, so
	-- this doesn't loosen anything for selling.
	if not item_id then return false end
	if not self:PS_HasItem(item_id) then return false end

	self.PS_Items[item_id] = nil

	PS:TakePlayerItem(self, item_id)

	self:PS_SendItemDelta(PS_DELTA_REMOVE, item_id)

	return true
end

-- buy/sell items

function Player:PS_BuyItem(item_id, initial_mods)
	if not self.PS_DataLoaded then return false end
	local ITEM = PS.Items[item_id]
	if not ITEM then return false end

	-- Guard against duplicate buy messages arriving before this call completes
	if self._PS_Purchasing then return false end
	self._PS_Purchasing = true

	local function finish(result)
		self._PS_Purchasing = nil
		return result
	end

	-- Prevent buying items the player already owns
	if self:PS_HasItem(item_id) then
		self:PS_Notify('You already own this item!')
		return finish(false)
	end

	local points = math.max(0, PS.Config.CalculateBuyPrice(self, ITEM))

	if not self:PS_HasPoints(points) then return finish(false) end
	if not self:PS_CanPerformAction(item_id) then return finish(false) end

	if ITEM.AdminOnly and not self:IsAdmin() then
		self:PS_Notify('This item is Admin only!')
		return finish(false)
	end

	if ITEM.AllowedUserGroups and #ITEM.AllowedUserGroups > 0 then
		if not table.HasValue(ITEM.AllowedUserGroups, self:PS_GetUsergroup()) then
			self:PS_Notify('You\'re not in the right group to buy this item!')
			return finish(false)
		end
	end

	local cat_name = ITEM.Category
	local CATEGORY = PS:FindCategoryByName(cat_name)

	if CATEGORY then
		if CATEGORY.AllowedUserGroups and #CATEGORY.AllowedUserGroups > 0 then
			if not table.HasValue(CATEGORY.AllowedUserGroups, self:PS_GetUsergroup()) then
				self:PS_Notify('You\'re not in the right group to buy this item!')
				return finish(false)
			end
		end

		if CATEGORY.CanPlayerSee then
			if not CATEGORY:CanPlayerSee(self) then
				self:PS_Notify('You\'re not allowed to buy this item!')
				return finish(false)
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
			return finish(false)
		end
	end

	-- ITEM:OnBuy is item-supplied code. Run it BEFORE taking payment and inside a pcall:
	-- if it errors, the player keeps their points instead of paying for nothing.
	local ok, err = pcall(function() ITEM:OnBuy(self) end)
	if not ok then
		ErrorNoHalt("[PointShop] OnBuy failed for '" .. tostring(item_id) .. "': " .. tostring(err) .. "\n")
		self:PS_Notify('Something went wrong buying that item. You have not been charged.')
		return finish(false)
	end

	self:PS_TakePoints(points)
	self:PS_Notify('Bought ', ITEM.Name, ' for ', points, ' ', PS.Config.PointsName)

	hook.Call( "PS_ItemPurchased", nil, self, item_id )

	if ITEM.SingleUse then
		self:PS_Notify('Single use item. You\'ll have to buy this item again next time!')
		return finish(true)
	end

	-- Everything past payment is wrapped too. An error here must not leave
	-- _PS_Purchasing latched, or that player can never buy anything again without
	-- reconnecting — finish() below is what clears it, and it has to be reached.
	local ok2, err2 = pcall(function()
		self:PS_GiveItem(item_id)

		-- Persist try-before-you-buy mods BEFORE equip: OnEquip resolves via
		-- PS_GetCustomization, which must find the SQL row so the item applies
		-- and broadcasts with the pre-purchase customization on first equip.
		if initial_mods and PS_SetCustomization and PS_SanitizeCustomizationData then
			local safe = PS_SanitizeCustomizationData(initial_mods, ITEM.TYPE or "accessory")
			if next(safe) ~= nil then
				PS_SetCustomization(self, item_id, safe)
			end
		end

		self:PS_EquipItem(item_id)
	end)

	if not ok2 then
		-- The item was paid for; grant it even if equipping blew up, so the purchase
		-- isn't silently lost.
		ErrorNoHalt("[PointShop] Post-purchase step failed for '" .. tostring(item_id) .. "': " .. tostring(err2) .. "\n")
		if not self:PS_HasItem(item_id) then
			pcall(function() self:PS_GiveItem(item_id) end)
		end
	end

	return finish(true)
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

	-- Item-supplied callbacks run first, in a pcall. Payment used to be credited before
	-- these, so an error left the player paid AND still holding the item.
	local ok, err = pcall(function()
		if self.PS_Items[item_id] and self.PS_Items[item_id].Equipped then
			ITEM:OnHolster(self)
		end
		ITEM:OnSell(self)
	end)

	if not ok then
		ErrorNoHalt("[PointShop] OnSell/OnHolster failed for '" .. tostring(item_id) .. "': " .. tostring(err) .. "\n")
		self:PS_Notify('Something went wrong selling that item. Nothing has changed.')
		return false
	end

	-- Remove before paying: if TakeItem fails the player keeps the item and gets nothing,
	-- which is recoverable. Paying first and failing to remove hands out free points.
	if not self:PS_TakeItem(item_id) then
		self:PS_Notify('Something went wrong selling that item. Nothing has changed.')
		return false
	end

	self:PS_GivePoints(points)

	hook.Call( "PS_ItemSold", nil, self, item_id )

	self:PS_Notify('Sold ', ITEM.Name, ' for ', points, ' ', PS.Config.PointsName)

	return true
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
		if ITEM and ITEM.Category == cat_name and item.Equipped then
			count = count + 1
		end
	end

	return count
end

-- equip/hoster items

-- May this player wear this item at all?
--
-- Returns ok, reason. The reason is returned rather than notified, because the caller decides
-- whether one refusal is worth telling someone about: equipping one item says so, applying a
-- loadout of six would otherwise print six lines about the two it skipped.
--
-- Deliberately only the checks that depend on the PLAYER and the ITEM, not on what else is
-- being worn. The AllowedEquipped and shared-category limits are counts over a SET, and the
-- two callers have different sets -- equip counts against what is currently on, a loadout
-- counts against itself -- so a single predicate cannot answer for both and pretending it can
-- is how a loadout of two hats gets past a one-hat limit.
--
-- Extracted so there is one implementation. Three hand-rolled copies of a team check had
-- already drifted apart elsewhere in this addon before anyone noticed.
function Player:PS_CanEquipItem(item_id)
	-- Buy and sell already gate on this; equip/holster/modify didn't, and they all reach
	-- the provider's save path. Acting before the load callback returns means writing
	-- against an inventory that isn't populated yet.
	if not self.PS_DataLoaded then return false, 'Your inventory has not finished loading.' end
	if not PS.Items[item_id] then return false, 'That item does not exist.' end
	if not self:PS_HasItem(item_id) then return false, 'You do not own that item.' end
	if not self:PS_CanPerformAction(item_id) then return false, 'You cannot do that right now.' end

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
		return false, message or 'You\'re not allowed to equip this item!'
	end

	if not PS:CanEquipForTeam(self, ITEM) then
		return false, 'You\'re not on the right team to equip this item!'
	end

	return true
end

function Player:PS_EquipItem(item_id)
	local ok, reason = self:PS_CanEquipItem(item_id)
	if not ok then
		-- Only the refusals that used to speak still speak. The three silent ones above --
		-- data not loaded, no such item, not owned -- returned false without a word, and
		-- saying something now would be a behaviour change smuggled in with a refactor.
		if reason and PS.Items[item_id] and self.PS_DataLoaded and self:PS_HasItem(item_id) then
			self:PS_Notify(reason)
		end
		return false
	end

	local ITEM = PS.Items[item_id]
	local cat_name = ITEM.Category
	local CATEGORY = PS:FindCategoryByName(cat_name)

	if CATEGORY and CATEGORY.AllowedEquipped > -1 then
		if self:PS_NumItemsEquippedFromCategory(cat_name) + 1 > CATEGORY.AllowedEquipped then
			self:PS_Notify('Only ' .. CATEGORY.AllowedEquipped .. ' item' .. (CATEGORY.AllowedEquipped == 1 and '' or 's') .. ' can be equipped from this category!')
			return false
		end
	end

	if PS.Items[item_id].Slot then
		for id, item in pairs(self.PS_Items) do
			if item_id ~= id and PS.Items[id] and PS.Items[id].Slot and PS.Items[id].Slot == PS.Items[item_id].Slot and self.PS_Items[id].Equipped then
				self:PS_HolsterItem(id)
			end
		end
	end
	
	-- Unequip other playermodels that would compete with this one.
	--
	-- What "compete" means depends on whether the gamemode gates by team.
	--
	-- GATING ON (Bear Hunt): a player is meant to keep one model per team, so that whichever
	-- side they end up on has something to wear. Equipping a victim model holsters every
	-- other equipped VICTIM model, across all victim tabs (normal, VIP, reserved), and
	-- leaves the bear model alone. Overlap in AllowedTeams is what "same slot" means here.
	--
	-- GATING OFF (Hide and Seek, and any gamemode whose roles churn mid-round): there are no
	-- teams to keep a model in reserve for, so a second equipped playermodel is not a spare,
	-- it is a competitor. Nothing decides between them except id order in FindTeamModel,
	-- which means what you are wearing depends on which item happened to sort first.
	--
	-- So with gating off, one playermodel holsters all the others. You can only wear one
	-- body, and without teams that is the entire rule.
	if ITEM.TYPE == "playermodel" and CATEGORY then
		local gating = PS:UsesTeamGating()

		-- Build a set of the new item's allowed teams for fast lookup
		local newTeams = {}
		if gating and CATEGORY.AllowedTeams then
			for _, tid in ipairs(CATEGORY.AllowedTeams) do newTeams[tid] = true end
		end

		for id, item in pairs(self.PS_Items) do
			-- PS.Items[id] was indexed four times across these two lines, and
			-- self.PS_Items[id] re-fetched when `item` is already the loop value.
			local otherITEM = PS.Items[id]
			if item_id ~= id and otherITEM and otherITEM.TYPE == "playermodel" and item.Equipped then
				if not gating then
					self:PS_HolsterItem(id)
				else
					local otherCategory = PS:FindCategoryByName(otherITEM.Category)
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
			if not PS.Items[id] then continue end
			local CatName = PS.Items[id].Category
			local Cat = PS:FindCategoryByName( CatName )
			-- FindCategoryByName returns false, not nil, when there's no match — so this
			-- has to test Cat itself before indexing it.
			if not Cat or not Cat.SharedCategories then continue end
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

	self:PS_SendItemDelta(PS_DELTA_UPDATE, item_id)
end

function Player:PS_HolsterItem(item_id)
	if not self.PS_DataLoaded then return false end
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

	self:PS_SendItemDelta(PS_DELTA_UPDATE, item_id)
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
	if not self.PS_DataLoaded then return false end
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

	self:PS_SendItemDelta(PS_DELTA_UPDATE, item_id)
end

-- clientside Models

function Player:PS_AddClientsideModel(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end

	-- EntIndex is sent alongside the entity because net.ReadEntity() returns NULL on the
	-- client when the player hasn't been networked yet. Without an index the client has
	-- no identity to queue the pending item against.
	net.Start('PS_AddClientsideModel')
		net.WriteEntity(self)
		net.WriteUInt(self:EntIndex(), 13)
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
		net.WriteUInt(self:EntIndex(), 13)  -- see PS_SendItems for why
		net.WriteInt(self.PS_Points, 32)
	net.Send(self)  -- Send only to this player (privacy + efficiency)
end

-- Full inventory sync. Kept for the three cases that genuinely need everything:
-- initial load, an explicit client re-request, and the admin clear command.
-- Single-item changes go through PS_SendItemDelta instead — see below.
function Player:PS_SendItems()
	-- EntIndex accompanies the entity because this fires ~0.1s after the player's data
	-- loads, which is right on the boundary of the entity being networked to the client.
	-- Confirmed in a live dump: the join sync arrived the same second as InitPostEntity
	-- with net.ReadEntity() returning NULL, so the whole inventory was silently dropped
	-- and only recovered when opening the shop triggered a second full sync. The index
	-- lets the client queue it and apply once the entity resolves.
	net.Start('PS_Items')
		net.WriteEntity(self)
		net.WriteUInt(self:EntIndex(), 13)
		net.WriteTable(self.PS_Items)
	net.Send(self)  -- Send only to item owner (other clients get PS_AddClientsideModel messages)
end

-- Single-item delta. Replaces the full-table send for equip/holster/modify/give/take.
--
-- net.WriteTable serialises every key and value with a type tag and writes numbers as
-- 8-byte doubles, so an untouched `offset = {0,0,0}` costs ~54 bytes to say "nothing
-- here". A 20-item inventory is several KB, and that whole payload used to go out every
-- time one boolean flipped. PS_WriteModifiers emits a 7-bit flag header and only the
-- fields actually present, as floats — typically ~40 bytes for the whole message.
--
-- op is one of PS_DELTA_ADD / PS_DELTA_REMOVE / PS_DELTA_UPDATE (sh_item_delta.lua).
function Player:PS_SendItemDelta(op, item_id)
	if not item_id then return end

	local entry = self.PS_Items and self.PS_Items[item_id]

	-- Nothing to describe: fall back to a full sync rather than sending a delta that
	-- references an item the client can't resolve.
	if op ~= PS_DELTA_REMOVE and not entry then
		self:PS_SendItems()
		return
	end

	net.Start('PS_ItemDelta')
		net.WriteEntity(self)
		net.WriteUInt(op, 2)
		net.WriteString(item_id)

		if op ~= PS_DELTA_REMOVE then
			net.WriteBool(entry.Equipped and true or false)
			PS_WriteModifiers(entry.Modifiers)
		end
	net.Send(self)

	if PS and PS.Config and PS.Config.Debug then
		local opName = (op == PS_DELTA_ADD and "ADD")
			or (op == PS_DELTA_REMOVE and "REMOVE")
			or (op == PS_DELTA_UPDATE and "UPDATE") or ("?" .. tostring(op))
		print(string.format("[PS DELTA] -> %s  op=%s id=%s equipped=%s (inventory has %d items)",
			self:Nick(), opName, tostring(item_id),
			entry and tostring(entry.Equipped) or "n/a",
			table.Count(self.PS_Items or {})))
	end
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

-- Team change: re-resolve which playermodel applies.
--
-- This used to search for a model valid for the new team and apply it, and do nothing at all
-- when it found none — leaving the previous team's model on and its flag set. The resolver
-- covers both outcomes, so the "none" case now clears the flag and asks the gamemode for its
-- own default instead of leaving the decision to whatever ran next.
--
-- Still delayed a tick: SetTeam fires this before the rest of the team change has settled,
-- and CanEquipForTeam reads ply:Team().
hook.Add("OnPlayerChangedTeam", "PS_ReapplyTeamModel", function(ply, oldTeam, newTeam)
	if not IsValid(ply) or not ply.PS_Items or not ply:Alive() then return end

	timer.Simple(0.1, function()
		if not IsValid(ply) or not ply:Alive() then return end

		local applied = ply:PS_ResolvePlayerModel()

		if PS.Config.Debug then
			print(string.format("[PS] Team change %d -> %d for %s: %s",
				oldTeam, newTeam, ply:Nick(),
				applied and "applied a shop model" or "handed back to the gamemode"))
		end
	end)
end)
