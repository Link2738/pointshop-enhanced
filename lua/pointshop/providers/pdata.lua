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

function PROVIDER:GiveItem(ply, item_id, data)
	local tmp = table.Copy(ply.PS_Items)
	tmp[item_id] = data
	ply:SetPData('PS_Items', util.TableToJSON(tmp))
end

function PROVIDER:TakeItem(ply, item_id)
	local tmp = util.JSONToTable(ply:GetPData('PS_Items', '{}'))
	tmp[item_id] = nil
	ply:SetPData('PS_Items', util.TableToJSON(tmp))
end

function PROVIDER:SetData(ply, points, items)
	ply:SetPData('PS_Points', points)
	ply:SetPData('PS_Items', util.TableToJSON(items))
end

-- Bulk wipes used by the ps_clear_points / ps_clear_items server console commands.
function PROVIDER:ClearAllPoints()
	sql.Query("DELETE FROM playerpdata WHERE infoid LIKE '%PS_Points%'")
end

function PROVIDER:ClearAllItems()
	sql.Query("DELETE FROM playerpdata WHERE infoid LIKE '%PS_Items%'")
end