-- Tapline's pieces in the window styles. Styles.lua does the choosing and the drawing (Blizzard,
-- Dark, or EllesmereUI's look); this file says what Tapline restyles.
--
-- Restyled:
--   the heal rows      a flat fill, a dark track with a thin edge, square icons. Every row is
--                      built by Panel.lua's Adorn, ours underneath and the game's over it, so both
--                      get the same look and the swap between them stays invisible. The game only
--                      ever writes values into a row (the countdown, the icon picture, the name);
--                      the art is all ours, chosen when the row is built. A row the game holds
--                      cannot be touched afterwards, so a change of style or accent rebuilds them.
--   the box behind     flat, keeping its background and border opacity settings.
--   our options window, and the copy of the page it shows while a style is drawn.
-- Left alone: the page in the game's options window (the game's own panel, which EllesmereUI
-- leaves be too), and the minimap button (minimap buttons are never restyled).

local ADDON, ns = ...
local Styles = ns.Styles
local Try = Styles.Try

local function S() return Styles.S end

local function Fonts(...)
	for i = 1, select("#", ...) do
		local fs = select(i, ...)
		if type(fs) == "table" and fs.GetFont then S().Font(fs) end
	end
end

-- EllesmereUI lays its border over the window as a frame of its own; the close button goes back
-- on top of it.
local function RaiseAbove(button, win)
	if type(button) ~= "table" or not button.SetFrameLevel then return end
	local top = win:GetFrameLevel() or 0
	for _, child in ipairs({ win:GetChildren() }) do
		if child ~= button then top = math.max(top, child:GetFrameLevel() or 0) end
	end
	button:SetFrameLevel(top + 1)
end

-- Colors of our own that follow the accent: the slider thumbs.
local accented = {}
local function Accent()
	local r, g, b = S().GetAccentColor()
	for _, paint in ipairs(accented) do paint(r, g, b) end
end

-- A slider's track art gives way to a thin dark groove and a flat thumb in the accent color.
local function SkinSlider(part)
	local slider = part.slider
	S().FadeRegions(slider)
	local groove = slider:CreateTexture(nil, "BACKGROUND", nil, -6)
	groove:SetPoint("LEFT")
	groove:SetPoint("RIGHT")
	groove:SetHeight(4)
	groove:SetColorTexture(0, 0, 0, 0.6)
	local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
	if type(thumb) == "table" then
		thumb:SetAlpha(1)
		thumb:SetSize(8, 14)
		accented[#accented + 1] = function(r, g, b) thumb:SetColorTexture(r, g, b, 1) end
	end
	Fonts(part.caption, part.value)
end

-- ---- the heal rows and the box behind them ----------------------------------------------------

local rowAccent -- the accent the rows were built in, so a change of it can rebuild them

-- Called from Adorn for every row, ours and the game's alike, before anything is handed over.
function ns.SkinRow(frame, parts, m)
	local bar, icon = parts.bar, parts.icon
	local r, g, b = S().GetAccentColor()
	rowAccent = { r, g, b }
	-- The fill becomes a plain color, which needs no texture file at all.
	local fill = bar:GetStatusBarTexture()
	if fill then fill:SetColorTexture(1, 1, 1, 1) end
	bar:SetStatusBarColor(r, g, b, 1)
	-- The plate Adorn made is the dark track already; a thin edge goes round it.
	Styles.Outline(bar, bar, "BACKGROUND", 0, 0, 0, 1, 1)
	-- Square: the picture's own bevel cropped off, and a black pixel edge on the row's frame.
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	Styles.Outline(frame, icon, "BORDER", 0, 0, 0, 1, 1)
	-- EllesmereUI's font, at the sizes the row was built with. Dark keeps the game's.
	if Styles.Applied() == "eui" then
		local path = S().GetFont()
		for _, fs in ipairs({ parts.name, parts.time, parts.count }) do
			local _, size, flags = fs:GetFont()
			if path and size then fs:SetFont(path, size, flags) end
		end
	end
end

local boxes = setmetatable({}, { __mode = "k" })
function ns.SkinBox(holder, p)
	if not S() or not holder then return end
	local parts = boxes[holder]
	if not parts then
		if holder.SetBackdrop then pcall(holder.SetBackdrop, holder, nil) end
		local bg = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
		bg:SetAllPoints()
		parts = { bg = bg, edges = Styles.Outline(holder, holder, "BORDER", 0, 0, 0, 1, 0) }
		boxes[holder] = parts
	end
	local r, g, b = S().GetPanelColor()
	parts.bg:SetColorTexture(r or 0.07, g or 0.07, b or 0.08, tonumber(p and p.bgAlpha) or 0.9)
	for _, edge in ipairs(parts.edges) do edge:SetAlpha(tonumber(p and p.borderAlpha) or 1) end
end

-- Rows built before the style was drawn, or in another accent, are made again.
local function RebuildRows(force)
	local panel = ns.Panel
	if not (panel and panel.bars) then return end
	if not force and rowAccent then
		local r, g, b = S().GetAccentColor()
		if r == rowAccent[1] and g == rowAccent[2] and b == rowAccent[3] then
			panel:Restyle() -- the box's panel color may have moved
			return
		end
	end
	panel:Rebuild() -- in a fight it waits for the fight to end, as every rebuild does
end

-- ---- the options window ------------------------------------------------------------------------

function ns.SkinWindow(win)
	if not S() or not win or win.tlSkinned then return end
	win.tlSkinned = true
	Try("options window", function()
		S().Shell(win)
		if type(win.Inset) == "table" then S().Inset(win.Inset) end
		local close = win.CloseButton or win.tlClose
		if type(close) == "table" then
			S().CloseButton(close)
			RaiseAbove(close, win)
		end
		local container = win.TitleContainer
		Fonts(type(container) == "table" and container.TitleText or win.TitleText)
	end)
end

-- The window's own copy of the page (never the one in the game's options window).
function ns.SkinContent(c)
	if not S() or not c then return end
	local parts = c.tlParts
	Try("options checkboxes", function()
		for _, check in ipairs(parts.checks) do
			S().Checkbox(check.button)
			Fonts(check.label)
		end
	end)
	Try("options sliders", function()
		for _, part in ipairs(parts.sliders) do SkinSlider(part) end
	end)
	Try("options buttons", function()
		for _, button in ipairs(parts.buttons) do
			S().Button(button)
			S().WhiteButtonLabel(button)
			if button.GetFontString then Fonts(button:GetFontString()) end
		end
	end)
	Try("options text", function()
		for _, fs in ipairs(parts.texts) do Fonts(fs) end
	end)
	Try("accent", Accent)
end

-- Everything that exists when a style is applied: the window, if it was opened before. If it is
-- open right now it is filled again, so it swaps to its own restyled copy of the page.
local function SkinAll(skin)
	if skin.OnLooksChanged then
		skin.OnLooksChanged(function()
			Try("accent", Accent)
			Try("heal rows", RebuildRows, false)
		end)
	end
	Try("heal rows", RebuildRows, true)
	local options = ns.Options
	local win = options and options.frame
	if not win then return end
	ns.SkinWindow(win)
	if win:IsShown() then
		options:FillWindow()
		options:Refresh()
	end
end

Styles.Setup({
	addon = ADDON,
	title = "Tapline",
	db = function() return ns.Profile and ns.Profile() end,
	report = ns.report,
	accent = { 0.8, 0.4, 1 }, -- the lilac of Tapline's chat lines
	skin = SkinAll,
})
