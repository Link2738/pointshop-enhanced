local PANEL = {}

-- [[
--	DPointShopFrameworkTest
--	This is a proof of concept for the new UI framework architecture.
--	It uses NO absolute positioning, NO manual math, and NO imperative state updates.
--	Everything is handled by the VBox/HBox layout engine and the Reactive State.
-- ]]

function PANEL:Init()
	local UI = PS.UI
	local M = PS.Theme.Metrics

	self:SetSize(800, 500)
	self:Center()
	self:MakePopup()

	-- Set up the background
	self.Paint = function(s, w, h)
		PS.Theme.PaintFrame(w, h)
		PS.Theme.PaintStatusStrip(w, UI.HeaderH("strip"), "Framework Test (Flexbox & State)")
	end

	-- 1. Initialize Reactive State
	-- This completely decouples our data from our UI elements!
	self.State = UI.State({
		category = "Weapons",
		searchQuery = "",
		items = {
			{ name = "Golden Gun", category = "Weapons", price = 5000 },
			{ name = "Crowbar", category = "Weapons", price = 100 },
			{ name = "Red Trail", category = "Trails", price = 500 },
			{ name = "Blue Trail", category = "Trails", price = 500 },
		},
		selectedItem = nil
	})

	-- 2. Master VBox (Takes up entire frame minus header)
	local master = UI.VBox(self)
	master:Dock(FILL)
	master:DockMargin(M.Gap, UI.HeaderH("strip") + M.Gap, M.Gap, M.Gap)
	master:SetGap(M.Gap)

	-- 3. Top Toolbar (HBox)
	local toolbar = UI.HBox(master)
	master:AddNode(toolbar, { height = M.ButtonH }) -- Fixed height
	
	local lbl = vgui.Create("DLabel", toolbar)
	lbl:SetText("Category:")
	lbl:SetFont("PS_Heading3")
	lbl:SetTextColor(PS.Theme.Text)
	lbl:SizeToContents()
	toolbar:AddNode(lbl, { width = lbl:GetWide() + 10 }) -- Fixed width

	-- Category Buttons (Flexing width)
	local categories = {"Weapons", "Trails", "Admin"}
	for _, cat in ipairs(categories) do
		local btn = UI.Button(toolbar, cat, "Category", function()
			self.State.category = cat
			self.State.selectedItem = nil
		end)
		
		-- Bind the button's active state visually to the Reactive State
		btn.Paint = function(s, w, h)
			local active = (self.State.category == cat)
			s:SetTextColor(active and PS.Theme.Selectable.Category.textActive or PS.Theme.Text)
			PS.Theme.PaintSelectable(s, w, h, active, PS.Theme.Selectable.Category)
		end
		
		toolbar:AddNode(btn, { weight = 1 }) -- weight 1, they share space equally
	end

	-- 4. Main Content Splitter (HBox)
	local contentSplit = UI.HBox(master)
	master:AddNode(contentSplit, { weight = 1 }) -- weight 1, fills remaining vertical space
	
	-- Left: Item List (VBox)
	local listContainer = UI.VBox(contentSplit)
	contentSplit:AddNode(listContainer, { weight = 2 }) -- weight 2 (takes 2/3 of width)
	
	local scroll = UI.Scroll(listContainer)
	listContainer:AddNode(scroll, { weight = 1 }) -- fill vertical
	
	-- Right: Inspector / Details (VBox)
	local inspector = UI.VBox(contentSplit)
	contentSplit:AddNode(inspector, { weight = 1 }) -- weight 1 (takes 1/3 of width)
	
	-- Inspector Content
	local itemName = vgui.Create("DLabel", inspector)
	itemName:SetFont("PS_LargeTitle")
	itemName:SetTextColor(PS.Theme.Text)
	inspector:AddNode(itemName, { height = 40 })
	
	local itemPrice = vgui.Create("DLabel", inspector)
	itemPrice:SetFont("PS_Heading2")
	itemPrice:SetTextColor(PS.Theme.PriceAfford)
	inspector:AddNode(itemPrice, { height = 30 })

	local buyBtn = UI.Button(inspector, "Buy", "Positive", function()
		print("Bought " .. self.State.selectedItem.name)
	end)
	inspector:AddNode(buyBtn, { height = M.ButtonH })
	
	-- 5. Reactive Subscriptions
	-- When category changes, redraw the list
	self.State:Subscribe("category", function(st)
		scroll:Clear()
		
		local y = 0
		for _, item in ipairs(st.items) do
			if item.category == st.category then
				local row = UI.Button(scroll, item.name .. " - " .. item.price .. " pts", "Neutral", function()
					self.State.selectedItem = item
				end)
				row:SetPos(0, y)
				row:SetSize(scroll:GetWide(), M.RowH)
				y = y + M.RowH + 2
			end
		end
	end)

	-- When selected item changes, update the inspector panel automatically
	self.State:Subscribe("selectedItem", function(st)
		local item = st.selectedItem
		if item then
			itemName:SetText(item.name)
			itemPrice:SetText(tostring(item.price) .. " pts")
			buyBtn:SetVisible(true)
		else
			itemName:SetText("Select an item")
			itemPrice:SetText("")
			buyBtn:SetVisible(false)
		end
	end)
end

vgui.Register('DPointShopFrameworkTest', PANEL, 'DFrame')

-- Command to easily open it
concommand.Add("ps_framework_test", function()
	if IsValid(_PS_TEST_PANEL) then _PS_TEST_PANEL:Remove() end
	_PS_TEST_PANEL = vgui.Create("DPointShopFrameworkTest")
end)
