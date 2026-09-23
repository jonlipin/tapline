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

local VERDICTS = {
	tap     = { "TAP",     0.25, 1.00, 0.30 },
	ok      = { "tap ok",  0.80, 0.85, 0.40 },
	wait    = { "WAIT",    1.00, 0.30, 0.25 },
	spare   = { "no need", 0.60, 0.60, 0.60 },
	unknown = { "?",       0.60, 0.60, 0.60 },
}
local INCOMING_COLORS = {
	read      = { 0.40, 1.00, 0.50 },
	estimated = { 0.55, 0.90, 1.00 },
	cast      = { 0.80, 0.80, 1.00 },
	none      = { 0.60, 0.58, 0.50 },
}

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

local function Bar(parent, r, g, b)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(BAR_W, BAR_H)
	bar:SetStatusBarTexture(BAR_TEXTURE)
	bar:SetStatusBarColor(r, g, b)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	bg:SetColorTexture(0, 0, 0, 0.7)
	local text = bar:CreateFontString(nil, "OVERLAY")
	text:SetFont(FONT, 10, "OUTLINE")
	text:SetPoint("CENTER")
	bar.text = text
	return bar
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

-- ------------------------------------------------------------------
-- The readout
-- ------------------------------------------------------------------
function Panel:Build()
	if self.frame then return self.frame end
	local f = Plate("TaplineFrame")
	f:SetSize(W, 118)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	MakeMovable(f, "x", "y")

	local title = f:CreateFontString(nil, "OVERLAY")
	title:SetFont(FONT, 11, "OUTLINE")
	title:SetPoint("TOPLEFT", 8, -7)
	title:SetText("|cffffd000Life Tap|r")

	f.health = Bar(f, 0.75, 0.15, 0.15)
	f.health:SetPoint("TOPLEFT", 8, -22)
	f.mana = Bar(f, 0.20, 0.35, 0.85)
	f.mana:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -3)

	f.verdict = f:CreateFontString(nil, "OVERLAY")
	f.verdict:SetFont(FONT, 18, "OUTLINE")
	f.verdict:SetPoint("TOPLEFT", f.mana, "BOTTOMLEFT", 0, -5)

	f.room = f:CreateFontString(nil, "OVERLAY")
	f.room:SetFont(FONT, 11, "OUTLINE")
	f.room:SetPoint("BOTTOMRIGHT", f.mana, "BOTTOMRIGHT", 0, -24)
	f.room:SetTextColor(0.85, 0.8, 0.65)

	f.reason = f:CreateFontString(nil, "OVERLAY")
	f.reason:SetFont(FONT, 10, "")
	f.reason:SetPoint("TOPLEFT", f.verdict, "BOTTOMLEFT", 0, -2)
	f.reason:SetWidth(BAR_W)
	f.reason:SetJustifyH("LEFT")
	f.reason:SetTextColor(0.75, 0.72, 0.62)

	f.incoming = f:CreateFontString(nil, "OVERLAY")
	f.incoming:SetFont(FONT, 10, "")
	f.incoming:SetPoint("TOPLEFT", f.reason, "BOTTOMLEFT", 0, -2)
	f.incoming:SetWidth(BAR_W)
	f.incoming:SetJustifyH("LEFT")

	-- A way to put it away without going looking for the options, since this window is the part
	-- of the addon that can say least on this client and is the most likely to be in the way.
	local okClose, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
	if okClose and close then
		close:SetPoint("TOPRIGHT", 2, 2)
		close:SetSize(22, 22)
	else
		close = CreateFrame("Button", nil, f)
		close:SetPoint("TOPRIGHT", -4, -4)
		close:SetSize(16, 16)
		local x = close:CreateFontString(nil, "OVERLAY")
		x:SetFont(FONT, 13, "OUTLINE")
		x:SetPoint("CENTER")
		x:SetText("x")
		x:SetTextColor(0.9, 0.8, 0.6)
	end
	close:SetScript("OnClick", function()
		local p = ns.Profile()
		if p then p.shown = false end
		Panel:Refresh(GetTime())
		if ns.Options then ns.Options:Refresh() end
		ns.Print("Readout hidden. /tapline show brings it back, or the tickbox in the options.")
	end)
	f.close = close

	f:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Tapline")
		GameTooltip:AddLine("Drag to move. /tapline for everything else.", 1, 1, 1)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	self.frame = f
	self:Place()
	ns.report["readout"] = "ok"
	return f
end

-- The box behind the rows, and how solid everything is. Kept apart from building them, so a
-- change of colour never costs a rebuild of the slots the game owns.
function Panel:Restyle()
	local p, holder = ns.Profile(), self.bars
	if not p or not holder then return end
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
	self.barKey, self.container, self.cells = nil, nil, nil
	if self.bars then self.bars:Hide() self.bars = nil end
	self:BuildBars()
	self:Refresh(GetTime())
	return true
end

function Panel:Place()
	local f, p = self.frame, ns.Profile()
	if not f or not p then return end
	f:ClearAllPoints()
	if p.x and p.y then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", -260, -120)
	end
	f:SetScale(p.scale or 1)
	f:SetAlpha(p.alpha or 1)
	local bars = self.bars
	if bars then
		bars:ClearAllPoints()
		if p.barX and p.barY then
			bars:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.barX, p.barY)
		else
			bars:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -6)
		end
		bars:SetScale(p.scale or 1)
		self:Restyle()
	end
end

function Panel:Refresh(now)
	ns.state.stats.refresh = (ns.state.stats.refresh or 0) + 1
	local p, f = ns.Profile(), self.frame
	if not p or not f then return end
	-- The readout and the bars are put away separately. They used to share one switch, which
	-- meant closing the window that can say least also took away the one thing that works.
	self:RefreshBars(now or GetTime())
	if not p.shown then f:Hide() return end
	f:Show()

	local S = ns.state
	-- When this client will not say what your health is, the readout says so once, quietly, and
	-- gets out of the way. A panel of error text sitting over the game is worse than no panel: the
	-- detail belongs in /tapline debug, and what is left here is what can still be shown.
	local blindVitals = not (S.hp and S.hpMax and S.hpMax > 0)
	if blindVitals ~= self.compact then
		self.compact = blindVitals
		f:SetHeight(blindVitals and 76 or 118)
		f.verdict:SetFont(FONT, blindVitals and 13 or 18, 'OUTLINE')
		f.health:SetShown(not blindVitals)
		f.mana:SetShown(not blindVitals)
		f.verdict:ClearAllPoints()
		f.verdict:SetPoint("TOPLEFT", blindVitals and f or f.mana, blindVitals and "TOPLEFT" or "BOTTOMLEFT",
			blindVitals and 8 or 0, blindVitals and -22 or -5)
	end

	if not blindVitals then
		f.health:SetValue(S.hp / S.hpMax)
		f.health.text:SetText(S.percentOnly and ("%d%%   (a percentage is all this client will give)"):format(S.hp)
			or ("%d / %d   %d%%"):format(S.hp, S.hpMax, floor(S.hp / S.hpMax * 100 + 0.5)))
		if S.mp and S.mpMax and S.mpMax > 0 then
			f.mana:SetValue(S.mp / S.mpMax)
			f.mana.text:SetText(("%d / %d   %d%%"):format(S.mp, S.mpMax, floor(S.mp / S.mpMax * 100 + 0.5)))
		else
			f.mana:SetValue(0)
			f.mana.text:SetText("mana is secret on this client")
		end
	end

	local key, reason, room = ns.Verdict()
	local cost = ns.Cost()
	if blindVitals then
		-- Nothing to decide with, so the panel stops pretending to decide. What it can still do is
		-- put a tap's cost against your maximum, which this client does hand over even though the
		-- current value is secret, and turn your floor into a number you can eye off your own bar.
		local hpMax = S.hpMaxApi
		if cost and hpMax and hpMax > 0 then
			f.verdict:SetText(("a tap costs %d of %d  (%d%%)"):format(cost, hpMax, floor(cost / hpMax * 100 + 0.5)))
			f.reason:SetText(("stay above %d health: only your own bar knows where you are"):format(
				floor(hpMax * (p.reserve or 25) / 100 + 0.5)))
		else
			f.verdict:SetText(cost and ("a tap costs %d"):format(cost) or "Life Tap")
			f.reason:SetText("your health is secret to addons here, so watch your own bar")
		end
		f.verdict:SetTextColor(0.85, 0.8, 0.6)
		f.room:SetText("")
	else
		local v = VERDICTS[key] or VERDICTS.unknown
		f.verdict:SetText(v[1])
		f.verdict:SetTextColor(v[2], v[3], v[4])
		f.room:SetText((room and room > 0 and cost) and ("%d x %d"):format(room, cost) or "")
		f.reason:SetText(reason or "")
	end
	local kind, line = ns.Incoming()
	local c = INCOMING_COLORS[kind] or INCOMING_COLORS.none
	f.incoming:SetText(line or "")
	f.incoming:SetTextColor(c[1], c[2], c[3])

	if key == "tap" and S.verdict ~= "tap" and (p.sndReady or 0) > 0 then ns.PlaySound(p.sndReady) end
	S.verdict = key
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
	-- Whatever room is asked for is added to the least that avoids an overlap, never instead of
	-- it, so the slider cannot put the bar back under the icon's frame however it is set.
	local gap = overhang + 3 + max(0, floor(tonumber(p.gapExtra) or 0))
	-- What the bar starts at: the icon, plus the frame art on both sides of it, plus the gap.
	local barLeft = overhang + iconSize + gap
	local barW = max(8, w - barLeft - overhang)
	-- A row is as tall as the taller of the bar and the icon, and no taller. The frame art round
	-- an icon was being counted in here too, which quietly padded every row by a tenth of the icon
	-- whatever the gap slider was set to, so winding the gap to nothing still left rows far apart.
	-- That art is a soft edge and a little overlap between rows is what the manager itself does, so
	-- how close rows sit is left entirely to the setting below.
	local rowH = max(h, iconSize)
	-- Negative closes rows up further, for a big icon that wants pulling together. Never past the
	-- point where one row would sit entirely on top of the next.
	local pitch = max(8, rowH + floor(tonumber(p.rowGap) or 4))
	return { w = w, h = h, iconSize = iconSize, overhang = overhang, overhangY = overhangY, gap = gap,
		barLeft = barLeft, barW = barW, rowH = rowH, pitch = pitch }
end

-- The rows to draw.
--
-- Usually one per heal. But what a warlock actually needs to know is whether anything at all is
-- ticking on them, not which of three spells it is, and for that one row is better than three:
-- one slot given every heal's spell ids shows whichever of them is on you, with its own icon,
-- its own name and its own countdown, and shows nothing when none is. It needs no guess about
-- how the game shares auras between slots, which is the one soft spot in packing rows together.
function Panel:Rows()
	local p = ns.Profile() or {}
	if p.single then
		local longest = 15
		for _, row in ipairs(ns.HOTS or {}) do
			if row.duration > longest then longest = row.duration end
		end
		return { { name = "Heal over time", duration = longest, any = true } }
	end
	return ns.HOTS or {}
end

-- Every spell id of every heal, for the rows that will take any of them.
function Panel:AllHealIds()
	local all = {}
	for _, row in ipairs(ns.HOTS or {}) do
		local ids = ns.Ranks(row.name)
		if ids then for id in pairs(ids) do all[id] = true end end
	end
	return next(all) and all or nil
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
	plate:SetColorTexture(0, 0, 0, 0.85)
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
	if (ns.Profile() or {}).growth == "up" then
		cell:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 6, 4 + (index - 1) * m.pitch)
	else
		cell:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6 - (index - 1) * m.pitch)
	end
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
	if row.any then
		-- It stands for all of them, so it wears the first one this client has art for, and the
		-- game writes the real name over it the moment a heal actually lands.
		for _, other in ipairs(ns.HOTS or {}) do
			local otherIds = ns.Ranks(other.name)
			if otherIds and not tex then
				for id in pairs(otherIds) do
					local _, t = ns.SpellInfo(id)
					if t then tex = t break end
				end
			end
		end
		cell.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
		cell.name:SetText(row.name)
	elseif (ns.Profile() or {}).collapse then
		-- Any heal can land in any row now, so the row underneath cannot honestly name one.
		cell.icon:SetTexture(nil)
		cell.name:SetText("")
	else
		cell.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
		cell.name:SetText(row.name)
	end
	cell.row = row
	return cell
end

-- How a row looks with a heal on it, and how it looks without one. Kept apart because the
-- preview needs both, one after the other.
local function ActiveLook(cell, left, period)
	cell:SetAlpha(1)
	cell.bar:SetValue(period > 0 and (left / period) or 0)
	cell.time:SetText(ns.BarTime(left))
	cell.icon:SetDesaturated(false)
	cell.icon:SetAlpha(1)
	cell.bar:SetAlpha(1)
	cell.name:SetAlpha(1)
	cell.time:SetAlpha(1)
	cell.name:SetTextColor(1, 1, 1)
	cell.name:SetText(cell.row and cell.row.name or "")
	cell.testActive = true
end

local function EmptyLook(cell)
	local p = ns.Profile() or {}
	cell.bar:SetValue(0)
	cell.time:SetText("")
	cell.icon:SetDesaturated(true)
	cell.icon:SetAlpha(0.35)
	cell.bar:SetAlpha(0.45)
	cell.name:SetAlpha(1)
	cell.time:SetAlpha(1)
	cell.name:SetTextColor(0.55, 0.53, 0.47)
	-- Fading the icon, the bar and the two labels was not enough: the frame art, the plate and
	-- the icon's shadow are put on by the skin and belong to the row, not to those four, so they
	-- stayed behind as empty squares. The row itself is what goes, which takes everything on it
	-- with it, and still leaves the game's own row, which is not a child of it, free to show.
	cell:SetAlpha(p.onlyActive and 0 or 1)
	cell.testActive = false
end

-- How long a previewed heal stays gone before it comes back.
local PREVIEW_REST = 5

function Panel:DressCell(cell, testing, now)
	if not testing then EmptyLook(cell) return end
	-- A preview that only ever showed full rows was no use for judging a layout that changes
	-- shape: which way it grows, whether it packs together and what "only what is on you" really
	-- looks like are all about rows going away. So a previewed heal runs its real length, falls
	-- off, and comes back, and the rows are offset from each other so they do not do it in step.
	local dur = (cell.row and cell.row.duration) or 15
	local period = dur + PREVIEW_REST
	local t = (now + (cell.testOffset or 0)) % period
	if t < dur then ActiveLook(cell, dur - t, dur) else EmptyLook(cell) end
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
	local key = ("%dx%dx%d|%s|%s|%s|%d|"):format(w, h, m.iconSize,
		tostring(p.growth), tostring(p.collapse), tostring(p.single), m.pitch)
	local rows = self:Rows()
	local any = false
	for _, row in ipairs(rows) do
		local ids = row.any and self:AllHealIds() or ns.Ranks(row.name)
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
	holder:SetSize(w + 12, #rows * m.pitch + 8)
	if not self.cells then
		self.cells = {}
		for i, row in ipairs(rows) do
			-- One row that will not build must not cost the others, nor the slots under them.
			local okCell, made = pcall(Cell, holder, row, i)
			if okCell and made then
				made.testOffset = i * 5
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

	-- Packed together, every slot is offered every heal, so the game fills them from the front
	-- and what is on you sits at the top with no holes. Which slot a heal lands in is the
	-- game's to decide: this addon cannot see which of them are filled, so it cannot pack them
	-- itself. That is the whole reason this is done by handing the game a wider list rather
	-- than by moving anything.
	local everything
	if p.collapse or p.single then
		everything = self:AllHealIds()
	end
	local made = 0
	for i, row in ipairs(rows) do
		local ids = everything or ns.Ranks(row.name)
		if ids then
			local okSlot, frame = pcall(c.AddAuraSlot, c, everything and ("row" .. i) or row.name, "HELPFUL", {
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
	ns.report["game-drawn bars"] = ("%d of %d slots, %dx%d, icon %d, gap %d%s"):format(
		made, #rows, w, h, m.iconSize, m.gap, p.single and ", one row for any heal" or "")
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
	self:Build()
	self:BuildBars()
	self:Refresh(GetTime())
end
