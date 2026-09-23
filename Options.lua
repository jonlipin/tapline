-- Tapline's options.
--
-- These live in the game's own options window, under AddOns, as a canvas category: Blizzard hosts
-- a frame of ours and we draw it ourselves. That is the safe half of the settings API. The other
-- half, registering proxy settings so Blizzard stores the values for us, is what put this addon's
-- mark on Blizzard's own code on this client once before and had its nameplates throwing "attempt
-- to compare a secret number value". None of that is used here: every value is read from and
-- written to our own saved settings, and Blizzard is only lending the frame a home.
--
-- The same content doubles as a standalone window, for when the category cannot be registered or
-- the game's options panel will not open to it, which on this client it sometimes will not.
--
-- Every template goes through pcall with a plain fallback behind it, because Blizzard's FrameXML
-- is not on disk here and no template can be checked for before it is used.

local ADDON, ns = ...

local Options = {}
ns.Options = Options

local floor, max, min = math.floor, math.max, math.min
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local W, H = 620, 560
local COL = 286

local function Try(kind, name, parent, template)
	local ok, f = pcall(CreateFrame, kind, name, parent, template)
	if ok and f then return f, template end
	return CreateFrame(kind, name, parent), nil
end

local function Label(parent, text, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, size or 11, "")
	fs:SetText(text)
	fs:SetTextColor(r or 0.85, g or 0.82, b or 0.72)
	fs:SetJustifyH("LEFT")
	return fs
end

local function P() return ns.Profile() or {} end

-- Every control registers itself here so the whole page can be brought back into line whenever a
-- value changes behind it, from a slash command or from the other host.
function Options:Track(widget)
	self.rows = self.rows or {}
	self.rows[#self.rows + 1] = widget
	return widget
end

function Options:Heading(parent, x, y, text)
	local fs = Label(parent, text, 13, 1, 0.82, 0)
	fs:SetPoint("TOPLEFT", x, y)
	return y - 22
end

function Options:Note(parent, x, y, text)
	local fs = Label(parent, text, 10, 0.62, 0.60, 0.53)
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetWidth(COL)
	fs:SetJustifyH("LEFT")
	local lines = max(1, floor(#text / 46) + 1)
	return y - (12 * lines) - 6
end

function Options:Slider(parent, x, y, label, lo, hi, step, get, set, suffix)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("TOPLEFT", x, y)
	holder:SetSize(COL, 40)

	local text = Label(holder, label, 11)
	text:SetPoint("TOPLEFT", 0, 0)
	local value = Label(holder, "", 11, 1, 0.82, 0)
	value:SetPoint("TOPRIGHT", 0, 0)
	value:SetJustifyH("RIGHT")

	local slider
	for _, template in ipairs({ "MinimalSliderTemplate", "UISliderTemplate", "OptionsSliderTemplate" }) do
		local made = select(1, Try("Slider", nil, holder, template))
		if made and made.SetMinMaxValues then slider = made ns.report["slider template"] = template break end
	end
	if not slider then slider = CreateFrame("Slider", nil, holder) end
	slider:SetPoint("TOPLEFT", 0, -17)
	slider:SetSize(COL, 16)
	slider:SetOrientation("HORIZONTAL")
	pcall(slider.SetMinMaxValues, slider, lo, hi)
	pcall(slider.SetValueStep, slider, step)
	pcall(slider.SetObeyStepOnDrag, slider, true)
	if not slider:GetThumbTexture() then
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
		thumb:SetSize(20, 20)
		pcall(slider.SetThumbTexture, slider, thumb)
	end

	local function show(v)
		value:SetText((step < 1 and ("%.2f"):format(v) or tostring(floor(v + 0.5))) .. (suffix or ""))
	end
	slider:SetScript("OnValueChanged", function(self2, v)
		if self2.tlQuiet then return end
		if step >= 1 then v = floor(v + 0.5) end
		show(v)
		set(v)
	end)
	holder.Refresh = function()
		local v = get()
		slider.tlQuiet = true
		pcall(slider.SetValue, slider, v)
		slider.tlQuiet = nil
		show(v)
	end
	holder.Refresh()
	self:Track(holder)
	return y - 44
end

function Options:Check(parent, x, y, label, get, set)
	local box = select(1, Try("CheckButton", nil, parent, "UICheckButtonTemplate"))
	box:SetPoint("TOPLEFT", x - 2, y + 2)
	box:SetSize(24, 24)
	local text = Label(parent, label, 11)
	text:SetPoint("LEFT", box, "RIGHT", 4, 0)
	if box.SetChecked then
		box:SetScript("OnClick", function(self2) set(self2:GetChecked() and true or false) Options:Refresh() end)
		box.Refresh = function() box:SetChecked(get() and true or false) end
		box.Refresh()
		self:Track(box)
	end
	return y - 26
end

function Options:Button(parent, x, y, width, label, onClick)
	local b = select(1, Try("Button", nil, parent, "UIPanelButtonTemplate"))
	b:SetPoint("TOPLEFT", x, y)
	b:SetSize(width, 22)
	if b.SetText then b:SetText(label) else Label(b, label, 11):SetPoint("CENTER") end
	b:SetScript("OnClick", onClick)
	return b
end

-- The alert is picked from a row of numbered buttons rather than a dropdown. The list is short,
-- pressing one plays it, and the names are half guesswork against file ids, so hearing it is the
-- whole point. Files this client refuses are greyed out and cannot be picked.
function Options:Sounds(parent, x, y, label, key)
	local text = Label(parent, label, 11)
	text:SetPoint("TOPLEFT", x, y)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("TOPLEFT", x, y - 16)
	holder:SetSize(COL, 22)
	local buttons = {}
	local at = 0
	local function make(index, caption, width)
		local b = select(1, Try("Button", nil, holder, "UIPanelButtonTemplate"))
		b:SetPoint("LEFT", at, 0)
		b:SetSize(width, 20)
		if b.SetText then b:SetText(caption) end
		b:SetScript("OnClick", function()
			P()[key] = index
			if index > 0 then ns.PlaySound(index) end
			ns.SyncSounds()
			Options:Refresh()
		end)
		b:SetScript("OnEnter", function(self2)
			if not GameTooltip then return end
			GameTooltip:SetOwner(self2, "ANCHOR_TOP")
			local c = ns.SOUNDS[index]
			GameTooltip:SetText(index == 0 and "Silent" or (c and c[1] or "?"))
			if c and c.valid == false then GameTooltip:AddLine("This client will not accept this one", 1, 0.4, 0.3) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		buttons[index] = b
		at = at + width + 2
	end
	make(0, "off", 26)
	for i, c in ipairs(ns.SOUNDS or {}) do
		-- Only files the game can be handed are worth offering: those are the alerts that survive
		-- a fight, which is the only kind worth having here.
		if c[4] then make(i, tostring(i), 20) end
	end
	holder.Refresh = function()
		for index, b in pairs(buttons) do
			local c = ns.SOUNDS[index]
			local refused = c and c.valid == false
			local on = (P()[key] or 0) == index
			b:SetAlpha(refused and 0.25 or (on and 1 or 0.55))
			if b.SetEnabled then pcall(b.SetEnabled, b, not refused) end
		end
	end
	holder.Refresh()
	self:Track(holder)
	return y - 44
end

-- ------------------------------------------------------------------
-- The page
-- ------------------------------------------------------------------
function Options:Content()
	if self.content then return self.content end
	local c = CreateFrame("Frame", "TaplineOptionsContent", UIParent)
	c:SetSize(W, H)
	self.content = c
	self.rows = {}

	local y = -14
	local intro = Label(c, "Whether a heal is on you is secret to addons on this client, so the game draws these bars rather than Tapline, and keeps them right in a fight. The alert below is played by the game too.", 11, 0.7, 0.68, 0.6)
	intro:SetPoint("TOPLEFT", 16, y)
	intro:SetWidth(W - 32)
	intro:SetJustifyH("LEFT")
	y = y - 40

	local left, right = 16, 16 + COL + 24
	local ly, ry = y, y

	-- Left: the shape of things.
	ly = self:Heading(c, left, ly, "The heal bars")
	ly = self:Slider(c, left, ly, "Bar width", 120, 480, 5,
		function() return P().barW or 260 end,
		function(v) P().barW = v ns.Panel:Rebuild() end)
	ly = self:Slider(c, left, ly, "Bar height", 14, 56, 1,
		function() return P().barH or 28 end,
		function(v) P().barH = v ns.Panel:Rebuild() end)
	ly = self:Slider(c, left, ly, "Icon size", 0.5, 1.5, 0.05,
		function() return P().iconScale or 1 end,
		function(v) P().iconScale = v ns.Panel:Rebuild() end)
	ly = self:Slider(c, left, ly, "Gap between icon and bar", -40, 40, 1,
		function() return P().gapExtra or 0 end,
		function(v) P().gapExtra = v ns.Panel:Rebuild() end)
	ly = self:Slider(c, left, ly, "Gap between rows", -20, 30, 1,
		function() return P().rowGap or 4 end,
		function(v) P().rowGap = v ns.Panel:Rebuild() end)
	ly = self:Slider(c, left, ly, "Redraws a second", 5, 60, 1,
		function() return P().rate or 30 end,
		function(v) P().rate = v end)
	ly = self:Slider(c, left, ly, "Bar opacity", 0.1, 1, 0.05,
		function() return P().barAlpha or 1 end,
		function(v) P().barAlpha = v ns.Panel:Restyle() end)
	ly = self:Slider(c, left, ly, "Scale", 0.5, 2, 0.05,
		function() return P().scale or 1 end,
		function(v) P().scale = v ns.Panel:Place() end)

	ly = self:Slider(c, left, ly, "Bar background opacity", 0, 1, 0.05,
		function() return P().barBgAlpha or 0.85 end,
		function(v) P().barBgAlpha = v ns.Panel:Restyle() end)

	ly = self:Heading(c, left, ly - 8, "The box behind them")
	ly = self:Slider(c, left, ly, "Background opacity", 0, 1, 0.05,
		function() return P().bgAlpha or 0.9 end,
		function(v) P().bgAlpha = v ns.Panel:Restyle() end)
	ly = self:Slider(c, left, ly, "Border opacity", 0, 1, 0.05,
		function() return P().borderAlpha or 1 end,
		function(v) P().borderAlpha = v ns.Panel:Restyle() end)

	-- Right: what is shown and what is heard.
	ry = self:Heading(c, right, ry, "What to show")
	ry = self:Check(c, right, ry, "The heal bars", function() return P().bars ~= false end,
		function(v) P().bars = v if v then ns.Panel:Rebuild() end ns.Panel:Refresh(GetTime()) end)
	ry = self:Check(c, right, ry, "A button on the minimap", function() return P().minimap ~= false end,
		function(v) P().minimap = v if ns.MinimapButton then ns.MinimapButton:Refresh() end end)
	ry = self:Check(c, right, ry, "Preview: run the bars on a made-up timer", function() return P().test end,
		function(v) P().test = v ns.Panel:Refresh(GetTime()) end)
	ly = self:Slider(c, left, ly, "Spark size", 0.5, 4, 0.1,
		function() return P().sparkScale or 1.6 end,
		function(v) P().sparkScale = v ns.Panel:Rebuild() end)
	ry = self:Check(c, right, ry, "A spark at the end of the fill",
		function() return P().spark ~= false end,
		function(v) P().spark = v ns.Panel:Rebuild() end)
	ry = self:Check(c, right, ry, "Always draw a frame round the bar",
		function() return P().edge == "always" end,
		function(v) P().edge = v and "always" or "auto" ns.Panel:Rebuild() end)
	ry = self:Check(c, right, ry, "Plain bars: skip the copied Cooldown Manager art", function() return P().plain end,
		function(v) P().plain = v ns.Panel:Rebuild() end)

	ry = self:Heading(c, right, ry - 8, "Alerts")
	ry = self:Note(c, right, ry, "These are played by the game itself, so they work in combat, where this addon cannot see an aura at all.")
	ry = self:Check(c, right, ry, "Make a noise when a heal lands", function() return P().soundOn ~= false end,
		function(v) P().soundOn = v ns.SyncSounds() end)
	ry = self:Sounds(c, right, ry, "When a heal lands on you", "sndApplied")
	ry = self:Sounds(c, right, ry, "When one runs out", "sndLapsed")
	ry = self:Note(c, right, ry, "Press a number to hear it. Greyed out means this client refuses that file.")

	local bottom = min(ly, ry) - 8
	self:Button(c, left, bottom, 120, "Reset layout", function()
		local p = P()
		p.x, p.y, p.barX, p.barY = nil, nil, nil, nil
		p.scale = 1
		ns.Panel:Place()
		Options:Refresh()
	end)
	self:Button(c, left + 130, bottom, 120, "Play them all", function() ns.SoundTry() end)
	self:Button(c, right, bottom, 120, "Self report", function() ns.Debug() end)

	ns.report["options"] = "ok"
	return c
end

function Options:Refresh()
	for _, row in ipairs(self.rows or {}) do
		if row.Refresh then pcall(row.Refresh) end
	end
end

-- ------------------------------------------------------------------
-- Living in the game's own options window
-- ------------------------------------------------------------------
-- A canvas category only: Blizzard hosts the frame and we draw it. No proxy settings, which is the
-- part that taints.
function Options:RegisterBlizzard()
	if self.category ~= nil then return self.category end
	self.category = false
	local canvas = CreateFrame("Frame", "TaplineOptionsCanvas", UIParent)
	canvas.name = "Tapline"
	local content = self:Content()
	content:SetParent(canvas)
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
	content:Show()
	self.canvas = canvas

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, canvas, "Tapline")
		if ok and category then
			category.ID = category.ID or "Tapline"
			local okAdd = pcall(Settings.RegisterAddOnCategory, category)
			if okAdd then
				self.category = category
				ns.report["game options page"] = "registered"
				return category
			end
		end
		ns.report["game options page"] = "the game refused the category: " .. tostring(category)
	elseif InterfaceOptions_AddCategory then
		local ok = pcall(InterfaceOptions_AddCategory, canvas)
		ns.report["game options page"] = ok and "registered the old way" or "the old way was refused too"
		if ok then self.category = canvas return canvas end
	else
		ns.report["game options page"] = "this client has no settings API to register with"
	end
	return self.category
end

-- Opens the game's page when it will, and our own window when it will not. The game's panel is
-- asked to open and then CHECKED, because on this client it opens reliably once and then stops.
function Options:Toggle()
	self:Content()
	if self.category and Settings and Settings.OpenToCategory then
		local id = (type(self.category) == "table" and (self.category.GetID and self.category:GetID() or self.category.ID)) or "Tapline"
		local ok = pcall(Settings.OpenToCategory, id)
		local shown = ok and SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown()
		if shown then
			ns.report["options opened"] = "the game's own window"
			self:Refresh()
			return true
		end
		ns.report["options opened"] = "the game's window would not open, so a window of ours"
	end
	return self:Window()
end

-- Our own window, which is also where the page goes when the game will not host it.
function Options:Window()
	local f = self.frame
	if not f then
		local made, template = Try("Frame", "TaplineOptions", UIParent, "ButtonFrameTemplate")
		if not template then made = select(1, Try("Frame", "TaplineOptions", UIParent, "BasicFrameTemplate")) end
		f = made
		ns.report["options frame"] = template or "plain"
		f:SetSize(W + 24, H + 40)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f:SetClampedToScreen(true)
		if f.TitleText then f.TitleText:SetText("Tapline") end
		if f.SetTitle then pcall(f.SetTitle, f, "Tapline") end
		if not f.CloseButton then
			local close = select(1, Try("Button", nil, f, "UIPanelCloseButton"))
			close:SetPoint("TOPRIGHT", -4, -4)
			close:SetSize(24, 24)
			close:SetScript("OnClick", function() f:Hide() end)
		end
		tinsert(UISpecialFrames, "TaplineOptions")
		f:Hide()
		self.frame = f
	end
	if f:IsShown() then f:Hide() return false end
	-- The page can only be in one place at a time, so it is borrowed back from the canvas.
	local content = self:Content()
	content:SetParent(f.Inset or f)
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", 4, -4)
	content:Show()
	self:Refresh()
	f:Show()
	return true
end
