--[[
	DPointShopLoadouts

	Slides out from behind the shop, on whichever side has more room.

	Slots down the left, a full preview of the selected one filling the rest. Selecting shows
	it; applying is a separate press, because a preview you cannot look at without wearing is
	not a preview.

	Everything here is derived from PS.Theme.Scale(). The appearance panel's footer had to be
	rebuilt once because it held written-down coordinates that were only ever right at one
	size, and this panel opens next to a window whose size the player chooses.
]]--

local PANEL = {}

function PANEL:Init()
	local T, UI = PS.Theme, PS.UI
	local M, S  = T.Metrics, T.Scale()

	self.S     = S
	self.Edge  = M.Margin
	self.RowH  = M.ButtonH + M.Gap
	self.SlotW = math.Round(150 * S)

	UI.SetupFrame(self, {
		title = "Loadouts",
		w     = math.Round(520 * S),
		h     = math.Round(420 * S),

		-- Not draggable: it is anchored to the shop's edge, and dragging it away from that
		-- edge would leave it floating with a slide animation that no longer goes anywhere.
		draggable = false,

		-- Not centred, because Deploy positions it against the shop.
		center = false,

		-- NOT A POPUP, and this is load-bearing rather than incidental. The shop is not one
		-- either, so the two are siblings under the base panel and MoveToBack can order this
		-- behind it. MakePopup would promote this to a layer the shop is not on, and no
		-- amount of ordering would bring it back down.
		popup = false,

		-- Slides home and removes itself on arrival, so it owns its own close.
		onClose = function()
			self:Retract()
			return true
		end,
	})

	self.StripH = self:BarH()

	self.Preview = vgui.Create("DPointShopPreview", self)

	self.SlotList = vgui.Create("DScrollPanel", self)
	self.SlotList.Paint = function(_, pw, ph) T.PaintListBox(pw, ph) end

	self:BuildSlots()
	self:Select(PS.Loadouts.Active)

	-- Refusals arrive after an apply, and change what the rows say.
	hook.Add("PS_LoadoutResult", self, function()
		if IsValid(self) then self:BuildSlots() end
	end)
end

function PANEL:OnRemove()
	hook.Remove("PS_LoadoutResult", self)
end

function PANEL:PerformLayout(w, h)
	local M = PS.Theme.Metrics
	local top = self.StripH + self.Edge

	self.SlotList:SetPos(self.Edge, top)
	self.SlotList:SetSize(self.SlotW, h - top - self.Edge)

	local px = self.Edge * 2 + self.SlotW
	self.Preview:SetPos(px, top)
	self.Preview:SetSize(w - px - self.Edge, h - top - self.Edge)
end

-- ============================================================================
-- SLOTS
-- ============================================================================

function PANEL:BuildSlots()
	local L, T, UI = PS.Loadouts, PS.Theme, PS.UI
	local M = T.Metrics

	self.SlotList:Clear()

	for i = 1, L.MAX do
		local slot = L.Slots[i]

		local row = self.SlotList:Add("DButton")
		row:Dock(TOP)
		row:DockMargin(M.Gap, i == 1 and M.Gap or 0, M.Gap, M.Gap)
		row:SetTall(M.ButtonH)
		row:SetText("")

		row.Paint = function(s, pw, ph)
			T.PaintSelectable(s, pw, ph, self.Selected == i, T.Selectable.Category)

			local label = slot and (slot.name or ("Loadout " .. i)) or (i .. ".  empty")

			-- A slot whose items this server will not wear is named in the colour that says
			-- so, rather than looking identical to one that will.
			local col = T.Text
			if slot and self:SlotRefused(slot) then col = T.WarningBorder end
			if not slot then col = T.TextDim end

			draw.SimpleText(label, "PS_Default", M.Gap, ph / 2, col,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		row.DoClick = function() self:Select(i) end

		row.DoRightClick = function()
			local menu = DermaMenu()

			if slot then
				menu:AddOption("Wear this", function() L.Apply(i) self:BuildSlots() end)
				menu:AddOption("Overwrite with what I am wearing", function()
					L.Slots[i] = L.Capture(slot.name)
					L.Save()
					self:BuildSlots()
					self:Select(i)
				end)
				menu:AddOption("Delete", function()
					L.Slots[i] = nil
					if L.Active == i then L.Clear() end
					L.Save()
					self:BuildSlots()
					self:Select(nil)
				end)
			else
				menu:AddOption("Save what I am wearing here", function()
					L.Slots[i] = L.Capture()
					L.Save()
					self:BuildSlots()
					self:Select(i)
				end)
			end

			menu:Open()
		end
	end
end

-- Does this server currently refuse anything in the slot?
function PANEL:SlotRefused(slot)
	for _, entry in ipairs(slot.items or {}) do
		if PS.Loadouts.Refused[entry.id] then return true end
	end
	return false
end

-- ============================================================================
-- SELECTION
-- ============================================================================

function PANEL:Select(index)
	self.Selected = index

	local slot = index and PS.Loadouts.Slots[index]
	if not slot then
		self.Preview:SetOutfit(nil)
		return
	end

	-- The playermodel comes from whichever item in the set is one. An outfit without a
	-- playermodel previews on the body the player already has, which is what wearing it would
	-- actually look like.
	local model
	for _, entry in ipairs(slot.items or {}) do
		local ITEM = PS.Items[entry.id]
		if ITEM and ITEM.Model and not ITEM.Attachment and not ITEM.Bone and not ITEM.WeaponClass then
			model = ITEM.Model
		end
	end

	self.Preview:SetOutfit({
		model     = model,
		colour    = slot.colour and Color(slot.colour[1] or 255, slot.colour[2] or 255,
			slot.colour[3] or 255) or nil,
		useColor2 = slot.useColor2,
		items     = slot.items,
	})
end

-- ============================================================================
-- SLIDING OUT
-- ============================================================================

-- Comes out of whichever side of the shop has more room between it and the screen edge.
--
-- Measured at open rather than remembered: the shop is draggable and its position is restored
-- from the player's own file, so the roomier side is wherever they last left it.
-- A SIBLING OF THE SHOP, ORDERED BEHIND IT.
--
-- The shop is not a popup -- cl_init.lua creates it plainly and turns on the screen clicker --
-- so this panel and the shop are both top-level children of the base panel. Siblings, which is
-- what makes MoveToBack the right and sufficient answer: sibling order is the only thing it
-- sorts, and sibling order is the only thing that has to change.
--
-- Parenting was tried instead and cannot work, for a reason worth writing down. A child draws
-- after its parent, so it lands in FRONT; painting it manually from the parent puts it behind,
-- but a panel whose bounds have left its parent's rectangle is skipped before it is painted at
-- all, and that skip is applied to every descendant separately. The frame can be nudged back
-- into intersection. Its slot list and its preview cannot.
--
-- What parenting bought was travelling with a draggable window and dying with it. Both are
-- cheap to do directly: Think reads the shop's position every frame, and drops this panel when
-- the shop goes away.
function PANEL:Deploy(shop)
	if not IsValid(shop) then return end

	self.Shop = shop

	-- Newly created siblings go to the end of the list and therefore draw last, on top. Both
	-- halves are stated rather than trusting one: this goes back, and the shop comes forward.
	self:MoveToBack()
	shop:MoveToFront()

	local sx = shop:GetPos()
	local sw, sh = shop:GetSize()
	local w = self:GetWide()

	local toRight = (ScrW() - (sx + sw)) >= sx

	-- Offsets from the shop's own top-left, resolved to screen coordinates every frame.
	--
	-- Hidden sits inside the shop's footprint rather than against it, so there is nothing to see
	-- until it emerges -- that is what reads as coming out from underneath.
	self.Hidden = toRight and (sw - w) or 0
	self.Shown  = toRight and sw or -w

	self:SetTall(math.min(self:GetTall(), sh))

	self.OffsetX = self.Hidden
	self.TargetX = self.Shown

	self:Follow()
end

function PANEL:Follow()
	if not IsValid(self.Shop) then return end

	local sx, sy = self.Shop:GetPos()
	self:SetPos(sx + self.OffsetX, sy)
end

-- The slide is a lerp here rather than MoveTo because the destination moves. MoveTo animates
-- towards a fixed point, and the shop can be dragged mid-animation; easing the offset instead
-- means the panel is always measured from wherever the shop is right now.
function PANEL:Think()
	self.BaseClass.Think(self)

	if not IsValid(self.Shop) then
		self:Remove()
		return
	end

	if math.abs(self.OffsetX - self.TargetX) < 1 then
		self.OffsetX = self.TargetX
		if self.Retracting then
			self:Remove()
			return
		end
	else
		self.OffsetX = Lerp(FrameTime() * 14, self.OffsetX, self.TargetX)
	end

	self:Follow()
end

function PANEL:Retract()
	if not self.Shop then
		self:Remove()
		return
	end

	-- Slides home; Think removes it on arrival.
	self.Retracting = true
	self.TargetX = self.Hidden
end

vgui.Register("DPointShopLoadouts", PANEL, "DFrame")
