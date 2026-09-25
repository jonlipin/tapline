-- Tapline's minimap button.
--
-- Its own, rather than LibDBIcon: this addon has no libraries and is not about to grow one for a
-- round button, and the same hand-rolled button has worked on this client before.
--
-- Nothing here goes near the heal bars. The art is all guarded, because textures that have existed
-- for twenty years are not guaranteed to render on this build: Interface\Buttons\* does not, which
-- is why the icon is an item icon and the ring is asked for by file id before it is used at all.

local ADDON, ns = ...

local Button = {}
ns.MinimapButton = Button

local floor, cos, sin, rad, deg = math.floor, math.cos, math.sin, math.rad, math.deg
-- The game runs an old Lua where math.atan2 exists; newer ones dropped it and take both
-- arguments on math.atan instead. Either is fine, as long as neither is assumed.
local atan2 = math.atan2 or math.atan
local ICON = "Interface\\Icons\\Spell_Shadow_BurningSpirit"
local RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- A texture path this client will not resolve draws nothing at all, and a button made of nothing
-- is indistinguishable from a button that failed to be made. Asked for first, used only if it is
-- really there, and what happened is reported either way.
local function Have(path)
	if not GetFileIDFromPath then return true end
	local ok, id = pcall(GetFileIDFromPath, path)
	return ok and id and true or false
end

-- Where the button sits: an angle around the minimap, which is how every other one works, so it
-- lands where the hand expects and can be dragged around the edge.
function Button:Place()
	local p, b = ns.Profile(), self.frame
	if not p or not b or not Minimap then return end
	local angle = rad(tonumber(p.minimapAngle) or 200)
	local okW, width = pcall(Minimap.GetWidth, Minimap)
	local radius = (okW and ns.Clean(width) or 140) / 2 + 5
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", cos(angle) * radius, sin(angle) * radius)
end

local function AngleFromCursor()
	if not (GetCursorPosition and Minimap) then return nil end
	local okC, cx, cy = pcall(GetCursorPosition)
	local okM, mx, my = pcall(Minimap.GetCenter, Minimap)
	local okS, scale = pcall(Minimap.GetEffectiveScale, Minimap)
	cx, cy, mx, my, scale = ns.Clean(cx), ns.Clean(cy), ns.Clean(mx), ns.Clean(my), ns.Clean(scale)
	if not (okC and okM and okS and cx and cy and mx and my and scale and scale ~= 0) then return nil end
	return deg(atan2(cy / scale - my, cx / scale - mx))
end

function Button:Build()
	if self.frame then return self.frame end
	if not Minimap then
		ns.report["minimap button"] = "this client has no Minimap frame"
		return nil
	end
	local b = CreateFrame("Button", "TaplineMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetMovable(true)

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(19, 19)
	icon:SetPoint("CENTER", 0, 1)
	-- Cropped square corners, so it reads as round inside the ring without needing a mask.
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.icon = icon

	local art = "icon only"
	if Have(RING) then
		local ring = b:CreateTexture(nil, "OVERLAY")
		ring:SetTexture(RING)
		ring:SetSize(53, 53)
		ring:SetPoint("TOPLEFT", 0, 0)
		b.ring = ring
		art = "icon and ring"
	else
		-- No ring to be had, so a plain dark disc behind the icon keeps it legible over the map.
		local back = b:CreateTexture(nil, "BACKGROUND")
		back:SetSize(25, 25)
		back:SetPoint("CENTER", icon, "CENTER", 0, 0)
		back:SetColorTexture(0, 0, 0, 0.6)
		b.back = back
	end
	if Have(HIGHLIGHT) then
		b:SetHighlightTexture(HIGHLIGHT)
	end
	ns.report["minimap button"] = art

	b:SetScript("OnDragStart", function(self2)
		self2.dragging = true
		self2:SetScript("OnUpdate", function()
			local a = AngleFromCursor()
			if a then
				local p = ns.Profile()
				if p then p.minimapAngle = a end
				Button:Place()
			end
		end)
	end)
	b:SetScript("OnDragStop", function(self2)
		self2.dragging = nil
		self2:SetScript("OnUpdate", nil)
		Button:Place()
	end)
	b:SetScript("OnClick", function(_, click)
		if click == "RightButton" then
			local p = ns.Profile()
			if p then
				p.bars = not (p.bars ~= false)
				if p.bars then ns.Panel:BuildBars() end
				ns.Panel:Refresh(GetTime())
				if ns.Options then ns.Options:Refresh() end
			end
		else
			ns.Options:Toggle()
		end
	end)
	b:SetScript("OnEnter", function(self2)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self2, "ANCHOR_LEFT")
		GameTooltip:SetText("Tapline")
		GameTooltip:AddLine("Left click: the options", 1, 1, 1)
		GameTooltip:AddLine("Right click: show or hide the heal bars", 1, 1, 1)
		GameTooltip:AddLine("Drag: move it around the minimap", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	self.frame = b
	self:Place()
	return b
end

function Button:Refresh()
	local p = ns.Profile()
	if not p then return end
	if p.minimap == false then
		if self.frame then self.frame:Hide() end
		return
	end
	local b = self:Build()
	if b then
		self:Place()
		b:Show()
	end
end
