--[[
	pointshop/sh_theme_sync.lua

	Canonical serialisation and hashing for the theme, shared by both realms.

	WHY THIS EXISTS

	The server holds one file of canonical sizes and colours. Clients need it, but almost
	always already have exactly it -- so sending the whole thing to everyone on every join is
	paying for a transfer that changes nothing.

	Instead the server sends a hash. A client whose cached copy hashes the same is already
	correct and asks for nothing; a client that differs -- because the owner changed something,
	or because the cache is truncated or corrupt -- asks for the real payload and gets it.

	WHY CANONICAL

	util.TableToJSON walks the table with pairs(), which has no defined order. The same palette
	serialises to a different string on each run, so hashing its output directly would produce
	a different hash every time and the check would miss on every join -- resending constantly
	AND burning a hash on top, which is worse than never having tried.

	So the tables are written out with their keys sorted, by one function that both realms
	call. Two implementations of "canonical" that disagree by a space would be the same bug
	with a much longer trail.
]]--

PS = PS or {}
PS.ThemeSync = PS.ThemeSync or {}

local S = PS.ThemeSync

-- The sections a theme file is made of, in a fixed order.
--
-- Named here rather than discovered, because the order they are written in is part of what
-- makes the output canonical -- and because a section this does not know about should not
-- silently change the hash.
S.SECTIONS = { "colours", "metrics" }

-- ============================================================================
-- CANONICAL FORM
-- ============================================================================

local function SortedKeys(tbl)
	local keys = {}
	for k in pairs(tbl) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	return keys
end

-- Numbers, written so the same value always produces the same characters.
--
-- %.14g rather than tostring(): tostring on a float is locale- and build-sensitive, and an
-- integer that arrives as 1.0 from JSON must not hash differently from the 1 that was written.
local function Num(v)
	if v == math.floor(v) and math.abs(v) < 1e15 then
		return string.format("%d", v)
	end
	return string.format("%.14g", v)
end

-- Serialises a value deterministically. Not JSON, and deliberately not: this is only ever
-- hashed, never parsed back, so it can be the simplest thing that is stable.
local function Write(out, v)
	if istable(v) then
		out[#out + 1] = "{"
		for _, k in ipairs(SortedKeys(v)) do
			out[#out + 1] = k
			out[#out + 1] = "="

			-- Indexed by the sorted STRING key, so a table with numeric keys resolves the
			-- same way whether it came from Lua or round-tripped through JSON, which turns
			-- integer keys into strings.
			Write(out, v[k] ~= nil and v[k] or v[tonumber(k)])
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	elseif isnumber(v) then
		out[#out + 1] = Num(v)
	elseif isbool(v) then
		out[#out + 1] = v and "true" or "false"
	else
		out[#out + 1] = tostring(v)
	end
end

function S.Canonical(tbl)
	if not istable(tbl) then return "" end

	local out = {}
	for _, section in ipairs(S.SECTIONS) do
		out[#out + 1] = section
		out[#out + 1] = ":"
		Write(out, tbl[section] or {})
		out[#out + 1] = "\n"
	end

	return table.concat(out)
end

-- ============================================================================
-- HASH
-- ============================================================================

-- SHA256 rather than CRC. This decides whether a client keeps using what it has, so a
-- collision is a client silently running the wrong theme forever -- and the cost is one hash
-- of a few kilobytes, once, on join.
function S.Hash(tbl)
	return util.SHA256(S.Canonical(tbl))
end

-- ============================================================================
-- SECTION WRITES
-- ============================================================================

-- Replaces ONE section of a stored table and leaves the rest alone.
--
-- The rule for both files. Sizes and colours live together, and saving one must not disturb
-- the other -- which is not hypothetical: writing a whole file on every save is how saving a
-- window size deleted a palette that had taken an evening to choose.
function S.MergeSection(stored, section, data)
	stored = istable(stored) and stored or {}
	if not istable(data) then return stored end

	stored[section] = data
	return stored
end
