PS.Config = {}

-- Player usergroup helper (compatibility wrapper)
local meta = FindMetaTable("Player")
if not meta.PS_GetUsergroup then
	function meta:PS_GetUsergroup()
		return self:GetUserGroup() or "user"
	end
end

-- Edit below

PS.Config.Debug = false -- Enable debug prints (console output for troubleshooting)

PS.Config.CommunityName = "My Community"

PS.Config.DataProvider = 'pdata'

PS.Config.Branch = '' -- (Unused) This Enhanced Edition versions independently; no upstream version checking.
PS.Config.CheckVersion = false -- Disabled: this fork does not phone home to the original PointShop repo.

PS.Config.ShopKey = 'F3' -- Any Uppercase key or blank to disable
PS.Config.ShopCommand = 'ps_shop' -- Console command to open the shop, set to blank to disable
PS.Config.ShopChatCommand = '!shop' -- Chat command to open the shop, set to blank to disable

PS.Config.NotifyOnJoin = true -- Should players be notified about opening the shop when they spawn?

PS.Config.PointsOverTime = true -- Should players be given points over time?
PS.Config.PointsOverTimeDelay = 1 -- If so, how many minutes apart?
PS.Config.PointsOverTimeAmount = 10 -- And if so, how many points to give after the time?

PS.Config.AdminCanAccessAdminTab = true -- Can Admins access the Admin tab?
PS.Config.SuperAdminCanAccessAdminTab = true -- Can SuperAdmins access the Admin tab?

PS.Config.CanPlayersGivePoints = true -- Can players give points away to other players?
PS.Config.DisplayPreviewInMenu = true -- Can players see the preview of their items in the menu?

PS.Config.PointsName = 'Points' -- What are the points called?
PS.Config.SortItemsBy = 'Name' -- How are items sorted? Set to 'Price' to sort by price.

-- Edit below if you know what you're doing

PS.Config.CalculateBuyPrice = function(ply, item)
	-- You can do different calculations here to return how much an item should cost to buy.
	-- There are a few examples below, uncomment them to use them.
	
	-- Everything half price for admins:
	-- if ply:IsAdmin() then return math.Round(item.Price * 0.5) end
	
	-- 25% off for the 'donators' group
	-- if ply:IsUserGroup('donators') then return math.Round(item.Price * 0.75) end
	
	-- Use new helper functions (see bottom of this file):
	-- if PS.Config.IsVIP(ply) then return math.Round(item.Price * 0.8) end -- 20% off for VIPs
	-- if PS.Config.IsStaff(ply) then return math.Round(item.Price * 0.5) end -- 50% off for staff
	
	return item.Price
end

PS.Config.CalculateSellPrice = function(ply, item)
	return math.Round(item.Price * 0.75) -- 75% or 3/4 (rounded) of the original item price
end

-- Helper functions for group checking
PS.Config.IsVIP = function(ply)
	if not IsValid(ply) then return false end
	local ugroup = ply:PS_GetUsergroup()
	
	if PS.Config.Debug then
		print("[PS DEBUG] IsVIP check for " .. ply:Nick() .. " - UserGroup: " .. tostring(ugroup))
	end
	
	-- Check if CORE.VIP_Groups exists (from bear_hunt gamemode)
	if CORE and CORE.VIP_Groups then
		for _, group in ipairs(CORE.VIP_Groups) do
			if ugroup == group then 
				if PS.Config.Debug then
					print("[PS DEBUG] " .. ply:Nick() .. " IS VIP (matched group: " .. group .. " from CORE.VIP_Groups)")
				end
				return true 
			end
		end
	end
	
	-- Fallback: check standard VIP groups
	local vipGroups = { "vip", "vipmax", "megadonator", "trialmod_vip", "trialmod_vipmax", 
	                     "trialmod_megadonator", "mod_vip", "mod_vipmax", "mod_megadonator", 
	                     "headmod", "admin", "owner" }
	for _, group in ipairs(vipGroups) do
		if ugroup == group then 
			if PS.Config.Debug then
				print("[PS DEBUG] " .. ply:Nick() .. " IS VIP (matched group: " .. group .. " from fallback list)")
			end
			return true 
		end
	end
	
	if PS.Config.Debug then
		print("[PS DEBUG] " .. ply:Nick() .. " is NOT VIP")
	end
	return false
end

PS.Config.IsStaff = function(ply)
	if not IsValid(ply) then return false end
	local ugroup = ply:PS_GetUsergroup()
	
	-- Check if CORE.ADMIN_Groups exists (from bear_hunt gamemode)
	if CORE and CORE.ADMIN_Groups then
		for _, group in ipairs(CORE.ADMIN_Groups) do
			if ugroup == group then return true end
		end
	end
	
	-- Fallback: check standard staff groups
	local staffGroups = { "trialmod", "trialmod_vip", "trialmod_vipmax", "trialmod_megadonator",
	                      "mod", "mod_vip", "mod_vipmax", "mod_megadonator",
	                      "headmod", "admin", "owner" }
	for _, group in ipairs(staffGroups) do
		if ugroup == group then return true end
	end
	
	return false
end

PS.Config.CanAccessAdminTab = function(ply)
	if not IsValid(ply) then return false end
	local ugroup = ply:PS_GetUsergroup()
	
	-- Owner/admin always have access
	if ugroup == "owner" or ugroup == "admin" then return true end
	
	-- Check old config settings for backward compatibility
	if PS.Config.AdminCanAccessAdminTab and ply:IsAdmin() then return true end
	if PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin() then return true end
	
	return false
end

PS.Config.GetVIPTier = function(ply)
	if not IsValid(ply) then return nil end
	local ugroup = ply:PS_GetUsergroup()
	
	-- Return VIP tier level (higher = better)
	local tierMap = {
		["owner"] = 10,
		["admin"] = 10,
		["headmod"] = 10,
		["mod_megadonator"] = 5,
		["trialmod_megadonator"] = 5,
		["megadonator"] = 5,
		["mod_vipmax"] = 4,
		["trialmod_vipmax"] = 4,
		["vipmax"] = 4,
		["mod_vip"] = 3,
		["trialmod_vip"] = 3,
		["vip"] = 3,
	}
	
	return tierMap[ugroup]
end

PS.Config.HasReservedModel = function(ply, teamFilter)
	if not IsValid(ply) then return false end
	
	-- Check if player has any reserved models for their current team or specified team
	if PS and PS.Items then
		for _, item in pairs(PS.Items) do
			if item.ReservedFor and item.AllowedTeam then
				-- Check team filter
				local teamMatch = true
				if teamFilter then
					teamMatch = (item.AllowedTeam == teamFilter)
				end
				
				if teamMatch then
					local steamID = ply:SteamID()
					-- Check if this item is reserved for this player
					if type(item.ReservedFor) == "table" then
						for _, sid in ipairs(item.ReservedFor) do
							if sid == steamID then return true end
						end
					elseif item.ReservedFor == steamID then
						return true
					end
				end
			end
		end
	end
	
	return false
end
