--[[
	pointshop/sh_item_delta.lua
	Shared delta-sync protocol for PS_Items.
	Instead of sending the full inventory table (net.WriteTable) on every
	single-item change, we send a compact typed message describing ONLY
	the item that changed.

	Full syncs (PS_SendItems via net.WriteTable) are still used for:
	  - Initial join (PS_LoadData)
	  - Explicit client re-request (PS_RequestData)
	  - Admin console ps_clear_items

	Included from sh_init.lua on both server and client.
]]--

-- Operation constants (fits in 2 bits)
PS_DELTA_ADD    = 1   -- item given (PS_GiveItem)
PS_DELTA_REMOVE = 2   -- item taken (PS_TakeItem)
PS_DELTA_UPDATE = 3   -- equip / holster / modify (send current state)

-- ─────────────────────────────────────────────────────────────────────
-- Modifier bitmask flags (7-bit field)
-- ─────────────────────────────────────────────────────────────────────
local MOD_SCALE     = 1   -- number
local MOD_OFFSET    = 2   -- 3x float (offsetX/Y/Z or offset table)
local MOD_ROTATION  = 4   -- number
local MOD_AXIS      = 8   -- string enum: "Right" | "Up" | "Forward"
local MOD_AXISDEG   = 16  -- number
local MOD_COLOR     = 32  -- Color (r,g,b,a as 4 bytes)
local MOD_EXTRA     = 64  -- extended fields present (skin, bodygroups, playercolor, ang, text)

-- ─────────────────────────────────────────────────────────────────────
-- Extended fields sub-bitmask (5-bit, only read when MOD_EXTRA is set)
-- ─────────────────────────────────────────────────────────────────────
local EXT_SKIN         = 1
local EXT_BODYGROUPS   = 2
local EXT_PLAYERCOLOR  = 4
local EXT_ANG          = 8
local EXT_TEXT         = 16

-- ─────────────────────────────────────────────────────────────────────
-- Helper: normalize offset from legacy offsetX/Y/Z or Vector to {x,y,z}
-- ─────────────────────────────────────────────────────────────────────
local function NormalizeOffset(mods)
	if mods.offset then
		local o = mods.offset
		return tonumber(o[1] or o.x) or 0, tonumber(o[2] or o.y) or 0, tonumber(o[3] or o.z) or 0
	elseif mods.offsetX or mods.offsetY or mods.offsetZ then
		return tonumber(mods.offsetX) or 0, tonumber(mods.offsetY) or 0, tonumber(mods.offsetZ) or 0
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────────────
-- Helper: normalize color to {r,g,b,a}
-- ─────────────────────────────────────────────────────────────────────
local function NormalizeColor(c)
	if not c then return nil end
	local r = tonumber(c.r or c[1]) or 255
	local g = tonumber(c.g or c[2]) or 255
	local b = tonumber(c.b or c[3]) or 255
	local a = tonumber(c.a or c[4]) or 255
	return r, g, b, a
end

-- ─────────────────────────────────────────────────────────────────────
-- Helper: normalize angle from Angle or table to {p,y,r}
-- ─────────────────────────────────────────────────────────────────────
local function NormalizeAngle(ang)
	if not ang then return nil end
	local p = tonumber(ang[1] or ang.p or ang.pitch) or 0
	local y = tonumber(ang[2] or ang.y or ang.yaw)   or 0
	local r = tonumber(ang[3] or ang.r or ang.roll)  or 0
	return p, y, r
end

-- ═════════════════════════════════════════════════════════════════════
-- PS_WriteModifiers( modifiers_table )
-- Writes a modifier table with typed net writes + bitmask header.
-- Typical cost: 1–20 bytes instead of 200–800 via net.WriteTable.
-- ═════════════════════════════════════════════════════════════════════
function PS_WriteModifiers(mods)
	if not mods then mods = {} end

	-- Build primary flags
	local flags = 0
	if mods.scale                                         then flags = bit.bor(flags, MOD_SCALE) end
	if mods.offset or mods.offsetX or mods.offsetY or mods.offsetZ then flags = bit.bor(flags, MOD_OFFSET) end
	if mods.rotation                                      then flags = bit.bor(flags, MOD_ROTATION) end
	if mods.axis                                          then flags = bit.bor(flags, MOD_AXIS) end
	if mods.axisDeg                                       then flags = bit.bor(flags, MOD_AXISDEG) end
	if mods.color                                         then flags = bit.bor(flags, MOD_COLOR) end

	-- Build extended flags
	local extFlags = 0
	if mods.skin                                          then extFlags = bit.bor(extFlags, EXT_SKIN) end
	if mods.bodygroups and next(mods.bodygroups)          then extFlags = bit.bor(extFlags, EXT_BODYGROUPS) end
	if mods.playercolor                                   then extFlags = bit.bor(extFlags, EXT_PLAYERCOLOR) end
	if mods.ang                                           then extFlags = bit.bor(extFlags, EXT_ANG) end
	if mods.text                                          then extFlags = bit.bor(extFlags, EXT_TEXT) end
	if extFlags ~= 0 then flags = bit.bor(flags, MOD_EXTRA) end

	net.WriteUInt(flags, 7)

	-- Primary fields
	if bit.band(flags, MOD_SCALE) ~= 0 then
		net.WriteFloat(mods.scale)
	end

	if bit.band(flags, MOD_OFFSET) ~= 0 then
		local ox, oy, oz = NormalizeOffset(mods)
		net.WriteFloat(ox)
		net.WriteFloat(oy)
		net.WriteFloat(oz)
	end

	if bit.band(flags, MOD_ROTATION) ~= 0 then
		net.WriteFloat(mods.rotation)
	end

	if bit.band(flags, MOD_AXIS) ~= 0 then
		-- Encode axis enum as 2 bits: 0=Right, 1=Up, 2=Forward
		local axisMap = { Right = 0, Up = 1, Forward = 2 }
		net.WriteUInt(axisMap[mods.axis] or 0, 2)
	end

	if bit.band(flags, MOD_AXISDEG) ~= 0 then
		net.WriteFloat(mods.axisDeg)
	end

	if bit.band(flags, MOD_COLOR) ~= 0 then
		local r, g, b, a = NormalizeColor(mods.color)
		net.WriteUInt(r, 8)
		net.WriteUInt(g, 8)
		net.WriteUInt(b, 8)
		net.WriteUInt(a, 8)
	end

	-- Extended fields
	if bit.band(flags, MOD_EXTRA) ~= 0 then
		net.WriteUInt(extFlags, 5)

		if bit.band(extFlags, EXT_SKIN) ~= 0 then
			net.WriteUInt(mods.skin, 8)
		end

		if bit.band(extFlags, EXT_BODYGROUPS) ~= 0 then
			-- Count entries, write count + key/value pairs (both small ints)
			local count = 0
			for _ in pairs(mods.bodygroups) do count = count + 1 end
			net.WriteUInt(count, 5)  -- max 31 bodygroups
			for bgID, bgVal in pairs(mods.bodygroups) do
				net.WriteUInt(bgID, 5)   -- bodygroup index 0-31
				net.WriteUInt(bgVal, 4)  -- bodygroup value 0-15
			end
		end

		if bit.band(extFlags, EXT_PLAYERCOLOR) ~= 0 then
			-- Read as sequential table or Vector, write 3 floats
			local pc = mods.playercolor
			local r = tonumber(pc[1] or pc.r or pc.x) or 0
			local g = tonumber(pc[2] or pc.g or pc.y) or 0
			local b = tonumber(pc[3] or pc.b or pc.z) or 0
			net.WriteFloat(r)
			net.WriteFloat(g)
			net.WriteFloat(b)
		end

		if bit.band(extFlags, EXT_ANG) ~= 0 then
			local p, y, r = NormalizeAngle(mods.ang)
			net.WriteFloat(p)
			net.WriteFloat(y)
			net.WriteFloat(r)
		end

		if bit.band(extFlags, EXT_TEXT) ~= 0 then
			net.WriteString(mods.text)
		end
	end
end

-- ═════════════════════════════════════════════════════════════════════
-- PS_ReadModifiers()
-- Client-side counterpart: reads the typed modifier data.
-- Returns a clean table matching what PS_Items[id].Modifiers expects.
-- ═════════════════════════════════════════════════════════════════════
function PS_ReadModifiers()
	local mods = {}
	local flags = net.ReadUInt(7)

	if bit.band(flags, MOD_SCALE) ~= 0 then
		mods.scale = net.ReadFloat()
	end

	if bit.band(flags, MOD_OFFSET) ~= 0 then
		mods.offset = { net.ReadFloat(), net.ReadFloat(), net.ReadFloat() }
	end

	if bit.band(flags, MOD_ROTATION) ~= 0 then
		mods.rotation = net.ReadFloat()
	end

	if bit.band(flags, MOD_AXIS) ~= 0 then
		local axisLookup = { [0] = "Right", [1] = "Up", [2] = "Forward" }
		mods.axis = axisLookup[net.ReadUInt(2)] or "Right"
	end

	if bit.band(flags, MOD_AXISDEG) ~= 0 then
		mods.axisDeg = net.ReadFloat()
	end

	if bit.band(flags, MOD_COLOR) ~= 0 then
		mods.color = Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))
	end

	if bit.band(flags, MOD_EXTRA) ~= 0 then
		local extFlags = net.ReadUInt(5)

		if bit.band(extFlags, EXT_SKIN) ~= 0 then
			mods.skin = net.ReadUInt(8)
		end

		if bit.band(extFlags, EXT_BODYGROUPS) ~= 0 then
			mods.bodygroups = {}
			local count = net.ReadUInt(5)
			for i = 1, count do
				local bgID = net.ReadUInt(5)
				local bgVal = net.ReadUInt(4)
				mods.bodygroups[bgID] = bgVal
			end
		end

		if bit.band(extFlags, EXT_PLAYERCOLOR) ~= 0 then
			mods.playercolor = { net.ReadFloat(), net.ReadFloat(), net.ReadFloat() }
		end

		if bit.band(extFlags, EXT_ANG) ~= 0 then
			mods.ang = { net.ReadFloat(), net.ReadFloat(), net.ReadFloat() }
		end

		if bit.band(extFlags, EXT_TEXT) ~= 0 then
			mods.text = net.ReadString()
		end
	end

	return mods
end
