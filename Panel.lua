-- Tapline's two displays.
--
-- The readout is an ordinary frame this addon draws. On this client it is usually the smaller half
-- of the display, because health and mana come back secret here and there is nothing to compute:
-- it then shows what a tap costs, what is heading your way, and gets out of the way.
--
-- The bars underneath are not ours. Each one is a slot the GAME fills: it is handed the spell ids
-- of every rank of one heal, and it draws that aura into regions we give it, staying right in
-- combat where no addon may look at an aura. Nothing comes back from it. The slot frame is a
-- forbidden object, so it is only ever positioned, and even that goes through pcall. What it shows
-- is for your eyes, not for this addon's arithmetic, which is exactly why it is worth having: it is
-- the one display here that cannot be wrong.

local ADDON, ns = ...

local Panel = {}
ns.Panel = Panel

local floor, max, min = math.floor, math.max, math.min
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local W, BAR_W, BAR_H = 216, 200, 13
local CELL_W, CELL_H = 200, 18

local function Backdrop(f)
	if not f.SetBackdrop then return false end
	f:SetBackdrop(BACKDROP)
	f:SetBackdropColor(0.05, 0.03, 0.02, 0.9)
	f:SetBackdropBorderColor(0.6, 0.5, 0.35, 1)
	return true
end

local function Plate(name, parent)
	local ok, f = pcall(CreateFrame, "Frame", name, parent or UIParent, "BackdropTemplate")
	if not ok or not f then f = CreateFrame("Frame", name, parent or UIParent) end
	Backdrop(f)
	return f
end

-- Dragging: both displays move the same way, and both remember where they were put.
local function MakeMovable(f, saveX, saveY)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p = ns.Profile()
		if p and self:GetLeft() then p[saveX], p[saveY] = self:GetLeft(), self:GetTop() end
	end)
end

function Panel:Restyle()
	local p, holder = ns.Profile(), self.bars
	if not p then return end
	local shade = tonumber(p.barBgAlpha) or 0.85
	for _, plate in ipairs(self.plates or {}) do pcall(plate.SetColorTexture, plate, 0, 0, 0, shade) end
	if not holder then return end
	holder:SetAlpha(tonumber(p.barAlpha) or 1)
	if holder.SetBackdropColor then
		pcall(holder.SetBackdropColor, holder, 0.05, 0.03, 0.02, tonumber(p.bgAlpha) or 0.9)
		pcall(holder.SetBackdropBorderColor, holder, 0.6, 0.5, 0.35, tonumber(p.borderAlpha) or 1)
	end
end

-- A size or an icon changed, so the rows have to be made again: a slot the game has placed
-- cannot be resized afterwards.
function Panel:Rebuild()
	if InCombatLockdown and InCombatLockdown() then
		self.rebuildWanted = true
		return false
	end
	self.rebuildWanted = nil
	self.barKey, self.container, self.cells, self.plates = nil, nil, nil, nil
	if self.bars then self.bars:Hide() self.bars = nil end
	self:BuildBars()
	self:Refresh(GetTime())
	return true
end

function Panel:Place()
	local p, bars = ns.Profile(), self.bars
	if not p or not bars then return end
	bars:ClearAllPoints()
	if p.barX and p.barY then
		bars:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.barX, p.barY)
	else
		bars:SetPoint("CENTER", UIParent, "CENTER", -260, -120)
	end
	bars:SetScale(p.scale or 1)
	self:Restyle()
end

function Panel:Refresh(now)
	ns.state.stats.refresh = (ns.state.stats.refresh or 0) + 1
	self:RefreshBars(now or GetTime())
end

-- ------------------------------------------------------------------
-- The heal bars
-- ------------------------------------------------------------------
-- Each row is two bars in the same place. Underneath is one of ours, dim and empty, naming the
-- heal it is waiting for and showing a countdown when you are previewing the layout. Over it sits
-- a slot the GAME fills, which is the only thing on this client that can follow an aura through a
-- fight. When a heal is on you, the game's row covers ours entirely; when it is not, the game
-- hides its row and ours shows through. Both wear the same art, so the swap is invisible.
--
-- Every handover to a slot is guarded on its own. One pcall round the lot was worse than useless:
-- the slot frame is the game's, resizing one is refused, and that single refusal threw away the
-- icon, the bar and the text with it, so the game fell back to drawing its own presentation
-- wherever it liked. The button is never resized now. What the game accepted is counted, so the
-- report can say which handovers this client allows.
ns.slotCalls = {}
local function Hand(button, method, ...)
	if not button[method] then ns.slotCalls[method] = "no such method" return false end
	local ok, err = pcall(button[method], button, ...)
	ns.slotCalls[method] = ok and "ok" or tostring(err):gsub("^.-%.lua:%d+:%s*", "")
	return ok
end

-- Everything about the shape of one row, worked out in one place so the cell, the slot the game
-- draws over it and the box around them can never disagree about how much room the icon takes.
--
-- The icon is not just the picture. The frame drawn around it reaches past the artwork on every
-- side, and by a share of the icon rather than a fixed number of pixels, so it reaches further
-- the bigger the icon gets. A gap of a few pixels is fine at the default size and is run straight
-- over at half again, which is the overlap this fixes: the gap grows with the icon, and the row
-- grows tall enough to hold it so neighbouring rows are not run into either.
-- Measured off the manager: the frame round an icon is not square, reaching further across than
-- it does down. Both are shares of the icon, so both grow with it.
local ICON_OVERHANG_X, ICON_OVERHANG_Y = 0.200, 0.175

function Panel:RowMetrics()
	local p = ns.Profile() or {}
	local h = max(12, min(64, tonumber(p.barH) or 28))
	local w = max(80, min(600, tonumber(p.barW) or 260))
	local iconSize = max(8, floor(h * (tonumber(p.iconScale) or 1) + 0.5))
	local overhang = floor(iconSize * ICON_OVERHANG_X + 0.5)
	local overhangY = floor(iconSize * ICON_OVERHANG_Y + 0.5)
	-- The frame round an icon reaches past the picture, so by default the bar starts clear of it.
	-- The setting adds to that or takes from it, down to nothing at all: pulled all the way in,
	-- the bar begins where the picture ends and the soft edge of the art laps over it, which is
	-- a fair thing to want and not this addon's business to forbid.
	local gap = max(0, overhang + 3 + floor(tonumber(p.gapExtra) or 0))
	-- What the bar starts at: the icon, plus the frame art on both sides of it, plus the gap.
	local barLeft = overhang + iconSize + gap
	local barW = max(8, w - barLeft - overhang)
	-- As tall as the taller of the bar and the icon, and no taller. Counting the frame art in
	-- here too padded every row by a tenth of the icon whatever the gap was set to, so winding
	-- the gap down to nothing still left the rows far apart. That art is a soft edge, and a
	-- little overlap between rows is what the manager itself does.
	local rowH = max(h, iconSize)
	-- Negative closes the rows up further, for a big icon that wants pulling together, but never
	-- so far that one row would sit entirely on top of the next.
	local pitch = max(8, rowH + floor(tonumber(p.rowGap) or 4))
	return { w = w, h = h, iconSize = iconSize, overhang = overhang, overhangY = overhangY, gap = gap,
		barLeft = barLeft, barW = barW, rowH = rowH, pitch = pitch }
end

function Panel:BarSize()
	local m = self:RowMetrics()
	return m.w, m.h
end

-- The pieces of one row, built straight onto the frame that will own them.
--
-- Straight onto it, with no frame of ours in between, because the slot the game fills is a
-- forbidden object and the regions it is handed have to be its own. A version that put them on an
-- intermediate frame looked identical offline and showed nothing at all in game.
--
-- The art goes on afterwards and inside a pcall of its own. Making the plate look like the
-- Cooldown Manager is worth doing, and it is worth exactly nothing if a refused call takes the bar
-- down with it: the worst this can do now is leave a plain bar that works.
local function Adorn(frame, m)
	local parts = {}
	local h = m.h

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(m.iconSize, m.iconSize)
	-- Inset by the frame art's reach, so the art stays inside the row rather than hanging off it.
	icon:SetPoint("LEFT", frame, "LEFT", m.overhang, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	parts.icon = icon

	local bar = CreateFrame("StatusBar", nil, frame)
	bar:SetSize(m.barW, h)
	bar:SetPoint("LEFT", frame, "LEFT", m.barLeft, 0)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar:SetStatusBarTexture(BAR_TEXTURE)
	bar:SetStatusBarColor(0.96, 0.55, 0.16)
	local plate = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	plate:SetAllPoints(bar)
	plate:SetColorTexture(0, 0, 0, tonumber((ns.Profile() or {}).barBgAlpha) or 0.85)
	-- Named, so the skin does not lay a second plate on top of this one, and remembered, so its
	-- shade can be changed later without rebuilding the rows the game owns.
	bar.tlPlate = plate
	Panel.plates = Panel.plates or {}
	Panel.plates[#Panel.plates + 1] = plate
	parts.bar = bar

	local size = max(9, floor(h * 0.42))
	local name = bar:CreateFontString(nil, "OVERLAY")
	name:SetFont(FONT, size, "OUTLINE")
	name:SetPoint("LEFT", bar, "LEFT", floor(h * 0.25), 0)
	name:SetJustifyH("LEFT")
	parts.name = name

	local time = bar:CreateFontString(nil, "OVERLAY")
	time:SetFont(FONT, size, "OUTLINE")
	time:SetPoint("RIGHT", bar, "RIGHT", -floor(h * 0.25), 0)
	time:SetJustifyH("RIGHT")
	parts.time = time

	local count = bar:CreateFontString(nil, "OVERLAY")
	count:SetFont(FONT, max(8, floor(size * 0.8)), "OUTLINE")
	count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
	parts.count = count

	-- Now the client's own art, if it will part with it, and never at the cost of the row.
	local p = ns.Profile()
	if p and p.plain then ns.report["bar art"] = "off, by /tapline plain" return parts end
	local ok, applied = pcall(function() return ns.Skin:Dress(bar, h, icon, name, time, m.iconSize) end)
	if not ok then
		ns.report["bar art"] = "refused: " .. tostring(applied):gsub("^.-%.lua:%d+:%s*", "")
	elseif applied then
		-- Only when the art actually went on. A refusal inside has already written its own reason,
		-- and overwriting it with the name of the skin we wanted hides exactly what went wrong.
		ns.report["bar art"] = ns.Skin.source or "applied"
	end
	return parts
end

-- What the game is handed for one heal. It owns when these are shown and what they say.
local function InitSlot(row)
	return function(button)
		if not button then return end
		local m = Panel:RowMetrics()
		-- Building the regions is one guarded step, since they are made on the game's own frame and
		-- a refusal there leaves nothing to hand over. Each handover is then guarded separately.
		local ok, parts = pcall(Adorn, button, m)
		ns.slotCalls["build the row"] = ok and "ok" or tostring(parts):gsub("^.-%.lua:%d+:%s*", "")
		if not ok or type(parts) ~= "table" then return end
		button.tlParts = parts
		Hand(button, "SetIcon", parts.icon)
		Hand(button, "SetDurationBar", parts.bar)
		Hand(button, "SetDurationText", parts.time)
		if button.SetSpellName then Hand(button, "SetSpellName", parts.name)
		else Hand(button, "SetNameText", parts.name) end
		Hand(button, "SetApplicationCount", parts.count)
	end
end

-- Our own row, under the game's. Dim and empty while nothing is on you, and running a made-up
-- countdown while you are previewing the layout.
local function Cell(parent, row, index)
	local m = Panel:RowMetrics()
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetSize(m.w, m.rowH)
	cell:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6 - (index - 1) * m.pitch)
	local parts = Adorn(cell, m)
	cell.icon, cell.bar, cell.name, cell.time, cell.count = parts.icon, parts.bar, parts.name, parts.time, parts.count

	-- By id, not by name. Asking for "Renew" by name gets a warlock nothing, because the client
	-- answers that question out of your own spellbook; any resolved rank carries the icon.
	local tex
	local ids = ns.Ranks(row.name)
	if ids then
		for id in pairs(ids) do
			local _, t = ns.SpellInfo(id)
			if t then tex = t break end
		end
	end
	if not tex then local _, t = ns.SpellInfo(row.name) tex = t end
	cell.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
	cell.name:SetText(row.name)
	cell.row = row
	return cell
end

function Panel:DressCell(cell, testing, now)
	local w, h = self:BarSize()
	if testing then
		-- A preview that moves, so the layout can be judged without waiting on a healer. The clock
		-- is the heal's own duration, so a test bar runs at the speed the real one will.
		local period = (cell.row and cell.row.duration) or 15
		local left = period - ((now + (cell.testOffset or 0)) % period)
		cell.bar:SetValue(left / period)
		cell.time:SetText(ns.BarTime(left))
		cell.icon:SetDesaturated(false)
		cell.icon:SetAlpha(1)
		cell.bar:SetAlpha(1)
		cell.name:SetTextColor(1, 1, 1)
		cell.time:SetTextColor(1, 1, 1)
	else
		cell.bar:SetValue(0)
		-- An empty bar has its fill squeezed to nothing at the left hand end, and the spark rides
		-- the end of the fill, so it would sit against the left edge looking like a mark on the
		-- plate. A spark belongs to a bar that is actually running.
		if cell.bar.tlSpark then cell.bar.tlSpark:Hide() end
		cell.time:SetText("")
		cell.icon:SetDesaturated(true)
		cell.icon:SetAlpha(0.35)
		cell.bar:SetAlpha(0.45)
		cell.name:SetAlpha(1)
		cell.time:SetAlpha(1)
		cell.name:SetTextColor(0.55, 0.53, 0.47)
	end
end

-- Built out of combat only: the game refuses to make a container in a fight, and refuses to let a
-- slot be re-pointed once placed. Rebuilt when the ranks finish resolving or the size changes,
-- since a slot is given ids and the set of ids it should hold changes as the client answers.
function Panel:BuildBars()
	local p = ns.Profile()
	if not p or p.bars == false then return end
	if InCombatLockdown and InCombatLockdown() then return end

	local m = self:RowMetrics()
	local w, h = m.w, m.h
	local key = ("%dx%dx%d|%d|%d|"):format(w, h, m.iconSize, m.gap, m.pitch)
	local any = false
	for _, row in ipairs(ns.HOTS or {}) do
		local ids = ns.Ranks(row.name)
		local list = {}
		if ids then for id in pairs(ids) do list[#list + 1] = id end end
		table.sort(list)
		if #list > 0 then any = true end
		key = key .. row.name .. "=" .. table.concat(list, ",") .. ";"
	end
	if key == self.barKey then return end
	if not any then
		ns.report["game-drawn bars"] = "no ranks resolved yet"
		return
	end

	-- The size changed, so the rows are rebuilt from scratch: a slot cannot be resized afterwards.
	if self.bars and self.barSize ~= key then
		for _, cell in ipairs(self.cells or {}) do cell:Hide() end
		self.cells = nil
	end

	local holder = self.bars
	if not holder then
		holder = Plate("TaplineBars")
		holder:SetFrameStrata("MEDIUM")
		holder:SetClampedToScreen(true)
		MakeMovable(holder, "barX", "barY")
		holder:SetScript("OnEnter", function(self2)
			if not GameTooltip then return end
			GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
			GameTooltip:SetText("Incoming heals")
			GameTooltip:AddLine("Drawn by the game, so it stays right in combat.", 1, 1, 1)
			GameTooltip:AddLine("Tapline cannot read these: they are for your eyes.", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		holder:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		self.bars = holder
	end
	holder:SetSize(w + 12, #(ns.HOTS or {}) * m.pitch + 8)
	if not self.cells then
		self.cells = {}
		for i, row in ipairs(ns.HOTS or {}) do
			-- One row that will not build must not cost the others, nor the slots under them.
			local okCell, made = pcall(Cell, holder, row, i)
			if okCell and made then
				made.testOffset = i * 3
				self.cells[i] = made
			else
				ns.report["row " .. row.name] = "refused: " .. tostring(made)
			end
		end
	end
	self.barSize = key
	self:Place()

	-- A container whose slots must change is thrown away and made again: the game gives no way to
	-- take a slot back out of one.
	if self.container then
		pcall(function() self.container:Hide() self.container:ClearAllPoints() end)
		self.container = nil
	end
	local ok, c = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not (ok and c) then
		ns.report["game-drawn bars"] = "AuraContainer refused: " .. tostring(c)
		return
	end
	c:SetAllPoints(holder)
	if c.SetUnit then pcall(c.SetUnit, c, "player") end
	c:Show()
	self.container = c

	local made = 0
	for i, row in ipairs(ns.HOTS or {}) do
		local ids = ns.Ranks(row.name)
		if ids then
			local okSlot, frame = pcall(c.AddAuraSlot, c, row.name, "HELPFUL", {
				initializeFrame = InitSlot(row),
				-- No isFromPlayerOrPlayerPet: the whole point is a heal somebody else cast on you.
				candidateFilters = { includeSpellIDs = ids },
			})
			if okSlot and frame then
				made = made + 1
				local cell = self.cells[i]
				-- The slot frame is the game's. Positioning is the only thing done to it, and even
				-- that is guarded, because reading anything off it is an error.
				pcall(function()
					frame:ClearAllPoints()
					frame:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
					frame:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 0, 0)
				end)
			else
				ns.report["game-drawn bars"] = "AddAuraSlot refused: " .. tostring(frame)
			end
		end
	end
	self.barKey = key
	ns.report["game-drawn bars"] = ("%d of %d slots, %dx%d, icon %d, gap %d"):format(
		made, #(ns.HOTS or {}), w, h, m.iconSize, m.gap)
end

function Panel:RefreshBars(now)
	ns.state.stats.barRefresh = (ns.state.stats.barRefresh or 0) + 1
	local p = ns.Profile()
	if not p or not self.bars then return end
	self.bars:SetShown(p.bars ~= false)
	local testing = p.test and true or false
	for _, cell in ipairs(self.cells or {}) do self:DressCell(cell, testing, now) end
end

function Panel:Init()
	self:BuildBars()
	self:Refresh(GetTime())
end
