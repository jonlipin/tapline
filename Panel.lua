-- Tapline's two displays.
--
-- The readout is an ordinary frame this addon draws from health and mana, which it can read, so it
-- keeps working in a fight.
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
	if self.bars then self.bars:SetShown(p.bars ~= false) end

	local S = ns.state
	if S.hp and S.hpMax and S.hpMax > 0 then
		f.health:SetValue(S.hp / S.hpMax)
		f.health.text:SetText(("%d / %d   %d%%"):format(S.hp, S.hpMax, floor(S.hp / S.hpMax * 100 + 0.5)))
	else
		f.health:SetValue(0)
		-- The reason, not just the fact: which wall was hit is the whole of the useful answer here.
		f.health.text:SetText(S.hpWhy and ("health: " .. S.hpWhy) or "health unreadable")
	end
	if S.mp and S.mpMax and S.mpMax > 0 then
		f.mana:SetValue(S.mp / S.mpMax)
		f.mana.text:SetText(("%d / %d   %d%%"):format(S.mp, S.mpMax, floor(S.mp / S.mpMax * 100 + 0.5)))
	else
		f.mana:SetValue(0)
		f.mana.text:SetText(S.mpWhy and ("mana: " .. S.mpWhy) or "mana unreadable")
	end

	local key, reason, room = ns.Verdict()
	local v = VERDICTS[key] or VERDICTS.unknown
	f.verdict:SetText(v[1])
	f.verdict:SetTextColor(v[2], v[3], v[4])
	local cost = ns.Cost()
	f.room:SetText((room and room > 0 and cost) and ("%d x %d"):format(room, cost) or "")
	f.reason:SetText(reason or "")
	local kind, line = ns.Incoming()
	local c = INCOMING_COLORS[kind] or INCOMING_COLORS.none
	f.incoming:SetText(line or "")
	f.incoming:SetTextColor(c[1], c[2], c[3])

	if key == "tap" and S.verdict ~= "tap" and (p.sndReady or 0) > 0 then ns.PlaySound(p.sndReady) end
	S.verdict = key
end

-- ------------------------------------------------------------------
-- The bars the game draws
-- ------------------------------------------------------------------
-- The regions handed to one slot. The game owns when they are shown and what they say; we own only
-- what they look like and where they are.
-- Every call here is guarded on its own. One pcall round the lot was worse than useless: the slot
-- frame is the game's, resizing one is refused, and that single refusal threw away the icon, the
-- bar and the text with it, so the game fell back to drawing its own presentation wherever it
-- liked. The button is never resized now, and each handover stands or falls by itself. What the
-- game accepted is counted, so the report can say which of them this client allows.
ns.slotCalls = {}
local function Hand(button, method, ...)
	if not button[method] then ns.slotCalls[method] = "no such method" return false end
	local ok, err = pcall(button[method], button, ...)
	ns.slotCalls[method] = ok and "ok" or tostring(err):gsub("^.-%.lua:%d+:%s*", "")
	return ok
end

local function InitSlot(row)
	return function(button)
		if not button then return end
		pcall(function()
			local icon = button:CreateTexture(nil, "ARTWORK")
			icon:SetSize(CELL_H, CELL_H)
			icon:SetPoint("LEFT")
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			Hand(button, "SetIcon", icon)

			local bar = CreateFrame("StatusBar", nil, button)
			bar:SetSize(CELL_W - CELL_H - 3, CELL_H - 2)
			bar:SetPoint("LEFT", button, "LEFT", CELL_H + 3, 0)
			bar:SetStatusBarTexture(BAR_TEXTURE)
			bar:SetStatusBarColor(0.25, 0.75, 0.35)
			local bg = bar:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints(bar)
			-- Opaque: the cell underneath is still drawn, and a see-through fill lets its greyed
			-- out name read through the time the game is writing.
			bg:SetColorTexture(0, 0, 0, 1)
			Hand(button, "SetDurationBar", bar)

			local time = button:CreateFontString(nil, "OVERLAY")
			time:SetFont(FONT, 10, "OUTLINE")
			time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
			Hand(button, "SetDurationText", time)

			local name = button:CreateFontString(nil, "OVERLAY")
			name:SetFont(FONT, 10, "OUTLINE")
			name:SetPoint("LEFT", bar, "LEFT", 4, 0)
			if button.SetSpellName then Hand(button, "SetSpellName", name)
			else Hand(button, "SetNameText", name) end

			local count = button:CreateFontString(nil, "OVERLAY")
			count:SetFont(FONT, 9, "OUTLINE")
			count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
			Hand(button, "SetApplicationCount", count)
		end)
	end
end

-- A cell of our own under each slot, so an empty row still says which heal it is waiting for.
local function Cell(parent, row, index)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetSize(CELL_W, CELL_H)
	cell:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6 - (index - 1) * (CELL_H + 3))
	local icon = cell:CreateTexture(nil, "ARTWORK")
	icon:SetSize(CELL_H, CELL_H)
	icon:SetPoint("LEFT")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	-- By id, not by name. Asking for "Renew" by name gets a warlock nothing, because the client
	-- answers that question out of your own spellbook; any resolved rank has the icon on it.
	local tex
	local ids = ns.Ranks(row.name)
	if ids then
		for id in pairs(ids) do
			local _, t = ns.SpellInfo(id)
			if t then tex = t break end
		end
	end
	if not tex then local _, t = ns.SpellInfo(row.name) tex = t end
	icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
	icon:SetDesaturated(true)
	icon:SetAlpha(0.35)
	local label = cell:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, 10, "")
	label:SetPoint("LEFT", cell, "LEFT", CELL_H + 7, 0)
	label:SetTextColor(0.5, 0.48, 0.42)
	label:SetText(row.name)
	cell.icon, cell.label = icon, label
	return cell
end

-- Built out of combat only: the game refuses to make one of these in a fight, and refuses to let a
-- slot be re-pointed once it has been placed. Rebuilt when the ranks finish resolving, since a slot
-- is given ids and the set of ids it should hold changes as the client answers.
function Panel:BuildBars()
	local p = ns.Profile()
	if not p or p.bars == false then return end
	if InCombatLockdown and InCombatLockdown() then return end

	local want = {}
	for _, row in ipairs(ns.HOTS or {}) do
		local ids = ns.Ranks(row.name)
		if ids then
			local list = {}
			for id in pairs(ids) do list[#list + 1] = id end
			table.sort(list)
			want[row.name] = table.concat(list, ",")
		end
	end
	local key = ""
	for _, row in ipairs(ns.HOTS or {}) do key = key .. (want[row.name] or "-") .. ";" end
	if key == self.barKey then return end
	if key == ";;" or key:find("^[-;]*$") then
		ns.report["game-drawn bars"] = "no ranks resolved yet"
		return
	end

	local holder = self.bars
	if not holder then
		holder = Plate("TaplineBars")
		holder:SetSize(CELL_W + 12, #(ns.HOTS or {}) * (CELL_H + 3) + 9)
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
		self.cells = {}
		for i, row in ipairs(ns.HOTS or {}) do self.cells[i] = Cell(holder, row, i) end
		self:Place()
	end

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
				-- The slot frame is the game's; positioning is the only thing done to it, and even
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
	ns.report["game-drawn bars"] = ("%d of %d slots"):format(made, #(ns.HOTS or {}))
end

function Panel:Init()
	self:Build()
	self:BuildBars()
	self:Refresh(GetTime())
end
