--[[
	pointshop/sh_gamemodes.lua
	Gamemode profiles: the one place the shop is allowed to know what game it is in.

	THE PROBLEM

	The shop had no gamemode awareness at all. It loaded every category folder it found and
	trusted each one's AllowedTeams, which are raw team numbers written into shop content.
	On the gamemode those numbers were written for they are correct; on any other gamemode
	they mean something else, or nothing. A category gated to team 2 follows the shop onto a
	server where team 2 is a different idea entirely, and gates itself to that instead.

	That is the same coupling that came out of the theme, the widget layer, the appearance
	menu and the model resolver: those all went through hooks so the shop never names a
	gamemode. Category data was the last place it still did.

	THE DISTINCTION THE SHOP WAS MISSING

	Team gating quietly assumes a team you CHOOSE AND KEEP. Bear Hunt is that: you pick
	victims, you stay a victim, the bear pool is drawn before the round. A team like that is
	a thing you can own items for.

	TTT, Murder and Hide and Seek are the other kind. Your role is ASSIGNED AND CHURNS -
	traitor at round start, murderer on the draw, seeker the moment somebody touches you.
	Nothing you own can be gated on a role you did not pick and might lose mid-round,
	because gating it means the shop strips and swaps your model at the instant the role
	changes. In Hide and Seek that would make getting caught visibly transform you, which is
	precisely the thing that gamemode is built not to do.

	So a profile describes the SHAPE of a gamemode, not just a list of categories. Hide and
	Seek is the first case of that distinction, not the reason for it.

	THE RULES

	  - A MISSING PROFILE CHANGES NOTHING. Every category loads and its own AllowedTeams
	    applies, exactly as before this file existed. The addon still works on a gamemode
	    nobody has written a profile for, which is the point of it being an addon.
	  - teamGating = false makes PS:CanEquipForTeam return true unconditionally. One flag,
	    one reader, and it is already the only place AllowedTeams is consulted for this.
	  - categories[name] = false skips that folder entirely at load. The items never
	    register, so they cannot be bought, equipped, or re-applied on spawn - which is
	    stronger than hiding them, and is what you want for content that belongs to a
	    different game.
	  - categories[name] = { teams = {...} } overrides that category's AllowedTeams, for a
	    gamemode that gates but disagrees with the shipped value.

	Profiles are data files in pointshop/gamemodes/<gamemode>.lua returning a table. The
	shop's own content stays generic; the profile is the single place a gamemode's
	specifics live. Same principle as AllowedTeams being category data rather than code,
	one level up.
]]--

PS.Gamemode = PS.Gamemode or {}

-- The loaded profile, or nil when this gamemode has none. Read through the accessors
-- below rather than directly, so "no profile" has one meaning in one place.
PS.GamemodeProfile = nil

function PS:LoadGamemodeProfile()
	local name = engine.ActiveGamemode()
	if not name or name == "" then return end

	local path = "pointshop/gamemodes/" .. name .. ".lua"
	if not file.Exists(path, "LUA") then
		if self.Config and self.Config.Debug then
			print("[PS] No gamemode profile for '" .. name .. "' - categories load with their own gates.")
		end
		return
	end

	-- AddCSLuaFile before the include so the client gets the same file. A profile that
	-- existed only on the server would leave the two realms disagreeing about which
	-- categories are registered, and the client builds the shop UI off its own list.
	if SERVER then AddCSLuaFile(path) end

	local ok, profile = pcall(include, path)
	if not ok or type(profile) ~= "table" then
		ErrorNoHalt("[PS] Gamemode profile '" .. name .. "' failed to load: " ..
			tostring(profile) .. "\n")
		return
	end

	self.GamemodeProfile = profile

	if self.Config and self.Config.Debug then
		print("[PS] Gamemode profile loaded: " .. name ..
			" (teamGating=" .. tostring(profile.teamGating ~= false) .. ")")
	end
end

-- Does this gamemode gate items by team at all?
--
-- Defaults to TRUE for both a missing profile and a profile that does not mention it, so
-- the flag can only ever loosen behaviour from what the shop did before, never tighten it.
-- Gating is what every existing category file was written expecting.
function PS:UsesTeamGating()
	local p = self.GamemodeProfile
	if not p then return true end
	return p.teamGating ~= false
end

-- Should this category folder be loaded at all?
--
-- Only an explicit `false` skips it. A category the profile does not mention loads, so a
-- profile lists what it wants to change and nothing else - adding a new category folder to
-- the shop does not mean editing every profile to permit it.
function PS:IsCategoryEnabled(folder)
	local p = self.GamemodeProfile
	if not p or not p.categories then return true end
	return p.categories[folder] ~= false
end

-- The team list this category should gate on, or nil for "whatever the category says".
function PS:CategoryTeamOverride(folder)
	local p = self.GamemodeProfile
	if not p or not p.categories then return nil end

	local entry = p.categories[folder]
	if type(entry) == "table" and entry.teams then return entry.teams end
	return nil
end
