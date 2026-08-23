--[[
	pointshop/sh_init.lua
	first file included on both states.
]]--

PS = {}
PS.__index = PS

PS.Items = {}
PS.Categories = {}
PS.ClientsideModels = {}

include("sh_config.lua")
include("sh_player_extension.lua")
include("sh_item_delta.lua")   -- PS_WriteModifiers / PS_ReadModifiers, used by the item delta protocol

-- ============================================================================
-- DEBUG LOG DUMP
--
-- PointShop's ~59 debug sites are scattered `if PS.Config.Debug then print(...) end`
-- blocks with no single chokepoint, so rather than touching every one of them, PS.Print
-- wraps the global print for the duration of a debug session and tees anything starting
-- with "[PS" to disk. Existing call sites keep working untouched and land in the dump.
--
-- Writes go to data/bear_debug/ alongside the gamemode's, so a session is one folder.
-- Buffered and flushed on a timer; file.Append per line would hammer the disk.
-- ============================================================================

PS.LogDir      = "bear_debug"
PS.LogMaxBytes = 8 * 1024 * 1024

local psLogBuffer, psLogLines = {}, 0

function PS:LogFileName()
	local realm = SERVER and "sv" or "cl"
	return string.format("%s/%s_pointshop_%s.txt", self.LogDir, realm, os.date("%Y-%m-%d"))
end

function PS:LogFlush()
	if psLogLines == 0 then return end

	local chunk = table.concat(psLogBuffer)
	psLogBuffer, psLogLines = {}, 0

	if not file.IsDir(self.LogDir, "DATA") then file.CreateDir(self.LogDir) end

	local path = self:LogFileName()
	local existing = file.Size(path, "DATA")
	if existing and existing > self.LogMaxBytes then
		file.Write(path .. ".old", file.Read(path, "DATA") or "")
		file.Write(path, "")
	end

	file.Append(path, chunk)
end

function PS:LogWrite(line)
	psLogBuffer[#psLogBuffer + 1] = os.date("[%H:%M:%S] ") .. line .. "\n"
	psLogLines = psLogLines + 1
	if psLogLines >= 200 then self:LogFlush() end
end

-- Tee any "[PS..." print to the dump. Installed once, and only active while
-- PS.Config.Debug is on, so it costs a string compare per print otherwise.
if not PS._PrintHooked then
	PS._PrintHooked = true
	local realPrint = print

	-- Tracks whether the previous captured line was ours, so indented continuation lines
	-- get picked up too. Several debug blocks print a "[PS ...]" header and then follow
	-- it with print("  Skin:", ...) style detail lines — matching only on the "[PS"
	-- prefix silently dropped all of that, leaving headers with nothing under them.
	local lastWasOurs = false

	print = function(...)
		realPrint(...)

		if not (PS.Config and PS.Config.Debug) then return end

		local n = select("#", ...)
		if n == 0 then lastWasOurs = false return end

		local first = select(1, ...)
		if type(first) ~= "string" then lastWasOurs = false return end

		local isHeader       = string.sub(first, 1, 3) == "[PS"
		local isContinuation = lastWasOurs and string.match(first, "^%s") ~= nil

		if not (isHeader or isContinuation) then
			lastWasOurs = false
			return
		end
		lastWasOurs = true

		local parts = {}
		for i = 1, n do parts[i] = tostring(select(i, ...)) end
		PS:LogWrite(table.concat(parts, "\t"))
	end
end

timer.Create("PS_LogFlush", 2, 0, function() if PS and PS.LogFlush then PS:LogFlush() end end)
hook.Add("ShutDown", "PS_LogFlushShutdown", function() if PS and PS.LogFlush then PS:LogFlush() end end)

concommand.Add("ps_debug_path", function()
	PS:LogFlush()
	local path = PS:LogFileName()
	local size = file.Size(path, "DATA") or 0
	MsgC(Color(100, 180, 255), "[PS] ", color_white,
		string.format("debug dump: garrysmod/data/%s  (%.1f KB)\n", path, size / 1024))
end)

-- ============================================================================
-- LEGACY MODS NORMALIZER
--
-- Customization data used to be stored as offsetX/offsetY/offsetZ plus an
-- axis + axisDeg pair (and a scalar `rotation` yaw). It's now offset = {x,y,z} and
-- ang = {pitch,yaw,roll}, and the readers only understand the new shape.
--
-- This upgrades a mods table in place. It runs on every read path rather than as a
-- one-shot database pass, because this addon is distributed — other servers have their
-- own SQL rows, their own item_defaults.json, and their own hand-written item files,
-- none of which a migration here could reach.
--
-- Returns the table plus a boolean saying whether anything changed, so callers can
-- write the upgraded row back and avoid redoing the work on every read.
-- ============================================================================

local LEGACY_AXIS_INDEX = { Right = 1, Up = 2, Forward = 3 }

function PS_NormalizeMods(mods)
	if type(mods) ~= "table" then return mods, false end

	local changed = false

	-- offsetX/Y/Z -> offset. An existing `offset` always wins; the legacy keys are
	-- dropped either way so they can't linger and confuse the next reader.
	if mods.offsetX ~= nil or mods.offsetY ~= nil or mods.offsetZ ~= nil then
		if not mods.offset then
			mods.offset = {
				tonumber(mods.offsetX) or 0,
				tonumber(mods.offsetY) or 0,
				tonumber(mods.offsetZ) or 0,
			}
		end
		mods.offsetX, mods.offsetY, mods.offsetZ = nil, nil, nil
		changed = true
	end

	-- axis + axisDeg -> ang. The old pair expressed a single-axis tilt; map it onto the
	-- matching component of the pitch/yaw/roll triple.
	if mods.axis ~= nil or mods.axisDeg ~= nil then
		if not mods.ang then
			local ang = { 0, 0, 0 }
			ang[LEGACY_AXIS_INDEX[tostring(mods.axis)] or 1] = tonumber(mods.axisDeg) or 0
			mods.ang = ang
		end
		mods.axis, mods.axisDeg = nil, nil
		changed = true
	end

	-- Scalar `rotation` was a yaw applied around the bone's up axis before `ang` existed.
	-- Fold a non-zero value into ang's yaw rather than discarding it outright.
	if mods.rotation ~= nil then
		local rot = tonumber(mods.rotation) or 0
		if rot ~= 0 then
			mods.ang = mods.ang or { 0, 0, 0 }
			mods.ang[2] = (tonumber(mods.ang[2]) or 0) + rot
		end
		mods.rotation = nil
		changed = true
	end

	return mods, changed
end

-- validation

function PS:ValidateItems(items)
	if type(items) ~= 'table' then return {} end

	for item_id, item in pairs(items) do
		-- Remove any items that no longer exist
		if not self.Items[item_id] then
			items[item_id] = nil
		elseif type(item) == 'table' and type(item.Modifiers) == 'table' then
			-- Upgrade legacy modifier shapes on load. This covers the data provider
			-- (pdata/flatfile/mysql), which stores its own copy of Modifiers separately
			-- from the ps_customization table.
			PS_NormalizeMods(item.Modifiers)
		end
	end

	return items
end

function PS:ValidatePoints(points)
	if type(points) ~= 'number' then return 0 end
	
	return points >= 0 and points or 0
end

-- Resolve an item ID to its model path (used by accessory backends)
function PS_GetModelPathForItem(itemID)
	if PS and PS.Items and PS.Items[itemID] and PS.Items[itemID].Model then
		return PS.Items[itemID].Model
	end
	return nil
end

-- Utils

function PS:FindCategoryByName(cat_name)
	for id, cat in pairs(self.Categories) do
		if cat.Name == cat_name then
			return cat
		end
	end

	return false
end

-- Single source of truth for the per-category team restriction (e.g. bear models
-- vs victim models). Returns true when the player's current team may wear the item.
-- No AllowedTeams on the category = no restriction = allowed.
function PS:CanEquipForTeam(ply, ITEM)
	if not IsValid(ply) or not ITEM then return false end

	local CATEGORY = PS:FindCategoryByName(ITEM.Category)
	if not CATEGORY or not CATEGORY.AllowedTeams or #CATEGORY.AllowedTeams == 0 then
		return true
	end

	for _, tid in ipairs(CATEGORY.AllowedTeams) do
		if ply:Team() == tid then return true end
	end

	return false
end

-- Initialization

function PS:Initialize()
	if SERVER then self:LoadDataProvider() end

	self:LoadItems()
end

-- Loading

function PS:LoadItems()	
	local _, dirs = file.Find('pointshop/items/*', 'LUA')
	local emptyfunc = function() end

	for _, category in pairs(dirs) do
		local f, _ = file.Find('pointshop/items/' .. category .. '/__category.lua', 'LUA')
		
		if #f > 0 then
			CATEGORY = {}
			
			CATEGORY.Name = ''
			CATEGORY.Icon = ''
			CATEGORY.Order = 0
			CATEGORY.AllowedEquipped = -1
			CATEGORY.AllowedUserGroups = {}
			CATEGORY.CanPlayerSee = function() return true end
			CATEGORY.ModifyTab = emptyfunc
			
			if SERVER then AddCSLuaFile('pointshop/items/' .. category .. '/__category.lua') end
			include('pointshop/items/' .. category .. '/__category.lua')
			
			if not PS.Categories[category] then
				PS.Categories[category] = CATEGORY
			end
			
			local files, _ = file.Find('pointshop/items/' .. category .. '/*.lua', 'LUA')
			
			for _, name in pairs(files) do
				-- Skip the category definition and any _-prefixed files. The latter are
				-- templates/examples kept in the repo for documentation and never loaded.
				if name ~= '__category.lua' and string.sub(name, 1, 1) ~= '_' then
					if SERVER then AddCSLuaFile('pointshop/items/' .. category .. '/' .. name) end
					
					ITEM = {}
					
					ITEM.__index = ITEM
					ITEM.ID = string.gsub(string.lower(name), '.lua', '')
					ITEM.Category = CATEGORY.Name
					ITEM.Price = 0
					
					-- model and material are missing but there's no way around it, there's a check below anyway
					
					ITEM.AdminOnly = false
					ITEM.AllowedUserGroups = {} -- this will fail the #ITEM.AllowedUserGroups test and continue
					ITEM.SingleUse = false
					ITEM.NoPreview = false
					
					ITEM.CanPlayerBuy = true
					ITEM.CanPlayerSell = true
					
					ITEM.CanPlayerEquip = true
					ITEM.CanPlayerHolster = true

					ITEM.OnBuy = emptyfunc
					ITEM.OnSell = emptyfunc
					ITEM.OnEquip = emptyfunc
					ITEM.OnHolster = emptyfunc
					ITEM.OnModify = emptyfunc
					ITEM.ModifyClientsideModel = function(ITEM, ply, model, pos, ang)
						return model, pos, ang
					end
					
					ITEM.__luaFile = 'pointshop/items/' .. category .. '/' .. name

					include('pointshop/items/' .. category .. '/' .. name)

					if not ITEM.Name then
						ErrorNoHalt("[POINTSHOP] Item missing name: " .. category .. '/' .. name .. "\n")
						continue
					elseif not ITEM.Price then
						ErrorNoHalt("[POINTSHOP] Item missing price: " .. category .. '/' .. name .. "\n")
						continue
					elseif not ITEM.Model and not ITEM.Material then
						ErrorNoHalt("[POINTSHOP] Item missing model or material: " .. category .. '/' .. name .. "\n")
						continue
					end
					
					-- precache
					
					if ITEM.Model then
						util.PrecacheModel(ITEM.Model)
					end
					
					-- item hooks
					local item = ITEM
					
				-- Functions that are NOT engine hooks — skip registering these
				local non_hooks = {
					OnEquip = true, OnHolster = true, OnBuy = true, OnSell = true,
					OnModify = true, Modify = true, ModifyClientsideModel = true,
					SanitizeTable = true, CanPlayerBuy = true, CanPlayerSell = true,
					CanPlayerEquip = true, CanPlayerHolster = true,
					ApplyModelSettings = true, ApplyAccessorySettings = true,
				}
				
				for prop, val in pairs(item) do
					if type(val) == "function" and not non_hooks[prop] then
						hook.Add(prop, 'PS_Item_' .. item.Name .. '_' .. prop, function(...)
							for _, ply in pairs(player.GetAll()) do
								if ply:PS_HasItemEquipped(item.ID) then
									item[prop](item, ply, ply.PS_Items[item.ID].Modifiers, unpack({...}))
								end
							end
						end)
					end
				end
					
					self.Items[ITEM.ID] = ITEM
					
					ITEM = nil
				end
			end
			
			CATEGORY = nil
		end
	end
end
