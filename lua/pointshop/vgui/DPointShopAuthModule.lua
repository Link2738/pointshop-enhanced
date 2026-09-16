local PANEL = {}

-- [[
--	DPointShopAuthModule
--	A proof-of-concept for the new Auth Module UI.
--	Built entirely on Framework.UI (State + Flexbox Layout).
-- ]]

function PANEL:Init()
	-- The new unified framework UI engine
	local UI = Framework.UI
	local M = PS.Theme.Metrics
	
	self:SetSize(900, 600)
	self:Center()
	self:MakePopup()
	self:SetTitle("")
	self:ShowCloseButton(false)

	self.Paint = function(s, w, h)
		PS.Theme.PaintFrame(w, h)
		PS.Theme.PaintStatusStrip(w, PS.UI.HeaderH("strip"), "Auth Module (Framework Preview)")
	end

	-- Close button top right
	local closeBtn = PS.UI.IconButton(self, PS.UI.GlyphIcon("close"), "Danger", function() self:Close() end)
	local sizeSelf = closeBtn.PerformLayout
	closeBtn.PerformLayout = function(s)
		if sizeSelf then sizeSelf(s) end
		s:SetPos(self:GetWide() - M.IconBtn - M.IconInset, PS.UI.IconBtnY(PS.UI.HeaderH("strip")))
	end
	
	-- 1. Reactive State
	self.State = UI.State({
		players = {},
		selectedPlayer = nil,
		search = ""
	})
	
	-- Mock load players
	for _, p in ipairs(player.GetAll()) do
		table.insert(self.State.players, { name = p:Nick(), group = "user", id = p:SteamID() })
	end

	-- 2. Master HBox (Splits the window into Left / Right columns)
	local master = UI.HBox(self)
	master:Dock(FILL)
	master:DockMargin(M.Gap, PS.UI.HeaderH("strip") + M.Gap, M.Gap, M.Gap)
	master:SetGap(M.Gap)
	
	-- ==========================================
	-- Left Column: Player List & Search
	-- ==========================================
	local leftCol = UI.VBox(master)
	master:AddNode(leftCol, 1) -- Takes 1/3 of the width (weight 1)
	
	local searchBox = vgui.Create("DTextEntry", leftCol)
	searchBox:SetPlaceholderText("Search players...")
	searchBox.OnChange = function(s) self.State.search = s:GetValue():lower() end
	leftCol:AddNode(searchBox, 0, M.ButtonH)
	
	local scroll = PS.UI.Scroll(leftCol)
	leftCol:AddNode(scroll, 1) -- Takes all remaining vertical space
	
	-- ==========================================
	-- Right Column: Player Inspector & Actions
	-- ==========================================
	local rightCol = UI.VBox(master)
	master:AddNode(rightCol, 2) -- Takes 2/3 of the width (weight 2)
	
	local nameLabel = vgui.Create("DLabel", rightCol)
	nameLabel:SetFont("PS_LargeTitle")
	nameLabel:SetTextColor(PS.Theme.Text)
	rightCol:AddNode(nameLabel, 0, 40)
	
	local groupLabel = vgui.Create("DLabel", rightCol)
	groupLabel:SetFont("PS_Heading2")
	groupLabel:SetTextColor(PS.Theme.Accent)
	rightCol:AddNode(groupLabel, 0, 30)
	
	local btnRow = UI.HBox(rightCol)
	rightCol:AddNode(btnRow, 0, M.ButtonH)
	
	local promoteBtn = PS.UI.Button(btnRow, "Promote to Admin", "Positive", function()
		print("Promoting " .. self.State.selectedPlayer.name)
	end)
	btnRow:AddNode(promoteBtn, 1) -- Buttons share space equally
	
	local kickBtn = PS.UI.Button(btnRow, "Kick", "Danger", function()
		print("Kicking " .. self.State.selectedPlayer.name)
	end)
	btnRow:AddNode(kickBtn, 1)

	-- ==========================================
	-- 3. Data Binding
	-- ==========================================
	
	-- Watch the search string; automatically rebuild the list when it changes
	self.State:Subscribe("search", function(val, st)
		scroll:Clear()
		local y = 0
		for _, p in ipairs(st.players) do
			if st.search == "" or string.find(p.name:lower(), st.search, 1, true) then
				local row = PS.UI.Button(scroll, p.name, "Neutral", function()
					self.State.selectedPlayer = p
				end)
				row:SetPos(0, y)
				row:SetSize(scroll:GetWide(), M.RowH)
				y = y + M.RowH + 2
			end
		end
	end)
	
	-- Watch the selected player; automatically update inspector details
	self.State:Subscribe("selectedPlayer", function(p, st)
		if p then
			nameLabel:SetText(p.name)
			groupLabel:SetText("Rank: " .. string.upper(p.group))
			promoteBtn:SetVisible(true)
			kickBtn:SetVisible(true)
		else
			nameLabel:SetText("Select a player on the left")
			groupLabel:SetText("")
			promoteBtn:SetVisible(false)
			kickBtn:SetVisible(false)
		end
	end)
end

vgui.Register("DPointShopAuthModule", PANEL, "DFrame")

-- Console command to test it easily
concommand.Add("ps_auth_test", function()
	if IsValid(_PS_AUTH_TEST) then _PS_AUTH_TEST:Remove() end
	_PS_AUTH_TEST = vgui.Create("DPointShopAuthModule")
end)
