--[[
	pointshop/sv_init.lua
	first file included serverside.
]]--

include "sh_init.lua"
include "sv_player_extension.lua"
include "sv_manifest.lua"

-- Owner-settable default UI palette.
--
-- Uses PS_IsItemDefaultOwner, which is defined in ps_item_defaults.lua — loaded from
-- lua/autorun/server/, so AFTER this file. That is fine because the only call is inside a
-- net handler and Lua resolves the global at call time, but it is why the gate there is
-- written defensively rather than assuming the function exists.
include "sv_theme.lua"

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

-- Payload ceilings, checked BEFORE any net.Read* call.
--
-- net.ReadTable is the expensive part — it walks attacker-controlled data and allocates
-- as it goes. A size check placed after it has already paid the cost it was meant to
-- avoid, which is exactly what these handlers used to do. `length` is available on entry,
-- so the guard belongs first.
--
-- A legit modify is a small text/colour/offset table; anything larger is an attempt to
-- make the server do work. 2 KB is generous for real items.
local PS_MAX_MODIFY_BITS = 16384   -- ~2 KB
local PS_MAX_BUY_BITS    = 16384   -- buy carries optional try-before-you-buy mods
local PS_MAX_PLAIN_BITS  = 2048    -- handlers that only carry an item id string

net.Receive('PS_BuyItem', function(length, ply)
	if length > PS_MAX_BUY_BITS then return end
	if not PS_RateLimit(ply, 'buy') then return end
	local item_id = net.ReadString()
	local initial_mods = net.ReadBool() and net.ReadTable() or nil
	ply:PS_BuyItem(item_id, initial_mods)
end)

net.Receive('PS_SellItem', function(length, ply)
	if length > PS_MAX_PLAIN_BITS then return end
	if not PS_RateLimit(ply, 'sell') then return end
	ply:PS_SellItem(net.ReadString())
end)

net.Receive('PS_EquipItem', function(length, ply)
	if length > PS_MAX_PLAIN_BITS then return end
	if not PS_RateLimit(ply, 'equip') then return end
	ply:PS_EquipItem(net.ReadString())
end)

net.Receive('PS_HolsterItem', function(length, ply)
	if length > PS_MAX_PLAIN_BITS then return end
	if not PS_RateLimit(ply, 'holster') then return end
	ply:PS_HolsterItem(net.ReadString())
end)

net.Receive('PS_ModifyItem', function(length, ply)
	if length > PS_MAX_MODIFY_BITS then return end
	if not PS_RateLimit(ply, 'modify') then return end
	local item_id = net.ReadString()
	local mods = net.ReadTable()
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

	if not (admin_allowed or super_admin_allowed) then return end
	if not item_id or item_id == '' then return end
	if not IsValid(other) or not other:IsPlayer() then return end
	if not other:PS_HasItem(item_id) then return end

	-- PS.Items[item_id] used to be part of this condition, which meant an item whose Lua
	-- file had been deleted could not be taken back at all: the player still owned the
	-- row, but every admin path to remove it was gated on a definition that no longer
	-- existed. The ownership check above is the one that matters for authority; the
	-- lookup below is only needed for the holster callback.
	local ITEM = PS.Items[item_id]

	-- holster it first without notificaiton
	if other.PS_Items[item_id] then
		other.PS_Items[item_id].Equipped = false
	end

	if ITEM then
		ITEM:OnHolster(other)
	end

	other:PS_TakeItem(item_id)
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
util.AddNetworkString('PS_AdminRequestSummary')
util.AddNetworkString('PS_AdminSummaryResponse')

-- Shared gate for every admin-tab net handler. Mirrors the client-side check that
-- decides whether the tab is drawn at all — the client one is cosmetic, this one is
-- the actual authority.
local function PS_AdminTabAllowed(ply)
	if not IsValid(ply) then return false end
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return false end
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	return (admin_allowed or super_allowed) == true
end

-- Admin request: fetch another player's items (not synced to other clients by default)
net.Receive('PS_AdminRequestItems', function(len, ply)
	if not PS_AdminTabAllowed(ply) then return end

	-- Rate limited: the response serialises a player's entire inventory.
	ply._PS_LastAdminReq = ply._PS_LastAdminReq or 0
	if CurTime() - ply._PS_LastAdminReq < 0.5 then return end
	ply._PS_LastAdminReq = CurTime()

	local target = net.ReadEntity()
	if not IsValid(target) then return end
	net.Start('PS_AdminItemsResponse')
		net.WriteEntity(target)
		net.WriteTable(target.PS_Items or {})
	net.Send(ply)
end)

-- Admin request: points and item counts for every player, for the admin list columns.
--
-- Those columns called ply:PS_GetPoints() / ply:PS_GetItems() directly, but PS_SendPoints
-- and PS_SendItems both net.Send(self) — a player's points and inventory are only ever
-- networked to that player. So the columns read PS_Points on a remote player entity,
-- which is never set, and rendered 0 for everyone but the admin themselves.
--
-- Sent as a flat list rather than per-player messages: one round trip for the whole
-- list, and counts instead of inventories keeps it small (2 bytes + 4 bytes per player).
net.Receive('PS_AdminRequestSummary', function(len, ply)
	if not PS_AdminTabAllowed(ply) then return end

	ply._PS_LastAdminSummary = ply._PS_LastAdminSummary or 0
	if CurTime() - ply._PS_LastAdminSummary < 0.5 then return end
	ply._PS_LastAdminSummary = CurTime()

	local plys = player.GetAll()
	net.Start('PS_AdminSummaryResponse')
		net.WriteUInt(#plys, 8)
		for _, p in ipairs(plys) do
			net.WriteUInt(p:EntIndex(), 13)
			net.WriteUInt(math.Clamp(p.PS_Points or 0, 0, 16777215), 24)
			net.WriteUInt(math.Clamp(table.Count(p.PS_Items or {}), 0, 4095), 12)
		end
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
	-- Run from the server console, ply is NULL — there's no menu to toggle.
	if not IsValid(ply) then return end
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