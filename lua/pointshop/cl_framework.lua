--[[
	PointShop Enhanced / Unified Framework - UI Core
	
	This file implements the true modern UI framework pillars discussed:
	1. Reactive State Binding (Framework.State)
	2. Flexbox Layout Engine (Framework.VBox, Framework.HBox)
	3. Window Router (Framework.Router)
]]--

if not CLIENT then return end

Framework = Framework or {}
Framework.UI = Framework.UI or {}

local UI = Framework.UI

-- ============================================================================
-- 1. REACTIVE STATE ENGINE
-- ============================================================================
-- Creates an observable state object. UI elements can Subscribe() to keys.
function UI.State(initial_state)
	local state = initial_state or {}
	local listeners = {}
	
	local proxy = {}
	setmetatable(proxy, {
		__index = state,
		__newindex = function(t, k, v)
			if state[k] == v then return end
			state[k] = v
			
			if listeners[k] then
				for _, cb in pairs(listeners[k]) do
					-- Protected call so one bad UI update doesn't break state
					pcall(cb, v, state) 
				end
			end
			
			if listeners["*"] then
				for _, cb in pairs(listeners["*"]) do
					pcall(cb, k, v, state)
				end
			end
		end
	})
	
	function proxy:Subscribe(key, callback, fire_immediately)
		listeners[key] = listeners[key] or {}
		table.insert(listeners[key], callback)
		
		if fire_immediately ~= false and state[key] ~= nil then 
			callback(state[key], state) 
		end
		
		-- Return an unsubscribe function
		return function()
			for i, cb in ipairs(listeners[key]) do
				if cb == callback then
					table.remove(listeners[key], i)
					break
				end
			end
		end
	end
	
	return proxy
end

-- ============================================================================
-- 2. FLEXBOX LAYOUT ENGINE (Two-Pass: Measure & Arrange)
-- ============================================================================

local function SetupFlexNode(p, isHorizontal)
	p:SetPaintBackground(false)
	p._children = {}
	p._gap = 6
	p._padding = 0
	p._align = "stretch" -- "start", "center", "end", "stretch"
	
	function p:SetGap(g) self._gap = g end
	function p:SetPadding(p) self._padding = p end
	function p:SetAlign(a) self._align = a end
	
	function p:AddNode(child, flexWeight, fixedSize)
		child:SetParent(self)
		table.insert(self._children, {
			panel = child,
			weight = flexWeight,
			fixed = fixedSize -- width if HBox, height if VBox
		})
		self:InvalidateLayout()
		return child
	end
	
	local baseRemoveAll = p.Clear
	function p:Clear()
		self._children = {}
		if baseRemoveAll then baseRemoveAll(self) end
	end
	
	p.PerformLayout = function(s, w, h)
		w = w or s:GetWide()
		h = h or s:GetTall()
		local flexCount = 0
		local fixedTotal = 0
		local validChildren = {}
		
		for _, c in ipairs(s._children) do
			if IsValid(c.panel) and c.panel:IsVisible() then
				table.insert(validChildren, c)
				if c.weight and c.weight > 0 then 
					flexCount = flexCount + c.weight
				else 
					local size = c.fixed or (isHorizontal and c.panel:GetWide() or c.panel:GetTall())
					c.fixed = size
					fixedTotal = fixedTotal + size 
				end
			end
		end
		
		local numChildren = #validChildren
		if numChildren == 0 then return end
		
		local gapTotal = math.max(0, numChildren - 1) * s._gap
		local availableSpace = (isHorizontal and w or h) - (s._padding * 2)
		local flexSpace = math.max(0, availableSpace - fixedTotal - gapTotal)
		
		local flexUnit = flexCount > 0 and (flexSpace / flexCount) or 0
		
		local currentPos = s._padding
		
		for _, c in ipairs(validChildren) do
			local size = (c.weight and c.weight > 0) and (flexUnit * c.weight) or c.fixed
			local crossSize = isHorizontal and h or w
			
			if s._align == "stretch" then
				if isHorizontal then c.panel:SetSize(size, crossSize) else c.panel:SetSize(crossSize, size) end
			else
				-- Auto-size on cross axis if not stretching
				local px, py = 0, 0
				local cw, ch = c.panel:GetSize()
				
				if isHorizontal then
					cw = size
					if s._align == "center" then py = (h - ch) / 2
					elseif s._align == "end" then py = h - ch end
				else
					ch = size
					if s._align == "center" then px = (w - cw) / 2
					elseif s._align == "end" then px = w - cw end
				end
				
				c.panel:SetSize(cw, ch)
				if isHorizontal then c.panel:SetPos(currentPos, py) else c.panel:SetPos(px, currentPos) end
			end
			
			if isHorizontal and s._align == "stretch" then
				c.panel:SetPos(currentPos, 0)
			elseif not isHorizontal and s._align == "stretch" then
				c.panel:SetPos(0, currentPos)
			end
			
			currentPos = currentPos + size + s._gap
		end
		
		-- Auto-size the flex container if it's not stretching to fill a parent
		local finalSize = currentPos - s._gap + s._padding
		if isHorizontal and s:GetDock() ~= FILL and s:GetDock() ~= BOTTOM and s:GetDock() ~= TOP then
			s:SetWide(math.max(w, finalSize))
		elseif not isHorizontal and s:GetDock() ~= FILL and s:GetDock() ~= LEFT and s:GetDock() ~= RIGHT then
			s:SetTall(math.max(h, finalSize))
		end
	end
	return p
end

function UI.VBox(parent)
	local p = vgui.Create("DPanel", parent)
	return SetupFlexNode(p, false)
end

function UI.HBox(parent)
	local p = vgui.Create("DPanel", parent)
	return SetupFlexNode(p, true)
end

-- ============================================================================
-- 3. ROUTER / WINDOW MANAGER
-- ============================================================================
-- Handles pushing and popping views, managing the Screen Clicker, and background blur.

UI.Router = UI.Router or {}
UI.Router.Stack = {}

function UI.Router:Push(panelClass, args)
	-- Hide the current top panel
	if #self.Stack > 0 then
		local top = self.Stack[#self.Stack]
		if IsValid(top) then top:SetVisible(false) end
	end
	
	local panel = vgui.Create(panelClass)
	if panel.OnRouteParams then panel:OnRouteParams(args) end
	
	table.insert(self.Stack, panel)
	
	gui.EnableScreenClicker(true)
	
	-- Overwrite panel's close method so it routes properly instead of just dying
	panel._OldClose = panel.Close
	panel.Close = function(s)
		UI.Router:Pop()
	end
	
	return panel
end

function UI.Router:Pop()
	if #self.Stack == 0 then return end
	
	local top = table.remove(self.Stack)
	if IsValid(top) then
		if top._OldClose then top:_OldClose() else top:Remove() end
	end
	
	if #self.Stack > 0 then
		local prev = self.Stack[#self.Stack]
		if IsValid(prev) then prev:SetVisible(true) end
	else
		gui.EnableScreenClicker(false)
	end
end

function UI.Router:Clear()
	while #self.Stack > 0 do
		self:Pop()
	end
end
