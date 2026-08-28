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

-- Name -> category index, built lazily and invalidated whenever PS.Categories changes size.
--
-- FindCategoryByName was a linear scan over every category, and two of its call sites sit
-- inside `for id, item in pairs(self.PS_Items)` loops in PS_EquipItem — making each equip
-- O(items_owned × categories). A player owning 300 items on a 20-category shop paid ~6,000
-- string comparisons per equip, and equipping runs once per equipped item on every spawn.
--
-- Rebuilt on a count mismatch rather than at load: categories are registered during
-- LoadItems, and this is shared code called from both realms, so there is no single point
-- after registration that is guaranteed to have run on both.
local categoryByName = nil
local categoryByNameCount = -1

function PS:FindCategoryByName(cat_name)
	if not cat_name then return false end

	local count = table.Count(self.Categories)
	if categoryByName == nil or count ~= categoryByNameCount then
		categoryByName = {}
		categoryByNameCount = count
		for _, cat in pairs(self.Categories) do
			if cat.Name then categoryByName[cat.Name] = cat end
		end
	end

	-- Still returns `false` rather than nil on a miss. Existing guards test the value
	-- itself before indexing it, and `false` is what they were written against.
	return categoryByName[cat_name] or false
end

-- Single source of truth for the per-category team restriction (e.g. bear models
-- vs victim models). Returns true when the player's current team may wear the item.
-- No AllowedTeams on the category = no restriction = allowed.
--
-- One reader, which is why the gamemode profile can turn the whole idea off with a single
-- flag: everywhere in the shop that asks "may this player wear this" comes through here.
function PS:CanEquipForTeam(ply, ITEM)
	if not IsValid(ply) or not ITEM then return false end

	-- Gamemodes where the role is assigned and churns mid-round do not gate at all. See
	-- sh_gamemodes.lua for why that is a property of the gamemode rather than of the item.
	if not self:UsesTeamGating() then return true end

	local CATEGORY = PS:FindCategoryByName(ITEM.Category)
	if not CATEGORY or not CATEGORY.AllowedTeams or #CATEGORY.AllowedTeams == 0 then
		return true
	end

	for _, tid in ipairs(CATEGORY.AllowedTeams) do
		if ply:Team() == tid then return true end
	end

	return false
end

-- ============================================================================
-- COLOUR APPLICATION
-- ============================================================================
--
-- There are two colour channels and they are mutually exclusive:
--
--   modulation   ent:SetColor(col)         works on every model
--   proxy        ply:SetPlayerColor(vec)   players; needs $color2 in the material
--                mdl:SetColor2(vec)        clientside models; same requirement
--
-- Whichever channel carries the colour, the other MUST be reset to neutral. Leaving it
-- alone lets the previously equipped model's colour bleed through the channel nobody
-- cleared, and on a wrong branch it is worse than that: the write lands in a channel the
-- model does not render while the one it was using gets wiped.
--
-- That rule is the entire reason these functions exist. It used to be reimplemented at
-- roughly 28 sites across 6 files, and every one had to remember to clear the channel it
-- was not using. Forgetting once is not a missing tint, it is a wiped one — which is what
-- made the failures so hard to read.
--
-- Players and accessories keep SEPARATE entry points on purpose. They share this rule,
-- not their API:
--
--   * the proxy channel is SetPlayerColor on a player and SetColor2 on a model
--   * a player's colour is a persistent property of the player; an accessory's belongs to
--     that one model and dies with it
--   * the player path is shared realm (equipping runs on the server), while clientside
--     models only exist on the client
--
-- Collapsing them into one "it's all a model" helper is precisely how a playermodel's
-- colour ends up on a hat.
--
-- PS:ApplyColorToPlayer  -- here, shared realm
-- PS:ApplyColorToModel   -- cl_player_extension.lua, client only

local COLOR_NEUTRAL  = Color(255, 255, 255, 255)
local VECTOR_NEUTRAL = Vector(1, 1, 1)

-- Normalises the three shapes a colour actually arrives in, because all three genuinely
-- reach this from different directions:
--
--   Color{r,g,b}        0-255, from panels and the accessory storage key
--   {[1],[2],[3]}       0-255, the array shape `playercolor` is stored as in SQL
--   Vector(x,y,z)       0-1 normalised, what item files write (playercolor = Vector(1,1,1))
--
-- The Vector case has to be tested first: a Vector answers to .x, and an unlucky read of
-- .r on one would come back nil and silently default the channel to 255.
-- Exposed as PS:ReadColorRGB below, because callers that store or network a colour need
-- the same normalisation and should not each re-derive it.
local function ReadRGB(color)
	if not color then return 255, 255, 255 end

	if type(color) == "Vector" or color.x ~= nil then
		return math.Clamp(math.floor((tonumber(color.x) or 1) * 255), 0, 255),
		       math.Clamp(math.floor((tonumber(color.y) or 1) * 255), 0, 255),
		       math.Clamp(math.floor((tonumber(color.z) or 1) * 255), 0, 255)
	end

	return math.Clamp(tonumber(color.r or color[1]) or 255, 0, 255),
	       math.Clamp(tonumber(color.g or color[2]) or 255, 0, 255),
	       math.Clamp(tonumber(color.b or color[3]) or 255, 0, 255)
end

function PS:ReadColorRGB(color)
	return ReadRGB(color)
end

-- Is this item the thing the player's body BECOMES, as opposed to something worn on it?
--
-- Four places asked "no Attachment and no Bone?" and one of them wrote "must be a playermodel?"
-- with a question mark, which was the honest version. A powerup answers yes to that question:
-- it carries a Model as its shop icon and hangs off no bone, because it is not worn at all. A
-- loadout holding one took the powerup's icon -- a glass bottle -- as the player's body, and a
-- bottle has no attachment points, so every accessory in the loadout had nowhere to go and the
-- player colour was applied to a bottle.
--
-- TYPE is believed when an item declares one. The rest is the old guess, minus the two cases
-- it got wrong: a weapon is not a body, and neither is something flagged NoPreview.
function PS.IsPlayermodelItem(ITEM)
	if not istable(ITEM) or not ITEM.Model then return false end
	if ITEM.TYPE then return ITEM.TYPE == "playermodel" end

	return not (ITEM.Attachment or ITEM.Bone or ITEM.WeaponClass or ITEM.NoPreview)
end

function PS:ApplyColorToPlayer(ply, color, useColor2)
	if not IsValid(ply) or not ply.SetColor then return end

	local r, g, b = ReadRGB(color)

	if useColor2 then
		ply:SetColor(COLOR_NEUTRAL)
		ply:SetPlayerColor(Vector(r / 255, g / 255, b / 255))
	else
		ply:SetColor(Color(r, g, b, 255))
		ply:SetPlayerColor(VECTOR_NEUTRAL)
	end

	ply:SetRenderMode(RENDERMODE_NORMAL)

	if PS.Config and PS.Config.Debug then
		print(string.format("[PS COLOR] player=%s R=%d G=%d B=%d useColor2=%s",
			ply:Nick(), r, g, b, tostring(useColor2 and true or false)))
	end
end

-- Initialization

function PS:Initialize()
	if SERVER then self:LoadDataProvider() end

	-- Before LoadItems, not after: the profile decides which category folders are loaded
	-- at all, and a category skipped here never registers its items rather than
	-- registering them and hiding them afterwards.
	self:LoadGamemodeProfile()

	self:LoadItems()
end

-- Loading

function PS:LoadItems()	
	local _, dirs = file.Find('pointshop/items/*', 'LUA')
	local emptyfunc = function() end

	for _, category in pairs(dirs) do
		-- The gamemode profile can disable a whole folder. Skipped here rather than filtered
		-- out of the UI later, so the items never enter PS.Items: an item that does not
		-- exist cannot be bought, cannot be equipped, and cannot be re-applied on spawn from
		-- a save made on another gamemode.
		if not PS:IsCategoryEnabled(category) then
			if SERVER and PS.Config and PS.Config.Debug then
				print("[PS] Category '" .. category .. "' disabled by gamemode profile.")
			end
			continue
		end

		local f, _ = file.Find('pointshop/items/' .. category .. '/__category.lua', 'LUA')
		
		if #f > 0 then
			CATEGORY = {}
			
			CATEGORY.Name = ''
			CATEGORY.Icon = ''
			CATEGORY.Order = 0
			CATEGORY.AllowedEquipped = -1
			CATEGORY.AllowedUserGroups = {}
			-- Whether this category is SHOWN, which is separate from whether its items can be
			-- equipped (PS:CanEquipForTeam) and has to agree with it.
			--
			-- It did not. Three category files each carried their own copy of this team check,
			-- none of which knew about the gamemode profile -- so a gamemode with teamGating off
			-- could equip an item from a category the menu refused to show it in. On Hide and
			-- Seek that meant a seeker could not see the hider categories, even though the whole
			-- point of that profile is that both roles wear the same things.
			--
			-- One default here, profile-aware, and the category files no longer define it. A
			-- category with a genuinely different rule can still override it below.
			CATEGORY.CanPlayerSee = function(self, ply)
				if not PS:UsesTeamGating() then return true end
				if not self.AllowedTeams or #self.AllowedTeams == 0 then return true end

				for _, tid in ipairs(self.AllowedTeams) do
					if IsValid(ply) and ply:Team() == tid then return true end
				end
				return false
			end
			CATEGORY.ModifyTab = emptyfunc
			
			if SERVER then AddCSLuaFile('pointshop/items/' .. category .. '/__category.lua') end
			include('pointshop/items/' .. category .. '/__category.lua')
			
			-- A profile may disagree with the shipped AllowedTeams for a category it still
			-- wants loaded. Applied here, after the category file has had its say and
			-- before anything reads it, so CanEquipForTeam sees one value.
			local teamOverride = PS:CategoryTeamOverride(category)
			if teamOverride then CATEGORY.AllowedTeams = teamOverride end

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
					-- '%.lua$' not '.lua': in a Lua pattern '.' matches ANY character and
					-- gsub is global, so 'valuable.lua' became 'vble' and 'bluaitem.lua'
					-- became 'item'. IDs are the database key, so a mangled one silently
					-- orphans that item's saved data.
					ITEM.ID = string.gsub(string.lower(name), '%.lua$', '')
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
					
					-- Colour path. Pinned here rather than inferred at each call site.
					--
					-- The two paths clear each other: ApplyModelSettings sets one and
					-- explicitly resets the other, to stop a previously equipped model's
					-- colour bleeding through. That means "undeclared" is not a neutral
					-- state — whichever branch ends up running wipes the other channel.
					--
					-- Defaults to render modulation (SetColor). $color2 proxy support is
					-- inconsistent across addon models while modulation works on all of
					-- them, so it is the path that degrades gracefully on an unknown
					-- model. The colour defaults to neutral white, which under modulation
					-- means untinted — the model's own appearance, not a colour nobody
					-- picked.
					--
					-- Deliberately not behind PS.Config.Debug. A missing flag is a content
					-- error in an item file, and the person running the server is the one
					-- who has to go fix it.
					if ITEM.UseColor2Proxy == nil then
						ITEM.UseColor2Proxy = false

						-- The neutral colour is only seeded for the types that key off
						-- `color` — accessories and trails. Playermodels key off
						-- `playercolor`, and seeding that is exactly the destructive case
						-- PS_GetCustomization's fallback was fixed for: a player's colour
						-- exists independently of the item, so inventing one repaints them.
						-- For a playermodel the flag alone is the fix; the colour is left
						-- to whatever they already have.
						if ITEM.TYPE ~= "playermodel" then
							ITEM.DefaultModifications = ITEM.DefaultModifications or {}
							if ITEM.DefaultModifications.color == nil then
								ITEM.DefaultModifications.color = Color(255, 255, 255, 255)
							end
						end

						MsgC(Color(255, 120, 40), string.format(
							"[POINTSHOP] %s does not set UseColor2Proxy - defaulting to SetColor modulation with a neutral colour. Set it explicitly (true or false) in %s\n",
							ITEM.ID, ITEM.__luaFile))
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
						-- Keyed on ID, not Name: IDs are unique (they're the filename), display
					-- names are not. Two items sharing a name silently overwrote each
					-- other's hooks, so only the last one loaded actually ran.
					hook.Add(prop, 'PS_Item_' .. item.ID .. '_' .. prop, function(...)
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
