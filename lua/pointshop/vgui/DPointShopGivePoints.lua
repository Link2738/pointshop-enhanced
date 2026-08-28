local PANEL = {}

function PANEL:Init()
	local UI = PS.UI
	local M  = PS.Theme.Metrics

	-- The 144 was the whole window before it had a bar across the top. Adding the bar to it
	-- rather than into it keeps the content area exactly the size it was.
	UI.SetupFrame(self, {
		title    = "Give",
		w        = 300,
		h        = 144 + UI.HeaderH(),
		remember = "givepoints",
	})

	self:SetDeleteOnClose(true)
	self:SetBackgroundBlur(true)
	self:SetDrawOnTop(true)

	local function Label(text)
		local l = vgui.Create("DLabel", self)
		l:SetText(text)
		l:SetTextColor(PS.Theme.Text)
		l:Dock(TOP)
		l:DockMargin(M.Gap, 0, M.Gap, M.Gap)
		l:SizeToContents()
		return l
	end

	Label("Player:")

	local pselect = vgui.Create("DComboBox", self)
	pselect:SetValue("Select A Player")
	pselect:SetTall(M.ButtonH)
	pselect:Dock(TOP)
	pselect:DockMargin(M.Gap, 0, M.Gap, 0)
	self.playerselect = pselect

	self:FillPlayers()

	Label(PS.Config.PointsName .. ":")

	local pointsselector = vgui.Create("DNumberWang", self)
	pointsselector:SetTextColor(Color(0, 0, 0, 255))
	pointsselector:SetTall(M.ButtonH)
	pointsselector:Dock(TOP)
	pointsselector:DockMargin(M.Gap, 0, M.Gap, 0)
	self.pselector = pointsselector

	local btnlist = vgui.Create("DPanel", self)
	btnlist:SetPaintBackground(false)
	btnlist:SetTall(M.ButtonH)
	btnlist:DockMargin(M.Gap, M.Gap, M.Gap, M.Gap)
	btnlist:Dock(BOTTOM)

	-- Widths set explicitly: UI.Button only sets a height, and a panel docked RIGHT keeps
	-- whatever width it already had -- which for a bare DButton is its default, not anything
	-- anyone chose. Derived from ButtonH so it scales with the rest.
	local btnW = M.ButtonH * 3

	local cancel = UI.Button(btnlist, "Cancel", "Neutral", function()
		self:Close()
	end)
	cancel:Dock(RIGHT)
	cancel:SetWide(btnW)
	cancel:DockMargin(M.Gap, 0, 0, 0)
	self.cancel = cancel

	local done = UI.Button(btnlist, "Send", "Positive", function()
		self:Submit()
		self:Close()
	end)
	done:Dock(RIGHT)
	done:SetWide(btnW)
	done:SetDisabled(true)
	self.submit = done

	-- Repainted from the disabled state rather than the style it was built with, so a Send
	-- that cannot be pressed does not sit there looking pressable. SetDisabled alone blocks
	-- the click and says nothing.
	done.Paint = function(s, w, h)
		local style = s:GetDisabled() and PS.Theme.Action.Neutral or PS.Theme.Action.Positive
		PS.Theme.PaintAction(s, w, h, style, "Send")
	end

	self.selected_uid = nil
	pselect.OnSelect = function(s, idx, val, data)
		if data then self.selected_uid = data end

		self:Update()
	end

	pointsselector.OnValueChanged = function()
		self:Update()
	end
end

function PANEL:FillPlayers()
	for _, ply in pairs(player.GetAll()) do
		if ply == LocalPlayer() then continue end
		
		self.playerselect:AddChoice(ply:Nick(), ply:UniqueID())
	end
end

function PANEL:Submit()
	local other = false
	
	for _, ply in pairs(player.GetAll()) do
		if tonumber(ply:UniqueID()) == tonumber(self.selected_uid) then
			other = ply
		end
	end
	
	if not other then return end -- player could have left

	net.Start('PS_SendPoints')
		net.WriteEntity(other)
		net.WriteInt(tonumber(self.pselector:GetValue()), 32)
	net.SendToServer()
end

function PANEL:Update()
	local disabled = false

	if not self.selected_uid then disabled = true end
	
	if (self.pselector:GetValue() < 1) or (self.pselector:GetValue() > LocalPlayer():PS_GetPoints()) then
		disabled = true
		self.pselector:SetTextColor(Color(180, 0, 0, 255))
	else
		self.pselector:SetTextColor(Color(0, 0, 0, 255))
	end

	self.submit:SetDisabled(disabled)
end

vgui.Register('DPointShopGivePoints', PANEL, 'DFrame')