-- Tapline's options window.
--
-- Built out of the client's own widget templates so it reads as part of the game, but it is our
-- own frame rather than a page in Blizzard's settings. That is deliberate: on this client,
-- registering proxy settings or opening the settings panel from addon code puts this addon's mark
-- on Blizzard's, and the game then starts refusing its own reads. A window of our own costs a
-- little art and risks nothing.
--
-- Every template is tried through pcall with a plain fallback behind it, because Blizzard's
-- FrameXML is not on disk here and no template can be checked for before it is used.

local ADDON, ns = ...

local Options = {}
ns.Options = Options

local floor, max, min = math.floor, math.max, math.min
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local W, H = 360, 520
local ROW = 26

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

-- A slider, which is what this user wants for anything numeric.
function Options:Slider(parent, y, label, lo, hi, step, get, set, suffix)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("TOPLEFT", 16, y)
	holder:SetSize(W - 48, ROW + 16)

	local text = Label(holder, label, 11)
	text:SetPoint("TOPLEFT", 0, 0)
	local value = Label(holder, "", 11, 1, 0.82, 0)
	value:SetPoint("TOPRIGHT", 0, 0)

	local slider
	for _, template in ipairs({ "MinimalSliderTemplate", "UISliderTemplate", "OptionsSliderTemplate" }) do
		local made = select(1, Try("Slider", nil, holder, template))
		if made and made.SetMinMaxValues then slider = made ns.report["slider template"] = template break end
	end
	if not slider then slider = CreateFrame("Slider", nil, holder) end
	slider:SetPoint("TOPLEFT", 0, -16)
	slider:SetSize(W - 48, 16)
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
		value:SetText(tostring(step < 1 and ("%.1f"):format(v) or floor(v + 0.5)) .. (suffix or ""))
	end
	slider.tlShow = show
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
	self.rows[#self.rows + 1] = holder
	return holder, y - (ROW + 20)
end

function Options:Check(parent, y, label, get, set)
	local box = select(1, Try("CheckButton", nil, parent, "UICheckButtonTemplate"))
	box:SetPoint("TOPLEFT", 14, y)
	box:SetSize(24, 24)
	if not box.SetChecked then return parent, y - ROW end
	local text = Label(parent, label, 11)
	text:SetPoint("LEFT", box, "RIGHT", 4, 0)
	box:SetScript("OnClick", function(self2) set(self2:GetChecked() and true or false) end)
	box.Refresh = function() box:SetChecked(get() and true or false) end
	box.Refresh()
	self.rows[#self.rows + 1] = box
	return box, y - ROW
end

function Options:Button(parent, y, x, width, label, onClick)
	local b = select(1, Try("Button", nil, parent, "UIPanelButtonTemplate"))
	b:SetPoint("TOPLEFT", x, y)
	b:SetSize(width, 22)
	if b.SetText then b:SetText(label) else Label(b, label, 11):SetPoint("CENTER") end
	b:SetScript("OnClick", onClick)
	return b
end

-- The sound pickers are a row of small numbered buttons rather than a dropdown: the list is short,
-- every press plays the sound, and the names here are half guesswork, so hearing one is the point.
function Options:Sounds(parent, y, label, key)
	local text = Label(parent, label, 11)
	text:SetPoint("TOPLEFT", 16, y)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("TOPLEFT", 16, y - 16)
	holder:SetSize(W - 32, 22)
	local buttons = {}
	local x = 0
	local function make(index, caption, width)
		local b = select(1, Try("Button", nil, holder, "UIPanelButtonTemplate"))
		b:SetPoint("LEFT", x, 0)
		b:SetSize(width, 20)
		if b.SetText then b:SetText(caption) end
		b:SetScript("OnClick", function()
			local p = ns.Profile()
			p[key] = index
			if index > 0 then ns.PlaySound(index) end
			ns.SyncSounds()
			Options:Refresh()
		end)
		b:SetScript("OnEnter", function(self2)
			if not GameTooltip then return end
			GameTooltip:SetOwner(self2, "ANCHOR_TOP")
			local c = ns.SOUNDS[index]
			GameTooltip:SetText(index == 0 and "Silent" or (c and c[1] or "?"))
			if c and not c[4] then GameTooltip:AddLine("Cannot be played in combat", 1, 0.5, 0.3) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		buttons[index] = b
		x = x + width + 2
	end
	make(0, "off", 26)
	for i, c in ipairs(ns.SOUNDS or {}) do
		-- Only the ones with a file behind them can be handed to the game, and those are the only
		-- ones worth offering for an alert that has to survive a fight.
		if c[4] then make(i, tostring(i), 20) end
	end
	holder.Refresh = function()
		local p = ns.Profile()
		for index, b in pairs(buttons) do
			local on = (p[key] or 0) == index
			if b.SetNormalFontObject and on then pcall(b.SetNormalFontObject, b, "GameFontHighlight") end
			b:SetAlpha(on and 1 or 0.55)
		end
	end
	holder.Refresh()
	self.rows[#self.rows + 1] = holder
	return holder, y - 44
end

function Options:Build()
	if self.frame then return self.frame end
	self.rows = {}
	local f, template = Try("Frame", "TaplineOptions", UIParent, "ButtonFrameTemplate")
	if not template then
		f = select(1, Try("Frame", "TaplineOptions", UIParent, "BasicFrameTemplate"))
	end
	ns.report["options frame"] = template or "plain"
	f:SetSize(W, H)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	f:Hide()
	if f.TitleText then f.TitleText:SetText("Tapline") end
	if f.SetTitle then pcall(f.SetTitle, f, "Tapline") end
	if not f.TitleText and not f.SetTitle then
		local t = Label(f, "Tapline", 14, 1, 0.82, 0)
		t:SetPoint("TOP", 0, -8)
	end
	if not f.CloseButton then
		local close = select(1, Try("Button", nil, f, "UIPanelCloseButton"))
		close:SetPoint("TOPRIGHT", -4, -4)
		close:SetSize(24, 24)
		close:SetScript("OnClick", function() f:Hide() end)
	end
	tinsert(UISpecialFrames, "TaplineOptions")

	local body = f.Inset or f
	local y = -12
	local p = ns.Profile()

	local intro = Label(body, "Your health is secret to addons on this client, so the bars are the answer: the game draws them and keeps them right in a fight.", 10, 0.65, 0.63, 0.56)
	intro:SetPoint("TOPLEFT", 16, y)
	intro:SetWidth(W - 48)
	intro:SetJustifyH("LEFT")
	y = y - 34

	local _
	_, y = self:Check(body, y, "Show the readout", function() return ns.Profile().shown end,
		function(v) ns.Profile().shown = v ns.Panel:Refresh(GetTime()) end)
	_, y = self:Check(body, y, "Show the heal bars", function() return ns.Profile().bars ~= false end,
		function(v) ns.Profile().bars = v if v then ns.Panel:BuildBars() end ns.Panel:Refresh(GetTime()) end)
	_, y = self:Check(body, y, "Preview: run the bars on a made-up timer", function() return ns.Profile().test end,
		function(v) ns.Profile().test = v ns.Panel:Refresh(GetTime()) end)
	y = y - 6

	_, y = self:Slider(body, y, "Bar width", 120, 480, 5,
		function() return ns.Profile().barW or 260 end,
		function(v) ns.Profile().barW = v ns.Panel:BuildBars() end)
	_, y = self:Slider(body, y, "Bar height", 14, 56, 1,
		function() return ns.Profile().barH or 28 end,
		function(v) ns.Profile().barH = v ns.Panel:BuildBars() end)
	_, y = self:Slider(body, y, "Scale", 0.5, 2, 0.05,
		function() return ns.Profile().scale or 1 end,
		function(v) ns.Profile().scale = v ns.Panel:Place() end)
	_, y = self:Slider(body, y, "Health to keep back", 0, 90, 5,
		function() return ns.Profile().reserve or 25 end,
		function(v) ns.Profile().reserve = v end, "%")

	_, y = self:Sounds(body, y, "When a heal lands on you (played by the game, works in combat)", "sndApplied")
	_, y = self:Sounds(body, y, "When one runs out", "sndLapsed")

	local hint = Label(body, "The numbers are sound files whose names are half guesswork. Press them to hear one, or use /tapline sound try to hear them all in order.", 10, 0.6, 0.58, 0.52)
	hint:SetPoint("TOPLEFT", 16, y)
	hint:SetWidth(W - 48)
	hint:SetJustifyH("LEFT")
	y = y - 34

	self:Button(body, y, 16, 110, "Reset layout", function()
		local pp = ns.Profile()
		pp.x, pp.y, pp.barX, pp.barY = nil, nil, nil, nil
		pp.scale = 1
		ns.Panel:Place()
		Options:Refresh()
	end)
	self:Button(body, y, 132, 110, "Self report", function() ns.Debug() end)
	self:Button(body, y, 248, 90, "Close", function() f:Hide() end)

	self.frame = f
	ns.report["options"] = "ok"
	return f
end

function Options:Refresh()
	if not self.frame then return end
	for _, row in ipairs(self.rows or {}) do
		if row.Refresh then pcall(row.Refresh) end
	end
end

function Options:Toggle()
	local f = self:Build()
	if f:IsShown() then f:Hide() else self:Refresh() f:Show() end
	return f:IsShown()
end
