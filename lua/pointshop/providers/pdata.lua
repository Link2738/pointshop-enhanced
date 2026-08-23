function PROVIDER:GetData(ply, callback)
	return callback(tonumber(ply:GetPData('PS_Points', 0)) or 0, util.JSONToTable(ply:GetPData('PS_Items', '{}')))
end

function PROVIDER:SetPoints(ply, set_points)
	ply:SetPData('PS_Points', math.max(0, tonumber(set_points) or 0))
end

function PROVIDER:GivePoints(ply, add_points)
	local current = tonumber(ply:GetPData('PS_Points', 0)) or 0
	ply:SetPData('PS_Points', math.max(0, current + add_points))
end

function PROVIDER:TakePoints(ply, points)
	self:GivePoints(ply, -points)
end

function PROVIDER:SaveItem(ply, item_id, data)
	self:GiveItem(ply, item_id, data)
end

-- Read-modify-write against PData, NOT against ply.PS_Items.
--
-- This used to do table.Copy(ply.PS_Items) and write the whole thing. If the in-memory
-- table wasn't populated yet — an equip landing before PS_LoadData's callback returns —
-- that wrote an inventory containing only the item being saved, destroying everything
-- else the player owned. Reading the stored copy and changing one key can't do that,
-- and matches what TakeItem already did.
function PROVIDER:GiveItem(ply, item_id, data)
	local tmp = util.JSONToTable(ply:GetPData('PS_Items', '{}')) or {}
	tmp[item_id] = data
	ply:SetPData('PS_Items', util.TableToJSON(tmp))
end

function PROVIDER:TakeItem(ply, item_id)
	local tmp = util.JSONToTable(ply:GetPData('PS_Items', '{}')) or {}
	tmp[item_id] = nil
	ply:SetPData('PS_Items', util.TableToJSON(tmp))
end

function PROVIDER:SetData(ply, points, items)
	-- Clamped the same way SetPoints does; this path used to write the raw value, so a
	-- negative could reach storage through one entry point but not the other.
	ply:SetPData('PS_Points', math.max(0, tonumber(points) or 0))
	ply:SetPData('PS_Items', util.TableToJSON(items or {}))
end

-- Bulk wipes used by the ps_clear_points / ps_clear_items server console commands.
-- pdata keys are stored as '<steamid64>[KeyName]', so these have to match the bracketed
-- suffix rather than a bare substring. The old '%PS_Points%' form would also match any
-- other addon's key that merely contained the text — 'MyAddon_PS_PointsBackup' and the
-- like — so a bulk wipe could delete data PointShop doesn't own. Anchoring to the
-- trailing '[PS_Points]' keeps it to keys this provider actually wrote.
function PROVIDER:ClearAllPoints()
	sql.Query("DELETE FROM playerpdata WHERE infoid LIKE '%[PS_Points]'")
end

function PROVIDER:ClearAllItems()
	sql.Query("DELETE FROM playerpdata WHERE infoid LIKE '%[PS_Items]'")
end