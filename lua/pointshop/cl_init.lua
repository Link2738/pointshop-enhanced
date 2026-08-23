--[[
	pointshop/cl_init.lua
	first file included clientside.
]]--

-- REMOVED: a SetColor interceptor that monkey-patched Player.SetColor globally to trace
-- who was recolouring players after a broadcast.
--
-- It never ran. The guard was `if PS and PS.Config and PS.Config.Debug`, but this sits
-- above `include "sh_init.lua"` — which is what creates PS — so PS was always nil here
-- and the block was dead from the day it was written.
--
-- Worth knowing before reinstating it: the patch was unconditional and permanent once
-- applied, replacing the method for every addon on the client for the rest of the
-- session. If that trace is needed again, hook it behind a console command so it can be
-- turned off, and place it after the include.

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

-- Points/items that arrived before their player entity was networked. Keyed by
-- EntIndex; drained in PS_Think once the entity resolves. See the PS_Items receiver.
local pendingPlayerData = {}

-- menu stuff

-- One resync per session, on the first menu open.
--
-- This started life as a workaround for the join race: the initial PS_Items send could
-- arrive before the player entity was networked, get assigned to NULL and vanish, and
-- re-requesting on menu open quietly papered over it. That race is now handled properly
-- in the PS_Items/PS_Points receivers (queued by EntIndex, drained in PS_Think), so the
-- re-request is no longer load-bearing.
--
-- It's kept for the first open only, as a safety net for a player who joins mid-session
-- with anything still in flight. Firing it on *every* open cost a full 6936-byte
-- inventory sync each time, which is the one thing the delta protocol was meant to stop.
local hasResyncedThisSession = false

local function RequestDataOnce()
	if hasResyncedThisSession then return end
	hasResyncedThisSession = true

	net.Start('PS_RequestData')
	net.SendToServer()

	if PS and PS.Config and PS.Config.Debug then
		print("[PS DELTA] -> requesting one-time session resync (first menu open)")
	end
end

function PS:ToggleMenu(forceOpen)
	if not PS.ShopMenu then
		PS.ShopMenu = vgui.Create('DPointShopMenu')
		PS.ShopMenu:SetVisible(false)
	end

	if forceOpen then
		PS.ShopMenu:Show()
		gui.EnableScreenClicker(true)
		RequestDataOnce()
	elseif PS.ShopMenu:IsVisible() then
		PS.ShopMenu:Hide()
		gui.EnableScreenClicker(false)
	else
		PS.ShopMenu:Show()
		gui.EnableScreenClicker(true)
		RequestDataOnce()
	end
end

function PS:SetHoverItem(item_id)
	local ITEM = PS.Items[item_id]
	if not ITEM then return end

	-- Always tear down the previous hover model first. This used to overwrite the
	-- reference without removing the entity, so scrolling through the shop leaked one
	-- ClientsideModel per item hovered.
	self:RemoveHoverItem()

	if ITEM.Model then
		self.HoverModel = item_id

		local mdl = ClientsideModel(ITEM.Model, RENDERGROUP_OPAQUE)
		-- ClientsideModel returns NULL when the model isn't on the client (missing
		-- FastDL content), and :SetNoDraw on that throws.
		if not IsValid(mdl) then
			self.HoverModel = nil
			return
		end

		mdl:SetNoDraw(true)
		self.HoverModelClientsideModel = mdl
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
	local ply      = net.ReadEntity()
	local plyIndex = net.ReadUInt(13)
	local items    = net.ReadTable()

	if not IsValid(ply) then
		-- Entity not networked yet. Queue rather than assigning to NULL, which silently
		-- discards the whole inventory — the join sync lands right on the InitPostEntity
		-- boundary and loses this race in practice.
		pendingPlayerData[plyIndex] = pendingPlayerData[plyIndex] or {}
		pendingPlayerData[plyIndex].items = items
		pendingPlayerData[plyIndex].expires = CurTime() + 30
		return
	end

	ply.PS_Items = PS:ValidateItems(items)

	-- Mark that we've received initial data (for loading state detection)
	if ply == LocalPlayer() then
		ply.PS_InitialDataReceived = true
	end

	if PS and PS.Config and PS.Config.Debug then
		-- Logged in the same format as the delta receiver so the two can be compared
		-- directly. This one should only appear on join, an explicit re-request, or
		-- ps_clear_items — if it shows up on equip/holster/modify, something is still
		-- calling PS_SendItems where it should be calling PS_SendItemDelta.
		print(string.format("[PS DELTA] <- %s  FULL SYNC  %d items  %d bits (%.0f bytes)",
			IsValid(ply) and ply:Nick() or "?", table.Count(ply.PS_Items or {}),
			length, math.ceil(length / 8)))
	end
end)

-- Delta protocol self-test receiver. Reads a vector the server wrote and diffs it
-- against this client's own copy of the same table. Triggered by ps_delta_selftest on
-- the server; see the sender there for what it's proving.
net.Receive('PS_DeltaSelfTest', function(length)
	local idx  = net.ReadUInt(8)
	local mods = PS_ReadModifiers()

	local vec = PS_DeltaTestVectors and PS_DeltaTestVectors[idx]
	if not vec then
		MsgC(Color(255, 80, 80), string.format("[PS delta] vector %d has no local counterpart — ", idx),
			color_white, "server and client are running different sh_item_delta.lua\n")
		return
	end

	local ok, err = PS_DeltaCompare(vec.mods, mods)
	if ok then
		MsgC(Color(120, 220, 120), "  PASS  ", color_white, vec.name .. "\n")
	else
		MsgC(Color(255, 80, 80), "  FAIL  ", color_white, vec.name .. "\n")
		MsgC(Color(255, 180, 180), "        " .. tostring(err) .. "\n")
	end
end)

-- Single-item delta. Applies one change to the local inventory instead of receiving a
-- full re-serialised copy of it. See Player:PS_SendItemDelta for why.
net.Receive('PS_ItemDelta', function(length)
	local ply     = net.ReadEntity()
	local op      = net.ReadUInt(2)
	local item_id = net.ReadString()

	if op == PS_DELTA_REMOVE then
		-- Nothing further on the wire for a removal.
		if IsValid(ply) and ply.PS_Items then
			ply.PS_Items[item_id] = nil
		end
		return
	end

	-- These reads must happen whether or not the entity resolved, otherwise the next
	-- message in the same batch starts reading from the wrong offset.
	local equipped = net.ReadBool()
	local mods     = PS_ReadModifiers()

	if not IsValid(ply) then return end

	-- Match PS:ValidateItems, which the full sync runs through: don't store items this
	-- client has no registration for, or they'd linger in the local table as entries
	-- that can never resolve to an ITEM.
	if not (PS.Items and PS.Items[item_id]) then return end

	ply.PS_Items = ply.PS_Items or {}
	ply.PS_Items[item_id] = { Equipped = equipped, Modifiers = mods }

	if ply == LocalPlayer() then
		ply.PS_InitialDataReceived = true
	end

	if PS and PS.Config and PS.Config.Debug then
		-- `length` is the message size in bits, so this reports the real cost rather
		-- than an estimate. Compare against a PS_Items full sync in the same session:
		-- the whole point of this protocol is that number staying flat as an inventory
		-- grows, instead of scaling with it.
		print(string.format("[PS DELTA] <- %s  id=%s equipped=%s  %d bits (%.0f bytes)",
			ply:Nick(), tostring(item_id), tostring(equipped), length, math.ceil(length / 8)))
	end
end)

net.Receive('PS_Points', function(length)
	local ply      = net.ReadEntity()
	local plyIndex = net.ReadUInt(13)
	local points   = net.ReadInt(32)

	if not IsValid(ply) then
		-- Same join race as PS_Items above.
		pendingPlayerData[plyIndex] = pendingPlayerData[plyIndex] or {}
		pendingPlayerData[plyIndex].points = points
		pendingPlayerData[plyIndex].expires = CurTime() + 30
		return
	end

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
	local plyIndex = net.ReadUInt(13)
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
		-- Queue by EntIndex, not by the entity. An un-networked player reads back as
		-- NULL, which is a single shared userdata — keying by it collapsed every pending
		-- player onto one entry that IsValid() could never clear, so the table grew
		-- forever and the queued items were never applied.
		local q = invalidplayeritems[plyIndex]
		if not q then
			q = { items = {}, expires = CurTime() + 30 }
			invalidplayeritems[plyIndex] = q
		end
		q.items[#q.items + 1] = item_id
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
			-- `key` is already the EntIndex here (the server writes it that way in
			-- PS_SendClientsideModels). The old `ply or key` resolved to NULL for an
			-- invalid index, so every pending player overwrote the previous one.
			local q = invalidplayeritems[key]
			if not q then
				q = { items = {}, expires = CurTime() + 30 }
				invalidplayeritems[key] = q
			end
			for _, id in pairs(items) do q.items[#q.items + 1] = id end
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

-- Client-side teardown when a player leaves.
--
-- Nothing used to clean any of this up. PS.ClientsideModels, PS_AccessoryCustomizations
-- and invalidplayeritems are all keyed by player, and every disconnect orphaned one
-- ClientsideModel entity per equipped accessory — permanently, since the entities were
-- never :Remove()d. GMod has a hard clientside entity cap; once it's reached new models
-- silently stop rendering for everyone, with no error and no obvious cause.
--
-- EntityRemoved fires clientside for players on disconnect, which is what we want:
-- the server's PS_PlayerDisconnected clears its own copy but never tells clients.
hook.Add('EntityRemoved', 'PS_CleanupClientsideModels', function(ent)
	if not ent:IsPlayer() then return end

	if PS.ClientsideModels and PS.ClientsideModels[ent] then
		for _, mdl in pairs(PS.ClientsideModels[ent]) do
			if IsValid(mdl) then mdl:Remove() end
		end
		PS.ClientsideModels[ent] = nil
	end

	if PS_AccessoryCustomizations then
		PS_AccessoryCustomizations[ent] = nil
	end

	-- invalidplayeritems is keyed by EntIndex, so clear that player's pending queue too.
	local idx = ent:EntIndex()
	if idx then invalidplayeritems[idx] = nil end
end)

hook.Add('Think', 'PS_Think', function()
	local now = CurTime()

	-- Apply points/items that beat their player entity onto the client.
	for idx, data in pairs(pendingPlayerData) do
		local ply = Entity(idx)
		if IsValid(ply) and ply:IsPlayer() then
			if data.items then
				ply.PS_Items = PS:ValidateItems(data.items)
			end
			if data.points then
				ply.PS_Points = PS:ValidatePoints(data.points)
			end
			if ply == LocalPlayer() then
				ply.PS_InitialDataReceived = true
			end

			if PS and PS.Config and PS.Config.Debug then
				print(string.format("[PS DELTA] <- %s  deferred join data applied (%d items, points=%s)",
					ply:Nick(), table.Count(ply.PS_Items or {}), tostring(data.points)))
			end

			pendingPlayerData[idx] = nil
		elseif data.expires and now > data.expires then
			pendingPlayerData[idx] = nil
		end
	end

	for idx, q in pairs(invalidplayeritems) do
		local ply = Entity(idx)
		if IsValid(ply) and ply:IsPlayer() then
			-- Skip LocalPlayer - they manage their own models
			if ply ~= LocalPlayer() then
				for _, item_id in pairs(q.items) do
					if PS.Items[item_id] then
						ply:PS_AddClientsideModel(item_id)
					end
				end
			end
			invalidplayeritems[idx] = nil
		elseif now > q.expires then
			-- The player never became valid (disconnected before networking finished, or
			-- the index was reused). Drop it rather than holding it forever.
			invalidplayeritems[idx] = nil
		end
	end
end)

-- Leak check. Run this in the client console any time — ideally late in a busy map,
-- since the failure mode it detects only accumulates with join/leave churn.
--
-- ORPHANED should always be 0. Anything above zero means ClientsideModels are being
-- kept for players who have left, which is the bug PS_CleanupClientsideModels fixes.
-- Left unchecked those exhaust the clientside entity limit and models silently stop
-- rendering for everyone until the map changes.
concommand.Add("ps_leakcheck", function()
	local owners, models, orphaned, orphanOwners = 0, 0, 0, 0
	for ply, tbl in pairs(PS.ClientsideModels or {}) do
		owners = owners + 1
		local dead = not IsValid(ply)
		if dead then orphanOwners = orphanOwners + 1 end
		for _, mdl in pairs(tbl) do
			if IsValid(mdl) then
				models = models + 1
				if dead then orphaned = orphaned + 1 end
			end
		end
	end

	local custEntries, custDead = 0, 0
	for ply in pairs(PS_AccessoryCustomizations or {}) do
		custEntries = custEntries + 1
		if not IsValid(ply) then custDead = custDead + 1 end
	end

	local pending = 0
	for _ in pairs(invalidplayeritems) do pending = pending + 1 end

	MsgC(Color(100, 180, 255), "[PS leakcheck]\n")
	MsgC(color_white, string.format("  players tracked : %d  (%d invalid)\n", owners, orphanOwners))
	MsgC(color_white, string.format("  live models     : %d\n", models))
	MsgC(orphaned > 0 and Color(255, 80, 80) or Color(120, 220, 120),
		string.format("  ORPHANED        : %d  %s\n", orphaned,
			orphaned > 0 and "<-- LEAKING, cleanup hook is not firing" or "(ok)"))
	MsgC(custDead > 0 and Color(255, 200, 80) or color_white,
		string.format("  customizations  : %d  (%d for invalid players)\n", custEntries, custDead))
	MsgC(color_white, string.format("  pending queue   : %d entries\n", pending))
	MsgC(color_white, string.format("  players on server: %d\n", #player.GetAll()))
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
        -- Remove the entity before dropping the reference. Nilling the table entry on
        -- its own orphans the ClientsideModel — it stays alive, holding a slot against
        -- the clientside entity cap, with nothing left pointing at it.
        if not PS.Items[item_id] then
            if IsValid(model) then model:Remove() end
            PS.ClientsideModels[ply][item_id] = nil
            continue
        end
        local ITEM = PS.Items[item_id]
        if not ITEM.Attachment and not ITEM.Bone then
            if IsValid(model) then model:Remove() end
            PS.ClientsideModels[ply][item_id] = nil
            continue
        end
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
            local boneOverride = PS_ItemDefaultOverrides and PS_ItemDefaultOverrides[item_id] and PS_ItemDefaultOverrides[item_id].bone
            local bone_id = ply:LookupBone(boneOverride or ITEM.Bone)
            if not bone_id then continue end
            pos, ang = ply:GetBonePosition(bone_id)
            -- GetBonePosition returns nil,nil when the bone matrix isn't set up yet,
            -- which happens routinely on the spawn frame. Passing that on ends in
            -- model:SetPos(nil), and because this is PostPlayerDraw the error repeats
            -- every frame rather than once.
            if not pos or not ang then continue end
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
