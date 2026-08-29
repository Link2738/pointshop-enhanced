--[[
	PointShop - Widget layer

	Construction, where cl_theme.lua is paint.

	The shop had no shared widget layer, so the same recipe existed in six copies: 76
	hand-written Paint functions, 28 buttons each with its own, 5 separately styled
	scrollbars. They drifted apart one edit at a time — which is why the greys disagreed, and
	why the same scrim bug sat in five files. It was pasted, not shared.

	Everything here returns a real Derma panel. Callers still Dock, SetSize, and hook events
	exactly as before; this wraps Derma rather than replacing it, so nothing has to be learned
	twice and any panel can drop out of it for one control without leaving the system.

	No Paint function below allocates. Colours come from PS.Theme, and anything derived goes
	through T.Shade / T.Alpha into a scratch the caller owns. That is the whole reason the
	shop was rebuilding 123 Colors a frame.
]]

PS = PS or {}
PS.UI = PS.UI or {}

local UI = PS.UI

local function T() return PS.Theme end
local function M() return PS.Theme.Metrics end

-- Scratch for the one derived colour this file paints. Owned here rather than shared with
-- cl_theme's pool for the reason given on T.Shade: two panels painting in the same frame
-- would otherwise hand the same table to two draw calls.
local sSectionRule = Color(255, 255, 255, 255)

-- ============================================================================
-- BUTTONS
-- ============================================================================

-- Labelled action button. `style` names an entry in PS.Theme.Action — "Positive",
-- "Warning", "Neutral", and so on.
function UI.Button(parent, label, style, onClick)
	local btn = vgui.Create("DButton", parent)
	btn:SetText("")
	btn:SetTall(M().ButtonH)
	btn.DoClick = onClick or function() end
	btn.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action[style] or PS.Theme.Action.Neutral, label)
	end
	return btn
end

-- Square button carrying a drawn glyph rather than a label.
--
-- `icon` is a function(w, h) that draws into the button, not a string: the header icons are
-- hand-drawn shapes and swatch grids, not text, and the ones that ARE text want their own
-- shadow offset. Handing the caller the surface is simpler than a config table trying to
-- describe every case.

-- Icons, by name rather than by character. Call sites say UI.GlyphIcon("bolt").
--
-- x and y are per icon because they need to be: the three glyphs come from different fallback
-- fonts and sit differently in their own boxes, so one shared offset cannot fix all three.
--
-- Constants, deliberately. These correct for where a font draws a character, which does not
-- vary by server or by player -- so there is nothing here for anyone to configure, and the
-- values below are the settled ones.
--
-- They were client convars for a while, driven by a tuning panel, with the results printed to
-- be pasted back here by hand. That made them neither a constant nor stored data.
UI.Icons = {
	close = { glyph = "X",  x = 0, y =  1 },
	bolt  = { glyph = "⚡", x = 0, y = -4 },
	star  = { glyph = "★", x = 0, y = -2 },
	wear  = { glyph = "◨", x = 0, y = -1 },   -- loadouts: a panel half out from behind another
}

-- Shared by every icon: the button's place in the header, and the shadow behind the glyph.
UI.IconShared = { ButtonY = 0, ShadowX = 1, ShadowY = 1 }

-- Both scale with the screen.
--
-- The numbers above are pixel nudges authored against the reference resolution, and the glyph
-- they are nudging grows with the font. Left unscaled, a correction that centres a character
-- at 1080p leaves it visibly off at 1440p and twice as far off at 2160p -- the shadow in
-- particular, which is a one-pixel offset that has to stay one pixel *relative to the text*.
local function Scaled(v)
	return math.Round(v * PS.Theme.Scale())
end

local function Shared(k)
	return Scaled(UI.IconShared[k] or 0)
end

local function Offset(name)
	local d = UI.Icons[name]
	if not d then return 0, 0 end
	return Scaled(d.x), Scaled(d.y)
end

-- Vertical centre for an icon button sitting in a bar of the given height.
--
-- Takes the height rather than reading HeaderH, because there are two bars: the shop's tall
-- header and the status strip every other window uses as its header. A function that could
-- only centre in one of them stranded the X halfway up the other.
function UI.IconBtnY(barH)
	return math.floor(((barH or M().HeaderH) - M().IconBtn) / 2) + Shared("ButtonY")
end

function UI.GlyphIcon(name, font)
	font = font or "PS_Heading2"
	local def = UI.Icons[name]
	local glyph = def and def.glyph or name   -- a raw character still works

	return function(w, h)
		local ox, oy = Offset(name)
		local cx, cy = w / 2 + ox, h / 2 + oy
		draw.SimpleText(glyph, font, cx + Shared("ShadowX"), cy + Shared("ShadowY"),
			PS.Theme.Shadow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		-- ButtonText, not HeaderText. A glyph sits on a button fill -- Danger, Modify, Accent
		-- -- which is exactly what ButtonText is for. HeaderText is the title on the bar, and
		-- one token covering both meant a look could not have a dark title on a pale bar and
		-- white glyphs on a red one. Classic wants precisely that.
		draw.SimpleText(glyph, font, cx, cy,
			PS.Theme.ButtonText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- REMEMBERED PANEL POSITIONS
--
-- Drag a panel somewhere and it opens there next time, across reopens, map changes and
-- rejoins. Stored with the client's palette in PS.Theme.Panels -- same store, because it
-- is the same thing: this client's own record of how they like the UI.
--
-- Restored positions are CLAMPED to the current screen, which is why this is a helper
-- rather than four lines in each panel. A position saved on a second monitor, or before a
-- resolution change, is coordinates that no longer exist -- and a panel restored
-- off-screen cannot be dragged back, because there is nothing left to grab.
function UI.RememberPosition(panel, key)
	if not IsValid(panel) or not key then return end

	local w, h = panel:GetSize()
	panel:SetPos(ScrW() / 2 - w / 2, ScrH() / 2 - h / 2)

	local saved = PS.Theme.Panels and PS.Theme.Panels[key]
	if saved and saved.x and saved.y then
		panel:SetPos(math.Clamp(saved.x, 0, math.max(0, ScrW() - w)),
			math.Clamp(saved.y, 0, math.max(0, ScrH() - h)))
	end

	-- Saved when the drag ENDS, not while it happens, or this writes a file every frame the
	-- panel is moving. DFrame sets Dragging for the duration.
	local oldThink = panel.Think
	panel.Think = function(s, ...)
		if oldThink then oldThink(s, ...) end

		if s.Dragging then
			s._posMoved = true
		elseif s._posMoved then
			s._posMoved = nil
			local x, y = s:GetPos()
			PS.Theme.Panels[key] = { x = math.Round(x), y = math.Round(y) }
			PS.Theme.SavePanels()
		end
	end
end

-- Forgets every remembered position. The way back for a panel that ended up somewhere
-- unreachable despite the clamp.
concommand.Add("ps_reset_panels", function()
	PS.Theme.Panels = {}
	PS.Theme.SavePanels()
	chat.AddText(PS.Theme.Accent, "[PS] ", color_white, "Panel positions reset.")
end, nil, "Forget remembered panel positions.")

function UI.IconButton(parent, icon, style, onClick)
	local btn = vgui.Create("DButton", parent)
	btn:SetText("")
	btn:SetSize(M().IconBtn, M().IconBtn)

	-- Re-read on every layout pass, not just at creation.
	--
	-- IconBtn moves when the look changes and again when the screen resolution does, and a
	-- size set once at build time cannot follow either. A caller that needs to position the
	-- button as well must WRAP this rather than replace it -- see DPointShopMenu's header
	-- buttons, which call it before setting their own position.
	btn.PerformLayout = function(s)
		s:SetSize(M().IconBtn, M().IconBtn)
	end

	btn.DoClick = onClick or function() end
	btn.Paint = function(s, w, h)
		PS.Theme.PaintAction(s, w, h, PS.Theme.Action[style] or PS.Theme.Action.Neutral)
		if icon then icon(w, h) end
	end
	return btn
end

-- ============================================================================
-- ROWS
--
-- Stacks labelled controls down a panel and keeps track of how tall the stack got.
--
-- Exists because every panel that needed a column of sliders was hand-placing them, and
-- hand-placed coordinates are how a combo box ends up too short for its own drop arrow and
-- a buttons row ends up half off the bottom of its window. A caller adds rows and asks for
-- the height; it never sees a Y coordinate.
--
--     local rows = PS.UI.Rows(body)
--     rows:Choice{ label = "Mode", options = {...}, get = ..., set = ... }
--     rows:Slider{ label = "Width", min = 320, max = 2560, get = ..., set = ... }
--     frame:SetTall(header + rows:Height() + footer)
--
-- Control heights come from the metrics, so they scale with the screen like everything
-- else, and they are a floor rather than a preference: DComboBox and DNumSlider both lay
-- out children inside themselves and misdraw when squeezed.
-- ============================================================================

-- parent may be nil, which measures instead of building.
--
-- A panel has to know how tall its contents are BEFORE it can size the window it will
-- put them in, and the contents cannot be built before that window exists. So the same
-- calls run twice: once with no parent to get a height, once for real. `width` supplies
-- the intended content width to the measuring pass, since there is no panel to ask.
-- `startY` starts the cursor below something the rows do not own -- a header strip painted by
-- the panel itself. Height() then includes it, which is what the caller wants when sizing.
--
-- Named startY rather than top because every row builder below already has a `local top` for
-- its own position, and a parameter of that name would sit shadowed behind all of them.
function UI.Rows(parent, width, startY)
	local r = { parent = parent, y = startY or 0 }

	function r:LabelH() return math.Round(16 * PS.Theme.Scale()) end
	function r:CtrlH()  return M().ButtonH end
	function r:Gap()    return M().Gap end
	function r:Width()
		if not parent then return (width or 0) - M().Margin * 2 end
		return parent:GetWide() - M().Margin * 2
	end

	function r:Height() return self.y end

	-- A caption above a control, for controls that do not draw their own.
	function r:Label(text)
		if not parent then self.y = self.y + self:LabelH() return end

		local l = vgui.Create("DLabel", parent)
		l:SetText(text or "")
		l:SetFont("PS_DefaultBold")
		l:SetTextColor(PS.Theme.Text)

		local top = self.y
		l.PerformLayout = function(s)
			s:SetPos(M().Margin, top)
			s:SetSize(r:Width(), r:LabelH())
		end

		self.y = self.y + self:LabelH()
		return l
	end

	-- A section header: the name of a group of rows, with a rule under it.
	--
	-- Distinct from Label, which is a caption for one control. A panel with three groups in a
	-- column and nothing but bold captions between them reads as one long list -- the rule is
	-- what says where a group ends.
	--
	-- The rule is Accent, the same token every other divider, outline and strip edge in the
	-- addon pulls from. A section header is a shared role, so it gets the shared colour rather
	-- than a per-panel one -- which is how HeaderBG and StatusBar became two names for the
	-- same bar.
	function r:Header(text)
		local h = self:LabelH() + math.Round(6 * PS.Theme.Scale())

		if not parent then
			self.y = self.y + h + self:Gap()
			return
		end

		local p = vgui.Create("DPanel", parent)
		p.Paint = function(s, w, ph)
			draw.SimpleText(text or "", "PS_DefaultBold", 0, 0,
				PS.Theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			surface.SetDrawColor(PS.Theme.Alpha(sSectionRule, PS.Theme.Accent, 130))
			surface.DrawRect(0, ph - 1, w, 1)
		end

		local top = self.y
		p.PerformLayout = function(s)
			s:SetPos(M().Margin, top)
			s:SetSize(r:Width(), h)
		end

		self.y = self.y + h + self:Gap()
		return p
	end

	-- DComboBox draws no label of its own, so it gets one above it.
	function r:Choice(opts)
		if opts.label then self:Label(opts.label) end
		if not parent then self.y = self.y + self:CtrlH() + self:Gap() return end

		local combo = vgui.Create("DComboBox", parent)
		combo:SetSortItems(false)

		local current = opts.get and opts.get()
		for _, o in ipairs(opts.options or {}) do
			combo:AddChoice(o.name, o.id, o.id == current)
		end
		if not combo:GetSelected() then combo:SetValue(opts.placeholder or "") end

		local top = self.y
		combo.PerformLayout = function(s)
			s:SetPos(M().Margin, top)
			s:SetSize(r:Width(), r:CtrlH())
		end

		-- Same guard, same reason: AddChoice with the selected flag can arrive as a selection.
		combo._seeding = true
		timer.Simple(0, function() if IsValid(combo) then combo._seeding = false end end)

		combo.OnSelect = function(s, _, _, data)
			if s._seeding then return end
			if opts.set then opts.set(data) end
		end

		self.y = self.y + self:CtrlH() + self:Gap()
		return combo
	end

	-- DNumSlider draws its own label inline, so it does not get one above it.
	function r:Slider(opts)
		if not parent then self.y = self.y + self:CtrlH() + self:Gap() return end

		local sl = vgui.Create("DNumSlider", parent)
		sl:SetText(opts.label or "")
		sl:SetMin(opts.min or 0)
		sl:SetMax(opts.max or 100)
		sl:SetDecimals(opts.decimals or 0)

		-- Seeded, and the seeding must not read as an edit.
		--
		-- DNumSlider does not fire OnValueChanged from SetValue directly -- it fires later,
		-- when its internal DSlider settles, which is after this function has finished wiring
		-- the callback up. So filling a panel in with its current values arrives at the caller
		-- as the user having changed every one of them.
		--
		-- That is how opening the shop layout panel silently counted as editing the look, which
		-- moved the player to Custom and left Classic showing something else entirely. The
		-- colour mixer already guards the same thing with frame._seeding.
		sl._seeding = true
		if opts.get then sl:SetValue(opts.get()) end
		timer.Simple(0, function() if IsValid(sl) then sl._seeding = false end end)

		sl.Label:SetTextColor(PS.Theme.Text)

		local top = self.y
		sl.PerformLayout = function(s)
			s:SetPos(M().Margin, top)
			s:SetSize(r:Width(), r:CtrlH())
		end

		sl.OnValueChanged = function(s, v)
			if s._seeding then return end
			if not opts.set then return end

			-- Rounded only when the slider has no decimals.
			--
			-- It used to round unconditionally, which was right for every caller at the time --
			-- window sizes and metrics are whole pixels. It is wrong the moment a slider asks
			-- for decimals: a 0.1-to-2 scale with two of them would arrive as 0, 1 or 2.
			opts.set((opts.decimals or 0) == 0 and math.Round(v) or v)
		end

		self.y = self.y + self:CtrlH() + self:Gap()
		return sl
	end

	-- A block of prose: an item's description, a note under a control.
	--
	-- Wrapped and self-sizing, so its height depends on the text and the width it is given.
	-- That makes it the one row whose height is not known until it has been laid out, which is
	-- why the cursor advances by a measured height rather than a fixed one.
	function r:Text(text, opts)
		opts = opts or {}

		local font  = opts.font or "PS_Default"
		local lines = opts.lines or 3

		-- Measured from the FONT, not from the generic label height.
		--
		-- This used LabelH(), which is 16 scaled pixels -- right for body text and far too
		-- short for anything else. A PS_LargeTitle line got a body-text box and had its top
		-- and bottom sliced off, which is what the item name and the price looked like.
		--
		-- GetTextSize rather than a table of per-font heights: the fonts are rebuilt whenever
		-- the scale changes, so asking is the only answer that cannot go stale.
		surface.SetFont(font)
		local _, lineH = surface.GetTextSize("Wg")

		local height = math.Round(lineH * lines)

		if not parent then
			self.y = self.y + height + self:Gap()
			return
		end

		local l = vgui.Create("DLabel", parent)
		l:SetText(text or "")
		l:SetFont(font)
		l:SetTextColor(opts.colour or PS.Theme.MenuRowText)
		l:SetWrap(true)

		-- Top-aligned either way, because wrapped text centres itself vertically inside its box
		-- and a two-line description would then sit lower than a one-line one.
		l:SetContentAlignment(opts.align == "center" and 8 or 7)

		local top = self.y
		l.PerformLayout = function(s)
			s:SetPos(M().Margin, top)
			s:SetSize(r:Width(), height)
		end

		self.y = self.y + height + self:Gap()
		return l
	end

	-- An action button, in one of the Action styles.
	function r:Button(label, style, onClick)
		if not parent then
			self.y = self.y + self:CtrlH() + self:Gap()
			return
		end

		local b = UI.Button(parent, label, style, onClick)

		local top = self.y
		b.PerformLayout = function(s)
			s:SetPos(M().Margin, top)
			s:SetSize(r:Width(), r:CtrlH())
		end

		self.y = self.y + self:CtrlH() + self:Gap()
		return b
	end

	-- Anything this builder does not know about: a colour mixer, a model panel, a grid.
	--
	-- The caller creates it and says how tall it is; the row places it and moves the cursor
	-- past it. That is the whole contract -- a builder that tried to own every control would
	-- either be enormous or refuse the interesting ones.
	function r:Custom(panel, height)
		height = math.Round(height * PS.Theme.Scale())

		if not parent or not IsValid(panel) then
			self.y = self.y + height + self:Gap()
			return panel
		end

		local top = self.y
		panel.PerformLayout = function(s)
			s:SetPos(M().Margin, top)
			s:SetSize(r:Width(), height)
		end

		self.y = self.y + height + self:Gap()
		return panel
	end

	-- Blank vertical space, for separating groups.
	function r:Space(mul)
		self.y = self.y + math.Round(self:Gap() * (mul or 1))
	end

	return r
end

-- One of a set where exactly one is active: category buttons, tabs, value pickers.
--
-- `isActive` is a function rather than a flag because the active one changes without this
-- button being told — clicking a sibling has to redraw this one, and asking at paint time is
-- the only version that cannot go stale.
--
-- It is handed the button, so a caller that stores the flag on the panel can write
-- `function(s) return s.IsActive end` rather than closing over a local that does not exist
-- yet at the point the callback is written.
function UI.Tab(parent, label, isActive, onClick, style)
	local btn = vgui.Create("DButton", parent)
	local styleName = style or "Category"

	btn:SetText(label or "")
	btn:SetFont("PS_CategoryButton")
	btn.DoClick = onClick or function() end

	-- Text colour is resolved per frame from the style rather than set once from the one
	-- global Text.
	--
	-- Set-once was wrong twice over. A look that darkens body text could not leave a tab's
	-- text light where the tab is filled, and a look whose tab strip IS the body surface --
	-- no fill, text directly on the panel -- had no way to give active, hovered and idle tabs
	-- the three different weights that then carry the whole selection signal.
	--
	-- Falls back to Text for any style that names none, which is every style today, so this
	-- resolves to exactly the previous behaviour.
	-- Resolved in Paint, not in UpdateColours. Derma calls UpdateColours from
	-- ApplySchemeSettings — on construction and skin changes — not every frame, so a colour
	-- that depends on the live active state would go stale there. Paint always runs, and
	-- SetTextColor marks the colour as overridden so Derma's own scheme pass leaves it alone.
	btn.Paint = function(s, w, h)
		local st = PS.Theme.Selectable[styleName]
		local active = isActive and isActive(s) or false

		s:SetTextColor(
			(active and st.textActive)
			or (s.Hovered and st.textHover)
			or st.text
			or PS.Theme.Text
		)

		PS.Theme.PaintSelectable(s, w, h, active, st)
	end
	return btn
end

-- ============================================================================
-- CONTAINERS
-- ============================================================================

-- DScrollPanel with a themed bar.
--
-- The bar is styled here rather than by each caller because it was the single most copied
-- block in the addon — five instances, all subtly different widths and colours.
function UI.Scroll(parent)
	local scroll = vgui.Create("DScrollPanel", parent)

	local bar = scroll:GetVBar()
	bar:SetWide(M().ScrollW)
	bar:SetHideButtons(true)
	bar.Paint = function(_, w, h) PS.Theme.PaintScrollTrack(w, h) end
	bar.btnGrip.Paint = function(s, w, h) PS.Theme.PaintScrollGrip(s, w, h) end

	return scroll
end

-- A scrolling list of rows.
--
-- :AddRow() returns the row panel; put whatever you like in it. The list tracks the index so
-- the alternating stripe survives rows being added over time rather than all at once.
function UI.List(parent)
	local list = UI.Scroll(parent)
	list._rows = 0

	function list:AddRow(tall)
		self._rows = self._rows + 1
		local index = self._rows

		local row = vgui.Create("DPanel", self)
		row:Dock(TOP)
		row:SetTall(tall or M().RowH)
		row:DockMargin(0, 0, 0, 2)
		row.Index = index
		row.Paint = function(s, w, h)
			PS.Theme.PaintRow(s, w, h, s.Index, s.Selected)
		end
		return row
	end

	function list:Reset()
		self:Clear()
		self._rows = 0
	end

	return list
end

-- ============================================================================
-- ORBIT CAMERA
--
-- One camera, for the inspector, the customization panel and the owner-defaults tool.
--
-- All three had their own: the same spherical orbit around the player from the same four
-- numbers -- a rotation in degrees, a height offset, a radius and a vertical angle -- with the
-- same CalcView hook computing the same view. Three copies of one idea, and they had already
-- drifted: only the inspector could be driven by the mouse, because it happens to be fullscreen
-- and so catches drags over the world; only the inspector could tilt, the other two pinning phi
-- at the horizon; and only two of the three reused their tables rather than allocating a view
-- and three Vectors every frame.
--
-- The orbit OWNS the four numbers. That is what makes one system rather than three: the sliders
-- and the mouse are two ways of writing the same state, instead of the camera reading whatever
-- the sliders happen to say and the mouse writing into the sliders behind its back.
-- ============================================================================

local ORBIT_MIN_PHI = math.rad(10)
local ORBIT_MAX_PHI = math.rad(170)

function UI.Orbit(name, opts)
	opts = opts or {}

	local o = {
		rot    = opts.rot or 180,
		height = opts.height or 0,
		radius = opts.radius or 80,
		phi    = math.pi / 2,

		minRadius = opts.minRadius or 30,
		maxRadius = opts.maxRadius or 200,

		hookName = "PS_Orbit_" .. name,

		-- Reused every frame. CalcView runs per frame per player, so a fresh table and three
		-- Vectors here is garbage forever.
		_view   = {},
		_origin = Vector(),
		_delta  = Vector(),
	}

	-- Called after the mouse changes anything, so a panel can push the new values into its
	-- sliders. Without it the sliders and the camera disagree the moment you drag.
	o.OnChange = opts.OnChange

	local function changed()
		if o.OnChange then o.OnChange(o) end
	end

	-- The view, from the four numbers. `active` decides whether it applies at all.
	function o:Start(active)
		hook.Add("CalcView", self.hookName, function(ply, pos, angles, fov)
			if ply ~= LocalPlayer() or not IsValid(ply) then return end
			if active and not active() then return end

			local theta  = math.rad(self.rot)
			local sinPhi = math.sin(self.phi)

			local p = ply:GetPos()
			local tx, ty, tz = p.x, p.y, p.z + 64 + self.height

			local dx = self.radius * sinPhi * math.cos(theta)
			local dy = self.radius * sinPhi * math.sin(theta)
			local dz = self.radius * math.cos(self.phi)

			local origin = self._origin
			origin.x, origin.y, origin.z = tx + dx, ty + dy, tz + dz

			-- target - origin, i.e. the direction from the camera back to the player.
			local delta = self._delta
			delta.x, delta.y, delta.z = -dx, -dy, -dz

			local view = self._view
			view.origin     = origin
			view.angles     = delta:Angle()
			view.fov        = fov
			view.drawviewer = true

			return view
		end)
	end

	function o:Stop()
		hook.Remove("CalcView", self.hookName)
	end

	-- Drag to orbit, wheel to raise, shift-wheel to change distance.
	--
	-- `blocked` is for a panel that has UI over its own input surface: the inspector's control
	-- panel sits inside its fullscreen catcher, and without this, pressing a slider started a
	-- drag underneath it.
	function o:Attach(panel, blocked)
		panel:SetMouseInputEnabled(true)

		panel.OnMousePressed = function(s, code)
			if code ~= MOUSE_LEFT then return end
			if blocked and blocked() then return end

			s._orbiting = true
			s._orbitX, s._orbitY = gui.MousePos()
		end

		panel.OnMouseReleased = function(s, code)
			if code == MOUSE_LEFT then s._orbiting = false end
		end

		-- The bare wheel raises and lowers; shift changes the distance.
		--
		-- Round that way to match Blender, so a player who already orbits a viewport for a
		-- living does not have to learn a second set of habits to look at a hat.
		panel.OnMouseWheeled = function(s, delta)
			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
				o.radius = math.Clamp(o.radius - delta * 5, o.minRadius, o.maxRadius)
			else
				o.height = math.Clamp(o.height + delta * 5, -100, 100)
			end

			changed()
			return true
		end

		-- Polled in Think because VGUI has no drag event: the delta is the difference in
		-- cursor position since the last frame.
		panel.OrbitThink = function(s)
			if not s._orbiting then return end

			local mx, my = gui.MousePos()
			local dx, dy = mx - (s._orbitX or mx), my - (s._orbitY or my)

			o.rot = (o.rot + dx * 0.5) % 360
			o.phi = math.Clamp(o.phi + math.rad(dy * 0.5), ORBIT_MIN_PHI, ORBIT_MAX_PHI)

			s._orbitX, s._orbitY = mx, my
			changed()
		end

		return panel
	end

	return o
end

-- ============================================================================
-- FRAMES
-- ============================================================================

-- The bar across the top of a window, in its two forms.
--
-- "bar" is what a window gets: a proper header with its title in it. "strip" is the thinner
-- status line, for a panel that wants to say something live under its header rather than
-- instead of one -- Movement's "saved to the server", Customization's "preview enabled".
--
-- Both paint StatusBar on the same fade, so a window reads as a window either way.
function UI.HeaderH(mode)
	if mode == "strip" then return M().IconBtn + M().Gap * 2 end
	return M().HeaderH
end

-- Applies the standard window chrome to a frame that already exists.
--
-- Separate from UI.Frame because a registered panel IS the frame -- DPointShopMenu and the
-- rest derive from DFrame, so they cannot call something whose first act is to create one.
-- Before this there were thirteen windows each setting up its own body, header, close button
-- and remembered position, and that is the reason the palette grew a token every time a panel
-- was added: a window that builds its own chrome is a window that can invent a colour for it.
--
-- opts: title, w, h, header ("bar" | "strip", default "strip"), closable (default true),
--       onClose, center (default true), draggable (default true), sizable (default false),
--       popup (default true), remember (a key: the panel opens where it was last dragged)
function UI.SetupFrame(frame, opts)
	opts = opts or {}

	local mode = opts.header or "bar"

	frame:SetSize(opts.w or 600, opts.h or 400)
	frame:SetTitle("")
	frame:ShowCloseButton(false)
	frame:SetDraggable(opts.draggable ~= false)
	frame:SetSizable(opts.sizable or false)

	if opts.center ~= false then frame:Center() end
	if opts.popup ~= false then frame:MakePopup() end
	if opts.remember then UI.RememberPosition(frame, opts.remember) end

	frame.HeaderMode = mode

	-- Functions rather than stored numbers, for the same reason the icon buttons re-read
	-- their size: both metrics move with the look and with the window size, and a height
	-- captured once at build time cannot follow either.
	function frame:BarH() return UI.HeaderH(mode) end
	function frame:ContentTop() return self:BarH() + M().Gap end

	-- The strip is painted by the FRAME, not by the header panel, because its accent rule
	-- sits below the bar -- a panel exactly bar-height would clip the rule off its own
	-- bottom edge. Every hand-rolled strip panel already drew it on the frame for this
	-- reason; this just makes that the one place it happens.
	frame.Paint = function(self, w, h)
		PS.Theme.PaintFrame(w, h)
		if mode ~= "bar" then
			PS.Theme.PaintStatusStrip(w, self:BarH(), opts.title)
		end
	end

	-- Positioned, NOT docked.
	--
	-- DFrame reserves space at the top of its dock area for the title bar it is no longer
	-- drawing, so a docked header lands below the bar the frame paints at y=0. The bar and
	-- the panel sitting in it end up in different places, which is what put the X under the
	-- strip instead of in it.
	--
	-- Sizing itself in its OWN PerformLayout rather than the frame's, because a registered
	-- panel defines PANEL:PerformLayout and setting one on the instance here would silently
	-- replace it.
	local header = vgui.Create("DPanel", frame)
	header.PerformLayout = function(s)
		s:SetPos(0, 0)
		s:SetSize(frame:GetWide(), frame:BarH())
	end

	-- Centred, because the shop is the only window whose header carries anything else. Its
	-- title goes left to clear the points readout and the icon buttons, and it asks for that
	-- itself rather than every other window inheriting the exception.
	if mode == "bar" then
		header.Paint = function(_, w, h)
			PS.Theme.PaintHeader(w, h, opts.title, opts.titleLeft)
		end
	else
		header.Paint = function() end
	end

	-- The header drags the window.
	--
	-- DFrame only drags from its own top 24 pixels, and it used to get them because the dock
	-- padding left a band of bare frame above the header. With the header flush to the top
	-- that band is covered and the frame never sees the click, so the header hands it one.
	-- Setting frame.Dragging is what DFrame's own Think reads, so the movement is unchanged --
	-- and this drags from the whole bar rather than a 24px sliver of it.
	if opts.draggable ~= false then
		header.OnMousePressed = function(_, code)
			if code ~= MOUSE_LEFT then return end
			frame.Dragging = { gui.MouseX() - frame.x, gui.MouseY() - frame.y }
			frame:MouseCapture(true)
		end

		header.OnMouseReleased = function()
			frame.Dragging = nil
			frame:MouseCapture(false)
		end
	end

	frame.Header = header

	-- Docked content clears the bar through padding instead. This is what the docked header
	-- was doing, minus the offset that came with it.
	frame:DockPadding(0, frame:BarH(), 0, 0)

	if opts.closable ~= false then
		local close = UI.IconButton(header, UI.GlyphIcon("close"), "Danger", function()
			-- An onClose that returns true has taken responsibility for the window. The
			-- loadout panel slides home and removes itself when it arrives; closing it here
			-- as well would cut that off at the first frame.
			if opts.onClose and opts.onClose(frame) then return end
			frame:Close()
		end)

		-- Positioned in PerformLayout, not once at build time. A sizable frame moved the
		-- header out from under a one-shot SetPos and stranded the button mid-bar, or off
		-- the panel entirely.
		--
		-- Wraps IconButton's own PerformLayout rather than replacing it, so the button still
		-- re-reads its SIZE from the metrics when the look or the resolution changes.
		--
		-- Measured against the FRAME rather than the header. The header is full width in both
		-- modes so the two agree, but a panel that overrides PerformLayout without calling its
		-- base can leave the header unsized, and a width of zero puts the X off the left edge.
		-- The frame's width is always known.
		local sizeSelf = close.PerformLayout
		close.PerformLayout = function(s)
			if sizeSelf then sizeSelf(s) end
			s:SetPos(frame:GetWide() - M().IconBtn - M().IconInset,
				UI.IconBtnY(frame:BarH()))
		end

		frame.CloseButton = close
	end

	return frame
end

-- One window per class, at most.
--
-- Every open site was a bare vgui.Create, so pressing the button twice built a second panel
-- on top of the first -- two appearance editors writing the same palette, two admin panels
-- polling the same summary, and only the top one reachable to close.
--
-- Brings the open one forward rather than refusing silently, because from the player's side
-- the button did nothing either way and the honest response to "open this" is to show it.
UI.Windows = UI.Windows or {}

function UI.Open(class)
	local open = UI.Windows[class]

	if IsValid(open) then
		open:MoveToFront()
		open:RequestFocus()
		return open
	end

	local panel = vgui.Create(class)
	UI.Windows[class] = panel

	return panel
end

-- A themed window: body, border, header with a title, and a close button.
--
-- The thin wrapper for callers that want the frame made for them rather than applying the
-- chrome to one they already are.
function UI.Frame(opts)
	return UI.SetupFrame(vgui.Create("DFrame"), opts or {})
end

-- Modal yes/no.
--
-- Replaces three separately hand-built confirmation dialogs, which is also why the Yes and
-- No buttons had drifted into three different greens and greys.
--
-- opts: title, text, yes, no, onYes, onNo
function UI.Confirm(opts)
	opts = opts or {}

	local frame = UI.Frame({
		title    = opts.title or "Confirm",
		w        = opts.w or 400,
		h        = opts.h or 190,
		closable = false,
	})

	local body = vgui.Create("DPanel", frame)
	body:Dock(FILL)
	body:DockMargin(M().Margin, M().Margin, M().Margin, M().Margin)
	body.Paint = function(_, w, h)
		draw.SimpleText(opts.text or "", "PS_DefaultBold", w / 2, h / 2 - 20,
			PS.Theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local row = vgui.Create("DPanel", frame)
	row:Dock(BOTTOM)
	row:SetTall(M().ButtonH + M().Margin * 2)
	row:DockMargin(M().Margin, 0, M().Margin, 0)
	row.Paint = function() end

	local function Finish(fn)
		return function()
			frame:Close()
			if fn then fn() end
		end
	end

	local no = UI.Button(row, opts.no or "No", "Neutral", Finish(opts.onNo))
	no:Dock(RIGHT)
	no:SetWide(120)

	local yes = UI.Button(row, opts.yes or "Yes", "Positive", Finish(opts.onYes))
	yes:Dock(RIGHT)
	yes:DockMargin(0, 0, M().Gap, 0)
	yes:SetWide(120)

	return frame
end
