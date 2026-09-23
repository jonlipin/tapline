-- Tapline's look, copied off the client rather than guessed at.
--
-- The bars are meant to pass for the Cooldown Manager's own, and the only reliable way to do that
-- is to find one of its bars at runtime and MEASURE it: read the real textures, the real atlas
-- names, the real colours, and the real distances each piece reaches past the bar, stored as
-- fractions of the bar's height so they scale. Naming an atlas and hoping is how you end up with
-- art that is the wrong shape, and nothing here is worth that.
--
-- If no donor turns up, there is a hand-made fallback that reads as the same family: dark plate,
-- warm fill, thin border, a pip at the fill's edge. The report says which one is in use.

local ADDON, ns = ...

local Skin = { ready = false }
ns.Skin = Skin

local Clean = ns.Clean
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BORDER_FILE = "Interface\\Tooltips\\UI-Tooltip-Border"
local PLAIN_BAR = "Interface\\TargetingFrame\\UI-StatusBar"

-- Where a Cooldown Manager bar might be found, best first. The viewers hold a pool of item frames;
-- any one of them carries the art, shown or not.
local DONOR_VIEWERS = { "BuffBarCooldownViewer", "EssentialCooldownViewer", "BuffIconCooldownViewer" }
local DONOR_TEMPLATES = { "CooldownViewerBuffBarItemTemplate", "CooldownViewerBarItemTemplate" }
local DONOR_FRAMES = { "PlayerCastingBarFrame", "CastingBarFrame" }

local function Rect(o)
	local ok, l, r, t, b = pcall(function() return o:GetLeft(), o:GetRight(), o:GetTop(), o:GetBottom() end)
	if not ok then return nil end
	l, r, t, b = Clean(l), Clean(r), Clean(t), Clean(b)
	if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then return nil end
	return { l = l, r = r, t = t, b = b, w = r - l, h = t - b }
end

local function Get(o, method, ...)
	if not o or not o[method] then return nil end
	local ok, v = pcall(o[method], o, ...)
	if not ok then return nil end
	return Clean(v)
end

-- Every item frame a viewer is holding, shown or not.
local function ViewerItems(viewer)
	local out = {}
	local pool = viewer and rawget(viewer, "itemFramePool")
	if pool and pool.EnumerateActive then
		local ok = pcall(function()
			for frame in pool:EnumerateActive() do out[#out + 1] = frame end
		end)
		if not ok then wipe(out) end
	end
	if #out == 0 then
		local ok, kids = pcall(function() return { viewer:GetChildren() } end)
		if ok and kids then for _, k in ipairs(kids) do out[#out + 1] = k end end
	end
	return out
end

-- The StatusBar inside an item frame, and the icon texture beside it.
local function PartsOf(item)
	local bar, icon
	local ok = pcall(function()
		for _, key in ipairs({ "Bar", "bar", "StatusBar", "statusBar", "BarFrame" }) do
			local v = rawget(item, key)
			if v and v.GetStatusBarTexture then bar = v break end
		end
		if not bar then
			for _, child in ipairs({ item:GetChildren() }) do
				if child.GetStatusBarTexture and not bar then bar = child end
			end
		end
		for _, key in ipairs({ "Icon", "icon", "Texture" }) do
			local v = rawget(item, key)
			if v and v.GetTexture then icon = v break end
		end
		if not icon then
			for _, region in ipairs({ item:GetRegions() }) do
				if not icon and region.GetTexture and Get(region, "GetObjectType") == "Texture" then
					local r = Rect(region)
					-- The icon is the square one at the left hand end.
					if r and r.w > 4 and abs(r.w - r.h) < 2 then icon = region end
				end
			end
		end
	end)
	if not ok then return nil, nil end
	return bar, icon
end

-- One texture, described so it can be rebuilt on a frame of a different size.
local function Describe(region, ref)
	local r, base = Rect(region), Rect(ref)
	if not r or not base or base.h <= 0 then return nil end
	return {
		atlas = Get(region, "GetAtlas"),
		file = Get(region, "GetTexture"),
		coords = (function()
			local ok, a, b, c, d = pcall(region.GetTexCoord, region)
			if not ok or type(Clean(a)) ~= "number" then return nil end
			return { Clean(a), Clean(b), Clean(c), Clean(d) }
		end)(),
		color = (function()
			local ok, cr, cg, cb, ca = pcall(region.GetVertexColor, region)
			if not ok or type(Clean(cr)) ~= "number" then return nil end
			return { Clean(cr), Clean(cg), Clean(cb), Clean(ca) }
		end)(),
		blend = Get(region, "GetBlendMode"),
		layer = Get(region, "GetDrawLayer"),
		-- How far it reaches past the bar on each side, as a share of the bar's height.
		l = (base.l - r.l) / base.h,
		rr = (r.r - base.r) / base.h,
		t = (r.t - base.t) / base.h,
		b = (base.b - r.b) / base.h,
		w = r.w / base.h,
		h = r.h / base.h,
		-- Narrow against the bar's whole length: that is a spark, which sits at the end of the
		-- fill and moves with it, not a plate that stretches from one end to the other.
		pip = base.w > 0 and (r.w / base.w) < 0.25 or false,
		-- Against the bar's own width and height. Measuring a width in multiples of the HEIGHT was
		-- the mistake: a bar is ten times as wide as it is tall, so its own full length frame looked
		-- like something enormous and was thrown away.
		wRatio = base.w > 0 and (r.w / base.w) or 0,
		hRatio = r.h / base.h,
	}
end

function Skin:Build()
	if self.ready then return self end
	self.ready = true
	-- Nothing in here may throw. It is called while a row is being made, and a row that fails to
	-- be made is a heal you never see land on you, which is worse than a plain looking bar.
	local ok, err = pcall(self.Reckon, self)
	if not ok then
		ns.report["bar skin"] = "could not be read off the client: " .. tostring(err):gsub("^.-%.lua:%d+:%s*", "")
	end
	return self
end

function Skin:Reckon()
	self.source = "hand made"
	self.fillColor = { 0.96, 0.55, 0.16 }
	self.barTexture = PLAIN_BAR
	self.pieces = {}

	local item, bar, icon
	for _, name in ipairs(DONOR_VIEWERS) do
		local viewer = _G[name]
		if viewer then
			for _, candidate in ipairs(ViewerItems(viewer)) do
				local b, i = PartsOf(candidate)
				if b and Rect(b) then item, bar, icon = candidate, b, i break end
			end
		end
		if bar then self.source = "the Cooldown Manager (" .. name .. ")" break end
	end
	if not bar then
		for _, template in ipairs(DONOR_TEMPLATES) do
			local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, template)
			if ok and made then
				local b, i = PartsOf(made)
				if b and Rect(b) then
					item, bar, icon = made, b, i
					self.source = "a Cooldown Manager template (" .. template .. ")"
					break
				end
			end
		end
	end
	if not bar then
		for _, name in ipairs(DONOR_FRAMES) do
			local f = _G[name]
			local b = f and (rawget(f, "Bar") or f)
			if b and b.GetStatusBarTexture and Rect(b) then
				item, bar = f, b
				self.source = "the cast bar (" .. name .. ")"
				break
			end
		end
	end

	if bar then
		local fillTex = Get(bar, "GetStatusBarTexture")
		self.fillTex = fillTex
		if fillTex then
			self.barAtlas = Get(fillTex, "GetAtlas")
			self.barTexture = Get(fillTex, "GetTexture") or PLAIN_BAR
			local ok, cr, cg, cb = pcall(fillTex.GetVertexColor, fillTex)
			if ok and type(Clean(cr)) == "number" then self.fillColor = { Clean(cr), Clean(cg), Clean(cb) } end
		end
		-- The frame, the backing and the spark are the STATUS BAR's own regions here, not the item
		-- frame's, which is why nothing was being copied and the bars came out plain. Every likely
		-- home is walked now: the item, the bar, and one level of children beneath the item.
		local sources, seen = { item }, {}
		if bar ~= item then sources[#sources + 1] = bar end
		local okKids, kids = pcall(function() return { item:GetChildren() } end)
		if okKids and kids then
			for _, kid in ipairs(kids) do sources[#sources + 1] = kid end
		end
		local found = {}
		for _, source in ipairs(sources) do
			local okR, regions = pcall(function() return { source:GetRegions() } end)
			if okR and regions then
				for _, region in ipairs(regions) do
					-- The fill itself is worn by our own bar, so it is not decoration to lay on top.
					if region ~= icon and region ~= fillTex and not seen[region]
						and Get(region, "GetObjectType") == "Texture" then
						seen[region] = true
						local d = Describe(region, bar)
						-- Decoration belongs to the bar if it is about the bar's size. Generous, since a
						-- frame reaches past what it frames, but not so generous that a whole window sneaks in.
						if d and (d.atlas or d.file) and d.wRatio <= 2 and d.hRatio <= 4 then
							self.pieces[#self.pieces + 1] = d
							found[#found + 1] = (d.atlas or tostring(d.file)) .. (d.pip and " (spark)" or "")
						end
					end
				end
			end
		end
		ns.report["bar pieces"] = #found > 0 and table.concat(found, ", ") or "none found on the item, the bar or its children"
		-- The fonts: which end each sits at, and how big against the bar.
		local okF, fonts = pcall(function()
			local out = {}
			for _, region in ipairs({ item:GetRegions() }) do
				if Get(region, "GetObjectType") == "FontString" then out[#out + 1] = region end
			end
			return out
		end)
		if okF and fonts then
			local base = Rect(bar)
			for _, fs in ipairs(fonts) do
				local r = Rect(fs)
				local _, size = pcall(function() return select(2, fs:GetFont()) end)
				size = Clean(size)
				if r and base and base.h > 0 and type(size) == "number" then
					local which = (r.l - base.l) < (base.r - r.r) and "nameFont" or "durFont"
					self[which] = { size = size / base.h }
				end
			end
		end
		if icon then
			local ok, masks = pcall(function() return icon:GetNumMaskTextures() end)
			if ok and (Clean(masks) or 0) > 0 then
				local okM, mask = pcall(function() return icon:GetMaskTexture(1) end)
				if okM and mask then self.iconMask = Get(mask, "GetAtlas") end
			end
		end
	end

	ns.report["bar skin"] = ("%s, %d pieces%s"):format(self.source, #self.pieces,
		self.barAtlas and (", fill atlas " .. self.barAtlas) or (self.barTexture ~= PLAIN_BAR and ", fill texture copied" or ", plain fill"))
	return self
end

-- Dresses one StatusBar and, if given, its icon. Everything is guarded: a piece the client would
-- not describe is simply left out rather than taking the bar down with it.
function Skin:Dress(bar, height, icon, name, time, iconSize)
	self:Build()
	local okAll, whyNot = pcall(self.Apply, self, bar, height, icon, name, time, iconSize)
	if not okAll then ns.report["bar art"] = "refused: " .. tostring(whyNot):gsub("^.-%.lua:%d+:%s*", "") end
	return okAll
end

function Skin:Apply(bar, height, icon, name, time, iconSize)
	-- Measured against the icon, never against the bar: the art round a picture grows with the
	-- picture, and sizing it off the bar is what let it reach across into the fill.
	iconSize = iconSize or height
	local tex = bar:GetStatusBarTexture()
	if self.barAtlas and tex and tex.SetAtlas then
		pcall(tex.SetAtlas, tex, self.barAtlas)
	else
		pcall(bar.SetStatusBarTexture, bar, self.barTexture or PLAIN_BAR)
		tex = bar:GetStatusBarTexture()
	end
	local c = self.fillColor or { 0.96, 0.55, 0.16 }
	pcall(bar.SetStatusBarColor, bar, c[1], c[2], c[3])

	if not bar.tlPlate then
		local plate = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
		plate:SetAllPoints(bar)
		plate:SetColorTexture(0, 0, 0, 0.85)
		bar.tlPlate = plate
	end

	-- The copied decoration, laid back on at this bar's size.
	bar.tlArt = bar.tlArt or {}
	for _, piece in ipairs(bar.tlArt) do piece:Hide() end
	for i, d in ipairs(self.pieces) do
		local t = bar.tlArt[i] or bar:CreateTexture(nil, "ARTWORK", nil, (d.t or 0) > 0 and 1 or -1)
		bar.tlArt[i] = t
		if d.atlas and t.SetAtlas then pcall(t.SetAtlas, t, d.atlas) elseif d.file then pcall(t.SetTexture, t, d.file) end
		if d.coords then t:SetTexCoord(d.coords[1], d.coords[2], d.coords[3], d.coords[4]) end
		if d.color then t:SetVertexColor(d.color[1], d.color[2], d.color[3], d.color[4] or 1) end
		if d.blend then pcall(t.SetBlendMode, t, d.blend) end
		t:ClearAllPoints()
		if d.pip then
			-- A spark keeps its own size and sits on the end of the fill, so it travels with it.
			local fill = bar:GetStatusBarTexture()
			t:SetSize(max(2, (d.w or 0.2) * height), max(2, (d.h or 1) * height))
			t:SetPoint("CENTER", fill or bar, "RIGHT", 0, 0)
			t:SetDrawLayer("OVERLAY", 2)
			bar.tlPip = t
		else
			t:SetPoint("TOPLEFT", bar, "TOPLEFT", -(d.l or 0) * height, (d.t or 0) * height)
			t:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", (d.rr or 0) * height, -(d.b or 0) * height)
		end
		t:Show()
	end
	-- What the client actually handed over, piece by piece. The old test was whether ANY art had
	-- been copied, which is far too coarse: the moment one stray texture was found the hand-made
	-- frame stopped being drawn, and if that texture was not a frame the bar simply lost its edge.
	-- Each part of the look is asked for separately now, and made by hand only where it is missing.
	local hasFrame, hasPip = false, false
	for _, d in ipairs(self.pieces) do
		if d.pip then hasPip = true
		-- A frame is a piece that reaches PAST what it frames. Anything sitting inside the bar is a
		-- backing, and a backing is not an edge.
		elseif (d.l or 0) > 0.01 or (d.rr or 0) > 0.01 or (d.t or 0) > 0.01 or (d.b or 0) > 0.01 then
			hasFrame = true
		end
	end
	local forced = (ns.Profile() or {}).edge == "always"

	if not hasFrame or forced then
		if not bar.tlEdge then
			local okE, edge = pcall(CreateFrame, "Frame", nil, bar, "BackdropTemplate")
			if okE and edge and edge.SetBackdrop then
				edge:SetPoint("TOPLEFT", -2, 2)
				edge:SetPoint("BOTTOMRIGHT", 2, -2)
				edge:SetBackdrop({ edgeFile = BORDER_FILE, edgeSize = 10 })
				edge:SetBackdropBorderColor(0.72, 0.60, 0.36, 1)
				bar.tlEdge = edge
			end
		end
		if bar.tlEdge then bar.tlEdge:Show() end
	elseif bar.tlEdge then
		bar.tlEdge:Hide()
	end

	if not hasPip and not bar.tlPip then
		-- No spark to copy, so one of our own: a bright sliver riding the end of the fill, which is
		-- what makes a bar read as moving rather than merely long.
		local pip = bar:CreateTexture(nil, "OVERLAY", nil, 2)
		pip:SetColorTexture(1, 0.93, 0.75, 0.85)
		pcall(pip.SetBlendMode, pip, "ADD")
		bar.tlPip, bar.tlOwnPip = pip, true
	end
	if bar.tlOwnPip and bar.tlPip then
		local fill = bar:GetStatusBarTexture()
		bar.tlPip:SetSize(max(2, height * 0.12), max(4, height))
		bar.tlPip:ClearAllPoints()
		bar.tlPip:SetPoint("CENTER", fill or bar, "RIGHT", 0, 0)
		bar.tlPip:Show()
	end
	ns.report["bar frame"] = (hasFrame and not forced) and "copied from the client" or "made here"
	ns.report["bar spark"] = hasPip and "copied from the client" or "made here"

	if icon then
		if self.iconMask and icon.AddMaskTexture and not icon.tlMask then
			local okM, m = pcall(function() return bar:GetParent():CreateMaskTexture() end)
			if okM and m and m.SetAtlas and pcall(m.SetAtlas, m, self.iconMask) then
				-- A mask atlas here is bigger than the shape it carries, so it is drawn larger than
				-- what it clips or it eats the edges of the picture.
				m:SetPoint("TOPLEFT", icon, "TOPLEFT", -iconSize * 0.13, iconSize * 0.13)
				m:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", iconSize * 0.13, -iconSize * 0.13)
				pcall(icon.AddMaskTexture, icon, m)
				icon.tlMask = m
			end
		end
		if not icon.tlOverlay then
			local okO, o = pcall(function() return bar:GetParent():CreateTexture(nil, "OVERLAY") end)
			if not okO then o = nil end
			if o then
			-- Measured off the manager: the overlay is not square, reaching further across than down.
			local okAtlas = o.SetAtlas and pcall(o.SetAtlas, o, "UI-HUD-CoolDownManager-IconOverlay")
			ns.report["icon shadow"] = okAtlas and "the manager's own overlay" or "this client has no icon overlay atlas"
			if okAtlas and o then
				local w, h = 0.200, 0.175
				o:SetPoint("TOPLEFT", icon, "TOPLEFT", -iconSize * w, iconSize * h)
				o:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", iconSize * w, -iconSize * h)
				icon.tlOverlay = o
			elseif o then
				-- Nothing to copy, so a dark halo a little larger than the picture, which is what that
				-- overlay amounts to: it is a shadow, not a border.
				o:SetColorTexture(0, 0, 0, 0.55)
				o:SetDrawLayer("BACKGROUND", -2)
				o:ClearAllPoints()
				o:SetPoint("TOPLEFT", icon, "TOPLEFT", -iconSize * 0.08, iconSize * 0.08)
				o:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", iconSize * 0.08, -iconSize * 0.08)
				o:Show()
				ns.report["icon shadow"] = "made here: this client has no overlay atlas"
			end
			end
		end
	end
	-- The fonts the manager uses, once there is art to size them against.
	if name and time then
		local f1, s1, g1 = ns.SkinFont("nameFont", height)
		pcall(name.SetFont, name, f1, s1, g1)
		local f2, s2, g2 = ns.SkinFont("durFont", height)
		pcall(time.SetFont, time, f2, s2, g2)
	end
end

-- The manager writes its times as "6 s" and "1 m". Matched, so a Tapline bar beside one does not
-- announce itself.
function ns.BarTime(sec)
	if not sec or sec < 0 then return "" end
	if sec >= 3600 then return ("%d h"):format(floor(sec / 3600)) end
	if sec >= 60 then return ("%d m"):format(floor(sec / 60)) end
	-- Rounded down, not to nearest: a timer that reads 6 with six seconds left is what the manager
	-- does, and a bar that says 7 while 6.4 remain is lying in the direction that gets you killed.
	if sec >= 1 then return ("%d s"):format(floor(sec)) end
	return ("%.1f s"):format(sec)
end

function ns.SkinFont(which, height)
	local s = Skin:Build()
	local spec = s[which]
	local size = spec and spec.size and max(8, floor(spec.size * height + 0.5)) or max(9, floor(height * 0.42))
	return FONT, size, "OUTLINE"
end
