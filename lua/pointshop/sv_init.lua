--[[
	pointshop/sv_init.lua
	first file included serverside.
]]--

include "sh_init.lua"
include "sv_player_extension.lua"
include "sv_manifest.lua"

-- net hooks

-- Per-player action rate limiter. Prevents spam that could cause race conditions or server load.
-- Cooldowns are intentionally short — just enough to prevent machine-speed abuse.
local PS_COOLDOWNS = { buy = 0.5, sell = 0.5, equip = 0.3, holster = 0.3, modify = 1.0 }
local function PS_RateLimit(ply, action)
	if not IsValid(ply) then return false end
	ply._PS_LastAction = ply._PS_LastAction or {}
	local cd = PS_COOLDOWNS[action] or 0.5
	if CurTime() - (ply._PS_LastAction[action] or 0) < cd then return false end
	ply._PS_LastAction[action] = CurTime()
	return true
end

net.Receive('PS_BuyItem', function(length, ply)
	local item_id = net.ReadString()
	local initial_mods = net.ReadBool() and net.ReadTable() or nil
	if not PS_RateLimit(ply, 'buy') then return end
	ply:PS_BuyItem(item_id, initial_mods)
end)

net.Receive('PS_SellItem', function(length, ply)
	local item_id = net.ReadString()
	if not PS_RateLimit(ply, 'sell') then return end
	ply:PS_SellItem(item_id)
end)

net.Receive('PS_EquipItem', function(length, ply)
	local item_id = net.ReadString()
	if not PS_RateLimit(ply, 'equip') then return end
	ply:PS_EquipItem(item_id)
end)

net.Receive('PS_HolsterItem', function(length, ply)
	local item_id = net.ReadString()
	if not PS_RateLimit(ply, 'holster') then return end
	ply:PS_HolsterItem(item_id)
end)

-- Reject oversized modify payloads before deserializing. A legit modify is a small
-- text+color/offset table; anything large is an attempt to make net.ReadTable do
-- expensive work on attacker-controlled data. ~2 KB is generous for real items.
local PS_MAX_MODIFY_BITS = 16384
net.Receive('PS_ModifyItem', function(length, ply)
	local item_id = net.ReadString()
	local mods = net.ReadTable()
	if not PS_RateLimit(ply, 'modify') then return end
	if length > PS_MAX_MODIFY_BITS then return end
	ply:PS_ModifyItem(item_id, mods)
end)

-- player to player

net.Receive('PS_SendPoints', function(length, ply)
	local other = net.ReadEntity()
	local points = math.Clamp(net.ReadInt(32), 0, 1000000)
	
	if not PS.Config.CanPlayersGivePoints then return end
	if not points or points == 0 then return end
	if not other or not IsValid(other) or not other:IsPlayer() then return end
	if not ply or not IsValid(ply) or not ply:IsPlayer() then return end
	if not ply:PS_HasPoints(points) then
		ply:PS_Notify("You can't afford to give away ", points, " of your ", PS.Config.PointsName, ".")
		return
	end

	ply.PS_LastGavePoints = ply.PS_LastGavePoints or 0
	if ply.PS_LastGavePoints + 5 > CurTime() then
		ply:PS_Notify("Slow down! You can't give away points that fast.")
		return
	end

	ply:PS_TakePoints(points)
	ply:PS_Notify("You gave ", other:Nick(), " ", points, " of your ", PS.Config.PointsName, ".")
		
	other:PS_GivePoints(points)
	other:PS_Notify(ply:Nick(), " gave you ", points, " of their ", PS.Config.PointsName, ".")

	ply.PS_LastGavePoints = CurTime()
end)

-- admin points

net.Receive('PS_GivePoints', function(length, ply)
	local other = net.ReadEntity()
	local points = math.Clamp(net.ReadInt(32), 0, 1000000)
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and points and IsValid(other) and other:IsPlayer() then
		other:PS_GivePoints(points)
		other:PS_Notify(ply:Nick(), ' gave you ', points, ' ', PS.Config.PointsName, '.')
	end
end)

net.Receive('PS_TakePoints', function(length, ply)
	local other = net.ReadEntity()
	local points = math.Clamp(net.ReadInt(32), 0, 1000000)
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and points and IsValid(other) and other:IsPlayer() then
		other:PS_TakePoints(points)
		other:PS_Notify(ply:Nick(), ' took ', points, ' ', PS.Config.PointsName, ' from you.')
	end
end)

net.Receive('PS_SetPoints', function(length, ply)
	local other = net.ReadEntity()
	local points = math.Clamp(net.ReadInt(32), 0, 1000000)
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and points and IsValid(other) and other:IsPlayer() then
		other:PS_SetPoints(points)
		other:PS_Notify(ply:Nick(), ' set your ', PS.Config.PointsName, ' to ', points, '.')
	end
end)

-- admin items

net.Receive('PS_GiveItem', function(length, ply)
	local other = net.ReadEntity()
	local item_id = net.ReadString()
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and item_id and PS.Items[item_id] and IsValid(other) and other:IsPlayer() and not other:PS_HasItem(item_id) then
		other:PS_GiveItem(item_id)
	end
end)

net.Receive('PS_TakeItem', function(length, ply)
	local other = net.ReadEntity()
	local item_id = net.ReadString()
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and item_id and PS.Items[item_id] and IsValid(other) and other:IsPlayer() and other:PS_HasItem(item_id) then
		-- holster it first without notificaiton
		other.PS_Items[item_id].Equipped = false
	
		local ITEM = PS.Items[item_id]
		ITEM:OnHolster(other)
		other:PS_TakeItem(item_id)
	end
end)

-- hooks

-- Ability to use any button to open pointshop.
hook.Add("PlayerButtonDown", "PS_ToggleKey", function(ply, btn)
	if PS.Config.ShopKey and PS.Config.ShopKey ~= "" then
		local psButton = _G["KEY_" .. string.upper(PS.Config.ShopKey)]
		if psButton and psButton == btn then
			ply:PS_ToggleMenu()
		end
	end
end)

hook.Add('PlayerSpawn', 'PS_PlayerSpawn', function(ply) ply:PS_PlayerSpawn() end)
hook.Add('PlayerDeath', 'PS_PlayerDeath', function(ply) ply:PS_PlayerDeath() end)
hook.Add('PlayerInitialSpawn', 'PS_PlayerInitialSpawn', function(ply) ply:PS_PlayerInitialSpawn() end)
hook.Add('PlayerDisconnected', 'PS_PlayerDisconnected', function(ply) ply:PS_PlayerDisconnected() end)

hook.Add('PlayerSay', 'PS_PlayerSay', function(ply, text)
	if string.len(PS.Config.ShopChatCommand) > 0 then
		if string.sub(text, 0, string.len(PS.Config.ShopChatCommand)) == PS.Config.ShopChatCommand then
			ply:PS_ToggleMenu()
			return ''
		end
	end
end)

-- ugly networked strings

util.AddNetworkString('PS_Items')
util.AddNetworkString('PS_ItemDelta')
util.AddNetworkString('PS_DeltaSelfTest')
util.AddNetworkString('PS_Points')
util.AddNetworkString('PS_BuyItem')
util.AddNetworkString('PS_SellItem')
util.AddNetworkString('PS_EquipItem')
util.AddNetworkString('PS_HolsterItem')
util.AddNetworkString('PS_ModifyItem')
util.AddNetworkString('PS_SendPoints')
util.AddNetworkString('PS_GivePoints')
util.AddNetworkString('PS_TakePoints')
util.AddNetworkString('PS_SetPoints')
util.AddNetworkString('PS_GiveItem')
util.AddNetworkString('PS_TakeItem')
util.AddNetworkString('PS_AddClientsideModel')
util.AddNetworkString('PS_RemoveClientsideModel')
util.AddNetworkString('PS_SendClientsideModels')
util.AddNetworkString('PS_SendNotification')
util.AddNetworkString('PS_ToggleMenu')
util.AddNetworkString('PS_AdminRequestItems')
util.AddNetworkString('PS_AdminItemsResponse')

-- Admin request: fetch another player's items (not synced to other clients by default)
net.Receive('PS_AdminRequestItems', function(len, ply)
	if not (IsValid(ply) and ply:IsAdmin()) then return end
	local target = net.ReadEntity()
	if not IsValid(target) then return end
	net.Start('PS_AdminItemsResponse')
		net.WriteEntity(target)
		net.WriteTable(target.PS_Items or {})
	net.Send(ply)
end)

-- Delta protocol self-test. Writes every vector in PS_DeltaTestVectors over the real
-- net layer; the client reads them back and diffs against its own copy of the same
-- table (see the receiver in cl_init.lua). Catches read/write asymmetry — a field
-- written in one order and read in another, or at a mismatched bit width — which
-- otherwise corrupts the rest of the stream silently.
--
--   ps_delta_selftest          run against every player
--   ps_delta_selftest <name>   run against one player
--
-- Results print in the *client* console of whoever is tested.
concommand.Add('ps_delta_selftest', function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end

	local targets = {}
	if args and args[1] then
		local found = string.lower(args[1])
		for _, p in ipairs(player.GetAll()) do
			if string.find(string.lower(p:Nick()), found, 1, true) then table.insert(targets, p) end
		end
	else
		targets = player.GetAll()
	end

	if #targets == 0 then
		MsgN("[PS delta] No matching players.")
		return
	end

	for _, p in ipairs(targets) do
		for i, vec in ipairs(PS_DeltaTestVectors) do
			net.Start('PS_DeltaSelfTest')
				net.WriteUInt(i, 8)
				PS_WriteModifiers(vec.mods)
			net.Send(p)
		end
		MsgN(string.format("[PS delta] Sent %d test vectors to %s — results are in their client console.",
			#PS_DeltaTestVectors, p:Nick()))
	end
end)

-- console commands

concommand.Add(PS.Config.ShopCommand, function(ply, cmd, args)
	ply:PS_ToggleMenu()
end)

concommand.Add('ps_clear_points', function(ply, cmd, args)
	if IsValid(ply) then return end -- only allowed from server console

	for _, target in pairs(player.GetAll()) do
		target:PS_SetPoints(0)
	end

	-- Persisted data is cleared through the active data provider (pdata/mysql/json/...).
	if PS.DataProvider.ClearAllPoints then
		PS.DataProvider:ClearAllPoints()
	else
		MsgN("[PointShop] Data provider '" .. tostring(PS.DataProvider.ID) .. "' has no ClearAllPoints(); only online players were reset.")
	end
end)

concommand.Add('ps_clear_items', function(ply, cmd, args)
	if IsValid(ply) then return end -- only allowed from server console

	for _, target in pairs(player.GetAll()) do
		target.PS_Items = {}
		target:PS_SendItems()
	end

	-- Persisted data is cleared through the active data provider (pdata/mysql/json/...).
	if PS.DataProvider.ClearAllItems then
		PS.DataProvider:ClearAllItems()
	else
		MsgN("[PointShop] Data provider '" .. tostring(PS.DataProvider.ID) .. "' has no ClearAllItems(); only online players were reset.")
	end
end)

-- data providers

function PS:LoadDataProvider()
	local path = "pointshop/providers/" .. self.Config.DataProvider .. ".lua"
	if not file.Exists(path, "LUA") then
		error("Pointshop data provider not found. " .. path)
	end

	PROVIDER = {}
	PROVIDER.__index = {}
	PROVIDER.ID = self.Config.DataProvider
		
	include(path)
		
	self.DataProvider = PROVIDER
	PROVIDER = nil
end

function PS:GetPlayerData(ply, callback)
	self.DataProvider:GetData(ply, function(points, items)
		callback(PS:ValidatePoints(tonumber(points)), PS:ValidateItems(items))
	end)
end

function PS:SetPlayerData(ply, points, items)
	self.DataProvider:SetData(ply, points, items)
end

function PS:SetPlayerPoints(ply, points)
	self.DataProvider:SetPoints(ply, points)
end

function PS:GivePlayerPoints(ply, points)
	self.DataProvider:GivePoints(ply, points)
end

function PS:TakePlayerPoints(ply, points)
	self.DataProvider:TakePoints(ply, points)
end

function PS:SavePlayerItem(ply, item_id, data)
	self.DataProvider:SaveItem(ply, item_id, data)
end

function PS:GivePlayerItem(ply, item_id, data)
	self.DataProvider:GiveItem(ply, item_id, data)
end

function PS:TakePlayerItem(ply, item_id)
	self.DataProvider:TakeItem(ply, item_id)
end