function PROVIDER:GetData(ply, callback)
	if not file.IsDir('pointshop', 'DATA') then
		file.CreateDir('pointshop')
	end
	
	local points, items
	
	local filename = string.Replace(ply:SteamID(), ':', '_')
	
	if not file.Exists('pointshop/' .. filename .. '.txt', 'DATA') then
		file.Write('pointshop/' .. filename .. '.txt', util.TableToJSON({
			Points = 0,
			Items = {}
		}))
		
		points = 0
		items = {}
	else
		local data = util.JSONToTable(file.Read('pointshop/' .. filename .. '.txt', 'DATA'))
		
		points = data.Points or 0
		items = data.Items or {}
	end
	
	return callback(points, items)
end

function PROVIDER:SetPoints( ply, set_points )
	self:GetData(ply, function(points, items)
		self:SetData(ply, set_points, items)
	end)
end

function PROVIDER:GivePoints( ply, add_points )
	self:GetData(ply, function(points, items)
		self:SetData(ply, points + add_points, items)
	end)
end

function PROVIDER:TakePoints( ply, points )
	self:GivePoints(ply, -points)
end

function PROVIDER:SaveItem( ply, item_id, data)
	self:GiveItem(ply, item_id, data)
end

-- Both operate on `items` as read back from disk, NOT on ply.PS_Items. Using the
-- in-memory table meant that if it wasn't populated yet — an equip landing before the
-- load callback returns — the save wrote an inventory containing only that one item and
-- destroyed the rest.
function PROVIDER:GiveItem( ply, item_id, data)
	self:GetData(ply, function(points, items)
		items = items or {}
		items[item_id] = data
		self:SetData(ply, points, items)
	end)
end

function PROVIDER:TakeItem( ply, item_id )
	self:GetData(ply, function(points, items)
		items = items or {}
		items[item_id] = nil
		self:SetData(ply, points, items)
	end)
end

function PROVIDER:SetData(ply, points, items)
	if not file.IsDir('pointshop', 'DATA') then
		file.CreateDir('pointshop')
	end
	
	local filename = string.Replace(ply:SteamID(), ':', '_')
	
	file.Write('pointshop/' .. filename .. '.txt', util.TableToJSON({
		Points = points,
		Items = items
	}))
end