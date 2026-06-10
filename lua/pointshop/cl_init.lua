--[[
	pointshop/cl_init.lua
	first file included clientside.
]]--

-- [PS DEBUG] Intercept SetColor calls on player entities to find who calls SetColor after broadcast
-- Remove this block once the culprit is found
if PS and PS.Config and PS.Config.Debug then
    local playerMeta = FindMetaTable("Player")
    local originalSetColor = playerMeta.SetColor
    playerMeta.SetColor = function(self, ...)
        -- Log if color is not white (not a reset)
        local c = (...)
        if c and (c.r ~= 255 or c.g ~= 255 or c.b ~= 255) then
            print(string.format("[PS SETCOLOR INTERCEPT] Player %s SetColor(%d,%d,%d) called from:", 
                IsValid(self) and self:Nick() or "?", c.r or 0, c.g or 0, c.b or 0))
            print(debug.traceback("", 2))
        end
        return originalSetColor(self, ...)
    end
end

include "sh_init.lua"
include "cl_player_extension.lua"

include "vgui/DPointShopMenu.lua"
include "vgui/DPointShopItem.lua"
include "vgui/DPointShopInspector.lua"
include "vgui/DPointShopPreview.lua"

include "vgui/DPointShopGivePoints.lua"
include "vgui/DPointShopAdmin.lua"

PS.ShopMenu = nil
PS.ClientsideModels = {}

PS.HoverModel = nil
PS.HoverModelClientsideModel = nil

local invalidplayeritems = {}

-- menu stuff

function PS:ToggleMenu(forceOpen)
	if not PS.ShopMenu then
		PS.ShopMenu = vgui.Create('DPointShopMenu')
		PS.ShopMenu:SetVisible(false)
	end
	
	if forceOpen then
		PS.ShopMenu:Show()
		gui.EnableScreenClicker(true)
		-- Request fresh data from server
		net.Start('PS_RequestData')
		net.SendToServer()
	elseif PS.ShopMenu:IsVisible() then
		PS.ShopMenu:Hide()
		gui.EnableScreenClicker(false)
	else
		PS.ShopMenu:Show()
		gui.EnableScreenClicker(true)
		-- Request fresh data from server
		net.Start('PS_RequestData')
		net.SendToServer()
	end
end

function PS:SetHoverItem(item_id)
	local ITEM = PS.Items[item_id]
	
	if ITEM.Model then
		self.HoverModel = item_id
	
		self.HoverModelClientsideModel = ClientsideModel(ITEM.Model, RENDERGROUP_OPAQUE)
		self.HoverModelClientsideModel:SetNoDraw(true)
	end
end

function PS:RemoveHoverItem()
	self.HoverModel = nil
	if IsValid(self.HoverModelClientsideModel) then
		self.HoverModelClientsideModel:Remove()
	end
	self.HoverModelClientsideModel = nil
end

-- modification stuff

function PS:ShowColorChooser(item, modifications)
	-- TODO: Do this
	local chooser = vgui.Create('DPointShopColorChooser')
	chooser:SetColor(modifications.color)
	
	chooser.OnChoose = function(color)
		modifications.color = color
		self:SendModifications(item.ID, modifications)
	end
end

function PS:SendModifications(item_id, modifications)
	net.Start('PS_ModifyItem')
		net.WriteString(item_id)
		net.WriteTable(modifications)
	net.SendToServer()
end

-- net hooks

net.Receive('PS_ToggleMenu', function(length)
	PS:ToggleMenu()
end)

net.Receive('PS_Items', function(length)
	local ply = net.ReadEntity()
	local items = net.ReadTable()
	ply.PS_Items = PS:ValidateItems(items)
	
	-- Mark that we've received initial data (for loading state detection)
	if ply == LocalPlayer() then
		ply.PS_InitialDataReceived = true
	end
end)

net.Receive('PS_Points', function(length)
	local ply = net.ReadEntity()
	local points = net.ReadInt(32)
	ply.PS_Points = PS:ValidatePoints(points)
	
	-- Mark that we've received initial data (for loading state detection)
	if ply == LocalPlayer() then
		ply.PS_InitialDataReceived = true
		
		-- Refresh menu if open (points display updates)
		if PS.ShopMenu and PS.ShopMenu:IsVisible() and PS.ShopMenu.Header then
			PS.ShopMenu.Header:InvalidateLayout(true)
		end
	end
end)

net.Receive('PS_AddClientsideModel', function(length)
	local ply = net.ReadEntity()
	local item_id = net.ReadString()

	-- Debug: log receipt of add-clientside-model net message and stacktrace
	if PS and PS.Config and PS.Config.Debug then
		pcall(function()
			local name = (IsValid(ply) and ply:Nick()) or tostring(ply)
			print(string.format("[PS DEBUG CLIENT] net.Receive 'PS_AddClientsideModel' for ply=%s item_id=%s", tostring(name), tostring(item_id)))
			print(debug.traceback())
		end)
	end
	
	if not IsValid(ply) then
		if not invalidplayeritems[ply] then
			invalidplayeritems[ply] = {}
		end
		
		table.insert(invalidplayeritems[ply], item_id)
		return
	end
	-- guard: skip if playerside table already has a valid model for this id (handle string/number)
	local skip = false
	if PS and PS.ClientsideModels and PS.ClientsideModels[ply] then
		if PS.ClientsideModels[ply][item_id] and IsValid(PS.ClientsideModels[ply][item_id]) then skip = true end
		local nid = tonumber(item_id)
		if not skip and nid and PS.ClientsideModels[ply][nid] and IsValid(PS.ClientsideModels[ply][nid]) then skip = true end
		if not skip then
			-- try matching by model path
			local ITEM = PS and PS.Items and PS.Items[item_id]
			if ITEM then
				for k, v in pairs(PS.ClientsideModels[ply]) do
					if IsValid(v) and v.GetModel and v:GetModel() == ITEM.Model then
						skip = true
						break
					end
				end
			end
		end
	end
	if not skip then
		ply:PS_AddClientsideModel(item_id)
	else
		-- debug
		print("[PS] net: skipping PS_AddClientsideModel for", tostring(ply), item_id)
	end
end)

net.Receive('PS_RemoveClientsideModel', function(length)
	local ply = net.ReadEntity()
	local item_id = net.ReadString()
	
	if not ply or not IsValid(ply) or not ply:IsPlayer() then return end
	
	ply:PS_RemoveClientsideModel(item_id)
end)

net.Receive('PS_SendClientsideModels', function(length)
	local itms = net.ReadTable()
	
	for key, items in pairs(itms) do
		-- Server sends EntIndex keys (numbers) for reliable serialization
		local ply = isnumber(key) and Entity(key) or key
		if not IsValid(ply) then -- skip if the player isn't valid yet and add them to the table to sort out later
			invalidplayeritems[ply or key] = items
			continue
		end
		
		-- Skip LocalPlayer - they manage their own models through direct OnEquip/OnHolster calls
		if ply == LocalPlayer() then continue end
		
		for _, item_id in pairs(items) do
			if not PS.Items[item_id] then continue end
			local skip = false
			if PS and PS.ClientsideModels and PS.ClientsideModels[ply] then
				if PS.ClientsideModels[ply][item_id] and IsValid(PS.ClientsideModels[ply][item_id]) then skip = true end
				local nid = tonumber(item_id)
				if not skip and nid and PS.ClientsideModels[ply][nid] and IsValid(PS.ClientsideModels[ply][nid]) then skip = true end
				if not skip then
					local ITEM = PS.Items[item_id]
					for k, v in pairs(PS.ClientsideModels[ply]) do
						if IsValid(v) and v.GetModel and v:GetModel() == ITEM.Model then
							skip = true
							break
						end
					end
				end
			end
			if not skip then
				ply:PS_AddClientsideModel(item_id)
			end
		end
	end
end)

net.Receive('PS_SendNotification', function(length)
	local str = net.ReadString()
	notification.AddLegacy(str, NOTIFY_GENERIC, 5)
end)

-- hooks

hook.Add('Think', 'PS_Think', function()
	for ply, items in pairs(invalidplayeritems) do
		if IsValid(ply) then
			-- Skip LocalPlayer - they manage their own models
			if ply ~= LocalPlayer() then
				for _, item_id in pairs(items) do
					if PS.Items[item_id] then
						ply:PS_AddClientsideModel(item_id)
					end
				end
			end
			
			invalidplayeritems[ply] = nil
		end
	end
end)

hook.Add('PostPlayerDraw', 'PS_PostPlayerDraw', function(ply)
	local t1 = SysTime()
	if not ply:Alive() then return end
	-- Removed problematic GetConVar('thirdperson') check to prevent engine spam
	-- If you need to check for third person, use a custom convar or hook instead
    
    -- Player model color is already set server-side and networked automatically
    -- We only need to draw clientside accessory models here
    
    if not PS.ClientsideModels[ply] then return end
    for item_id, model in pairs(PS.ClientsideModels[ply]) do
        if not PS.Items[item_id] then PS.ClientsideModels[ply][item_id] = nil continue end
        local ITEM = PS.Items[item_id]
        if not ITEM.Attachment and not ITEM.Bone then PS.ClientsideModels[ply][item_id] = nil continue end
        local pos = Vector()
        local ang = Angle()
        if ITEM.Attachment then
            local attach_id = ply:LookupAttachment(ITEM.Attachment)
            if not attach_id then continue end
            local attach = ply:GetAttachment(attach_id)
            if not attach then continue end
            pos = attach.Pos
            ang = attach.Ang
        else
            local bone_id = ply:LookupBone(ITEM.Bone)
            if not bone_id then continue end
            pos, ang = ply:GetBonePosition(bone_id)
        end
        model, pos, ang = ITEM:ModifyClientsideModel(ply, model, pos, ang)
        model:SetPos(pos)
        model:SetAngles(ang)
        model:SetRenderOrigin(pos)
        model:SetRenderAngles(ang)
        model:SetupBones()
        
        -- Apply color modulation before drawing
        -- Skip render.SetColorModulation if model uses Color2Proxy (color already set via SetColor2)
        if not ITEM.UseColor2Proxy then
            local modelColor = model:GetColor() or Color(255, 255, 255, 255)
            render.SetColorModulation(modelColor.r / 255, modelColor.g / 255, modelColor.b / 255)
            if modelColor.a < 255 then
                render.SetBlend(modelColor.a / 255)
            end
        end
        
        model:DrawModel()
        
        -- Reset render state (only if we set it)
        if not ITEM.UseColor2Proxy then
            render.SetColorModulation(1, 1, 1)
            render.SetBlend(1)
        end
        
        model:SetRenderOrigin()
        model:SetRenderAngles()
    end
    local t2 = SysTime()
    local dt = (t2 - t1) * 1000 -- ms
    if PS and PS.Config and PS.Config.Debug and dt > 2 then
        print(string.format('[Pointshop] PostPlayerDraw for %s took %.2f ms', tostring(ply), dt))
    end
end)
