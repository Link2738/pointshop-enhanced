local PANEL = {}

function PANEL:Init()
	local UI = PS.UI
	local M  = PS.Theme.Metrics

	UI.SetupFrame(self, {
		title    = "Give",
		w        = 300,
		h        = 180 + UI.HeaderH(), -- Slightly taller to accommodate form margins comfortably
		remember = "givepoints",
	})

	self:SetDeleteOnClose(true)
	self:SetBackgroundBlur(true)
	self:SetDrawOnTop(true)

	-- 1. Initialize Reactive State
	self.State = Framework.UI.State({
		uid = nil,
		points = 0
	})

	local r = PS.UI.Rows(self)
	
	r:Header("Recipient")
	local plyselector = r:Choice({
		placeholder = "Select a player...",
		options     = {},
		get         = function() return self.State.uid end,
		set         = function(val) self.State.uid = val end
	})
	for _, ply in ipairs(player.GetAll()) do
		if ply ~= LocalPlayer() then
			plyselector:AddChoice(ply:GetName(), ply:UniqueID())
		end
	end

	r:Header("Amount")
	local pointsselector = r:Slider({
		label = "Points to Give",
		min   = 0,
		max   = LocalPlayer():PS_GetPoints(),
		get   = function() return self.State.points end,
		set   = function(val) self.State.points = val end
	})
	
	-- Binding: Red text if invalid amount
	self.State:Subscribe("points", function(_, st)
		if st.points < 1 or st.points > LocalPlayer():PS_GetPoints() then
			pointsselector.TextArea:SetTextColor(Color(180, 0, 0, 255))
		else
			pointsselector.TextArea:SetTextColor(PS.Theme.Text)
		end
	end)

	r:Space(1)

	-- Button Row
	local btnRow = Framework.UI.HBox(self)
	r:Custom(btnRow, M.ButtonH)
	
	local cancel = PS.UI.Button(nil, "Cancel", "Neutral", function() self:Close() end)
	local done   = PS.UI.Button(nil, "Send", "Positive", function() self:Submit() end)
	
	btnRow:AddNode(cancel, 1)
	btnRow:AddNode(done, 1)

	-- Binding: Disable done button if invalid state
	local function checkDisabled(_, st)
		local invalid = (not st.uid) or (st.points < 1) or (st.points > LocalPlayer():PS_GetPoints())
		done:SetDisabled(invalid)
	end
	self.State:Subscribe("uid", checkDisabled)
	self.State:Subscribe("points", checkDisabled)
end

function PANEL:Submit()
	local target
	for _, ply in ipairs(player.GetAll()) do
		if tonumber(ply:UniqueID()) == tonumber(self.State.uid) then
			target = ply
			break
		end
	end
	
	if not target then return end -- player could have left

	net.Start('PS_SendPoints')
		net.WriteEntity(target)
		net.WriteInt(self.State.points, 32)
	net.SendToServer()
	self:Close()
end

vgui.Register('DPointShopGivePoints', PANEL, 'DFrame')