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
	end
end

function Panel:Refresh(now)
	local p, f = ns.Profile(), self.frame
	if not p or not f then return end
	if not p.shown then f:Hide() if self.bars then self.bars:Hide() end return end
	f:Show()
	self:RefreshBars(now or GetTime())

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

function Panel:BarSize()
	local p = ns.Profile() or {}
	local h = max(12, min(64, tonumber(p.barH) or 28))
	local w = max(80, min(600, tonumber(p.barW) or 260))
	return w, h
end

-- The icon, the bar and the two fontstrings that make one row, dressed in the client's own art.
local function BuildRow(parent, w, h)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(w, h)

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(h, h)
	icon:SetPoint("LEFT")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetSize(max(8, w - h - 4), h)
	bar:SetPoint("LEFT", row, "LEFT", h + 4, 0)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	ns.Skin:Dress(bar, h, icon)

	local nameFont, nameSize, nameFlags = ns.SkinFont("nameFont", h)
	local name = bar:CreateFontString(nil, "OVERLAY")
	name:SetFont(nameFont, nameSize, nameFlags)
	name:SetPoint("LEFT", bar, "LEFT", floor(h * 0.25), 0)
	name:SetJustifyH("LEFT")

	local timeFont, timeSize, timeFlags = ns.SkinFont("durFont", h)
	local time = bar:CreateFontString(nil, "OVERLAY")
	time:SetFont(timeFont, timeSize, timeFlags)
	time:SetPoint("RIGHT", bar, "RIGHT", -floor(h * 0.25), 0)
	time:SetJustifyH("RIGHT")

	local count = bar:CreateFontString(nil, "OVERLAY")
	count:SetFont(timeFont, max(8, floor(timeSize * 0.8)), timeFlags)
	count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)

	row.icon, row.bar, row.name, row.time, row.count = icon, bar, name, time, count
	return row
end

-- What the game is handed for one heal. It owns when these are shown and what they say.
local function InitSlot(row)
	return function(button)
		if not button then return end
		pcall(function()
			local w, h = Panel:BarSize()
			local made = BuildRow(button, w, h)
			made:SetAllPoints(button)
			button.tlRow = made
			Hand(button, "SetIcon", made.icon)
			Hand(button, "SetDurationBar", made.bar)
			Hand(button, "SetDurationText", made.time)
			if button.SetSpellName then Hand(button, "SetSpellName", made.name)
			else Hand(button, "SetNameText", made.name) end
			Hand(button, "SetApplicationCount", made.count)
		end)
	end
end

-- Our own row, under the game's. Dim and empty while nothing is on you, and running a made-up
-- countdown while you are previewing the layout.
local function Cell(parent, row, index)
	local w, h = Panel:BarSize()
	local cell = BuildRow(parent, w, h)
	cell:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6 - (index - 1) * (h + 4))

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
		cell.time:SetText("")
		cell.icon:SetDesaturated(true)
		cell.icon:SetAlpha(0.35)
		cell.bar:SetAlpha(0.45)
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

	local w, h = self:BarSize()
	local key = ("%dx%d|"):format(w, h)
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
	if self.bars and self.barSize ~= w .. "x" .. h then
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
	holder:SetSize(w + 12, #(ns.HOTS or {}) * (h + 4) + 8)
	if not self.cells then
		self.cells = {}
		for i, row in ipairs(ns.HOTS or {}) do
			self.cells[i] = Cell(holder, row, i)
			self.cells[i].testOffset = i * 3
		end
	end
	self.barSize = w .. "x" .. h
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
	ns.report["game-drawn bars"] = ("%d of %d slots, %dx%d"):format(made, #(ns.HOTS or {}), w, h)
end

function Panel:RefreshBars(now)
	local p = ns.Profile()
	if not p or not self.bars then return end
	self.bars:SetShown(p.shown and p.bars ~= false)
	local testing = p.test and true or false
	for _, cell in ipairs(self.cells or {}) do self:DressCell(cell, testing, now) end
end

function Panel:Init()
	self:Build()
	self:BuildBars()
	self:Refresh(GetTime())
end
