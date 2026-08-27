CATEGORY.Name = 'VIP Victim Models'
CATEGORY.Icon = 'star'
CATEGORY.Order = 12
CATEGORY.AllowedTeams = { 1 }  -- TEAM_VICTIMS

-- CanPlayerSee is not defined here any more.
--
-- It was an exact copy of the same team check in three category files, and none of them
-- knew about the gamemode profile -- so a gamemode that turns team gating off could equip
-- an item from a category the menu still refused to show. The shared default in
-- sh_init.lua does this now and honours the profile.
