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

-- Whether this client actually has an atlas. This is the answer to the problem that dogged the
-- whole skin: a texture set to art the client does not have renders as nothing, and nothing looks
-- exactly like a piece that was never copied. Asked outright, the two stop being alike.
local function AtlasExists(name)
	if type(name) ~= "string" then return false end
	if C_Texture and C_Texture.GetAtlasInfo then
		local ok, info = pcall(C_Texture.GetAtlasInfo, name)
		return (ok and type(info) == "table") and info or false
	end
	-- No way to ask, so let the art speak for itself.
	return true
end

-- Blizzard's own spark, by the names the Cooldown Manager uses for it, in case the donor bar is
-- not carrying one where it can be measured.
local SPARK_ATLASES = {
	"UI-HUD-CoolDownManager-Bar-Pip",
	"UI-HUD-CoolDownManager-Bar-Spark",
	"UI-HUD-CoolDownManager-Bar-Glow",
	"UI-HUD-CoolDownManager-Bar-Tick",
}

local function Rect(o)
	local ok, l, r, t, b = pcall(function() return o:GetLeft(), o:GetRight(), o:GetTop(), o:GetBottom() end)
	if not ok then return nil end
	l, r, t, b = Clean(l), Clean(r), Clean(t), Clean(b)
	if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then return nil end
	return { l = l, r = r, t = t, b = b, w = r - l, h = t - b }
end

-- How far one region reaches past another, as shares of that other's size. This is the whole
-- trick: a piece measured this way can be laid back on an icon of any size and keep its shape.
-- Naming an atlas and reckoning a size from it is what produced art of the wrong shape before.
local function RelRect(region, ref)
	local r, base = Rect(region), Rect(ref)
	if not r or not base or base.w <= 0 or base.h <= 0 then return nil end
	return {
		l = (base.l - r.l) / base.w,
		r = (r.r - base.r) / base.w,
		t = (r.t - base.t) / base.h,
		b = (base.b - r.b) / base.h,
	}
end

-- What the manager draws round its own icon, when none of it can be measured: one mask exactly
-- the size of the picture, and an overlay reaching past it further across than down. That overlay
-- IS the shadow on this client; there is no border art on any of the viewers.
local ICON_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local ICON_OVERLAY_RECT = { l = 0.200, r = 0.200, t = 0.175, b = 0.175 }

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

local function IsTexture(o)
	return o ~= nil and Get(o, "GetObjectType") == "Texture"
end

local function Field(o, key)
	if type(o) ~= "table" then return nil end
	local ok, v = pcall(function() return o[key] end)
	return ok and v or nil
end

local function Regions(o)
	if not o then return {} end
	local ok, list = pcall(function() return { o:GetRegions() } end)
	return ok and list or {}
end

local function Children(o)
	if not o then return {} end
	local ok, list = pcall(function() return { o:GetChildren() } end)
	return ok and list or {}
end

-- The manager's icon, and the frame it sits on.
--
-- On the real item, .Icon is a FRAME holding the texture rather than the texture itself, and a
-- check for "does this have GetTexture" walks straight past it. With no icon in hand there is
-- nothing to measure the mask and the shadow against, and nothing to keep out of the bar art, so
-- missing it quietly breaks three things at once.
local function FindIcon(item)
	for _, key in ipairs({ "Icon", "icon", "Texture" }) do
		local v = Field(item, key)
		if IsTexture(v) then return v, item end
		if v then
			local inner = Field(v, "Icon") or Field(v, "icon")
			if IsTexture(inner) then return inner, v end
			for _, r in ipairs(Regions(v)) do
				if IsTexture(r) then return r, v end
			end
		end
	end
	-- Otherwise the squarest texture on the item or on any of its children: an icon is square and
	-- everything else on one of these rows is not.
	local holders = { item }
	for _, kid in ipairs(Children(item)) do holders[#holders + 1] = kid end
	for _, holder in ipairs(holders) do
		for _, r in ipairs(Regions(holder)) do
			if IsTexture(r) then
				local rect = Rect(r)
				if rect and rect.w > 4 and abs(rect.w - rect.h) < 2 then return r, holder end
			end
		end
	end
end

-- The StatusBar inside an item frame, and the icon texture beside it.
local function PartsOf(item)
	local bar
	local ok = pcall(function()
		for _, key in ipairs({ "Bar", "bar", "StatusBar", "statusBar", "BarFrame" }) do
			local v = Field(item, key)
			if v and v.GetStatusBarTexture then bar = v break end
		end
		if not bar then
			for _, child in ipairs(Children(item)) do
				if child.GetStatusBarTexture and not bar then bar = child end
			end
		end
	end)
	if not ok then return nil, nil, nil end
	local icon, iconFrame = FindIcon(item)
	return bar, icon, iconFrame
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

	local item, bar, icon, iconFrame
	for _, name in ipairs(DONOR_VIEWERS) do
		local viewer = _G[name]
		if viewer then
			for _, candidate in ipairs(ViewerItems(viewer)) do
				local b, i, holder = PartsOf(candidate)
				if b and Rect(b) then item, bar, icon, iconFrame = candidate, b, i, holder break end
			end
		end
		if bar then self.source = "the Cooldown Manager (" .. name .. ")" break end
	end
	if not bar then
		for _, template in ipairs(DONOR_TEMPLATES) do
			local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, template)
			if ok and made then
				local b, i, holder = PartsOf(made)
				if b and Rect(b) then
					item, bar, icon, iconFrame = made, b, i, holder
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
						-- Art sitting on the icon belongs to the icon. It is collected separately below,
						-- and left here it would be laid across the bar as a plate, or worse, mistaken
						-- for a spark, since it is narrow against a bar ten times its width.
						local near = icon and (function()
							local rel = RelRect(region, icon)
							return rel and max(abs(rel.l), abs(rel.r), abs(rel.t), abs(rel.b)) <= 0.6
						end)()
						if near then seen[region] = true end
						local d = Describe(region, bar)
						-- Decoration belongs to the bar if it is about the bar's size. Generous, since a
						-- frame reaches past what it frames, but not so generous that a whole window sneaks in.
						if not near and d and (d.atlas or d.file) and d.wRatio <= 2 and d.hRatio <= 4 then
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
			-- Every mask on the manager's icon, with the rectangle each one covers measured against
			-- that icon. On this client there is one and it sits exactly on the picture, but measuring
			-- it costs nothing and means a client that differs is followed rather than fought.
			self.iconMasks = {}
			local okN, n = pcall(function() return icon:GetNumMaskTextures() end)
			n = okN and Clean(n) or 0
			for i = 1, n do
				local okM, mask = pcall(function() return icon:GetMaskTexture(i) end)
				if okM and mask then
					local rect = RelRect(mask, icon)
					local atlas, file = Get(mask, "GetAtlas"), Get(mask, "GetTexture")
					if rect and (atlas or file) then
						self.iconMasks[#self.iconMasks + 1] = { atlas = atlas, file = file, rect = rect }
					end
				end
			end
			-- And everything else the item draws near the icon, kept with the layer it is drawn in.
			-- Anything reaching more than half an icon away belongs to the bar, not to the picture.
			self.iconUnder, self.iconOver = {}, {}
			-- The art may hang on the item or on the frame the icon itself sits on.
			local near = {}
			for _, r in ipairs(Regions(item)) do near[#near + 1] = r end
			if iconFrame and iconFrame ~= item then
				for _, r in ipairs(Regions(iconFrame)) do near[#near + 1] = r end
			end
			if true then
				for _, region in ipairs(near) do
					if region ~= icon and Get(region, "GetObjectType") == "Texture" then
						local rect = RelRect(region, icon)
						local atlas, file = Get(region, "GetAtlas"), Get(region, "GetTexture")
						local near = rect and max(abs(rect.l), abs(rect.r), abs(rect.t), abs(rect.b)) <= 0.6
						local okShown, shown = pcall(function() return region:IsShown() end)
						if near and (atlas or file) and not (okShown and Clean(shown) == false) then
							local layer = Get(region, "GetDrawLayer") or "ARTWORK"
							local into = (layer == "BACKGROUND" or layer == "BORDER") and self.iconUnder or self.iconOver
							into[#into + 1] = { atlas = atlas, file = file, rect = rect, layer = layer }
						end
					end
				end
			end
		end
	end

	ns.report["bar skin"] = ("%s, %d pieces%s"):format(self.source, #self.pieces,
		self.barAtlas and (", fill atlas " .. self.barAtlas) or (self.barTexture ~= PLAIN_BAR and ", fill texture copied" or ", plain fill"))
	return self
end

-- Dresses one StatusBar and, if given, its icon. Everything is guarded: a piece the client would
-- not describe is simply left out rather than taking the bar down with it.
function Skin:Dress(bar, height, icon, name, time, iconSize, already)
	self:Build()
	local okAll, whyNot = pcall(self.Apply, self, bar, height, icon, name, time, iconSize, already)
	if not okAll then ns.report["bar art"] = "refused: " .. tostring(whyNot):gsub("^.-%.lua:%d+:%s*", "") end
	return okAll
end

function Skin:Apply(bar, height, icon, name, time, iconSize, already)
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
			bar.tlCopiedPip = t
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
	-- Whether a copied piece is the frame round the bar.
	--
	-- Geometry alone was not enough. The test was whether a piece reached past the bar, and the
	-- manager's backing sits a pixel or two proud of it, which counted. So a bar that has a backing
	-- and no frame at all was read as framed, the hand-made edge stopped being drawn, and the
	-- border simply vanished. The art says what it is in its own name, so that is asked first.
	local function LooksLikeFrame(d)
		local name = tostring(d.atlas or d.file or "")
		if name:find("Border") or name:find("Frame") or name:find("Edge") then return true end
		if name:find("BG") or name:find("Background") or name:find("Backing") then return false end
		-- Nothing to go on but the shape, then, and at a reach a backing will not manage.
		return (d.l or 0) > 0.06 or (d.rr or 0) > 0.06 or (d.t or 0) > 0.06 or (d.b or 0) > 0.06
	end

	local hasFrame, hasPip = false, false
	for _, d in ipairs(self.pieces) do
		if d.pip then hasPip = true
		elseif LooksLikeFrame(d) then hasFrame = true end
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

	-- The spark: Blizzard's own art where this client has it, and a plain sliver only when it has
	-- not. It is taken in three goes, best first.
	--
	--   1. the piece measured off the donor bar, if its atlas really exists
	--   2. the manager's spark asked for by name, if that exists
	--   3. a sliver drawn here, which is at least certain to appear
	--
	-- The middle step is worth having because the donor is not always carrying a spark at the
	-- moment it is read: a bar with nothing running has nothing at its end to measure.
	if bar.tlCopiedPip then bar.tlCopiedPip:Hide() end
	local wantSpark = (ns.Profile() or {}).spark ~= false
	if wantSpark then
		local picked, info, how
		for _, d in ipairs(self.pieces) do
			if d.pip and not picked then
				local exists = AtlasExists(d.atlas)
				if exists then picked, info, how = d.atlas, exists, "measured off the manager's own bar" end
			end
		end
		if not picked then
			for _, name in ipairs(SPARK_ATLASES) do
				local exists = AtlasExists(name)
				if exists and not picked then picked, info, how = name, exists, "the manager's own art, by name" end
			end
		end
		if not bar.tlSpark then bar.tlSpark = bar:CreateTexture(nil, "OVERLAY", nil, 3) end
		local spark = bar.tlSpark
		-- Blizzard's spark is drawn for a bar taller than these usually are, so at its own scale it
		-- comes out a sliver. It is given a size of its own, and keeps its shape at any of them.
		local scale = tonumber((ns.Profile() or {}).sparkScale) or 1.6
		if scale < 0.5 then scale = 0.5 elseif scale > 4 then scale = 4 end
		local tall = max(6, floor(height * 1.15 * scale + 0.5))
		if picked and spark.SetAtlas and pcall(spark.SetAtlas, spark, picked) then
			-- Its own proportions, scaled to this bar, so it is Blizzard's shape and not a rectangle.
			local ratio = (type(info) == "table" and tonumber(info.width) and tonumber(info.height) and info.height > 0)
				and (info.width / info.height) or 0.2
			spark:SetSize(max(3, floor(tall * ratio + 0.5)), tall)
			pcall(spark.SetVertexColor, spark, 1, 1, 1, 1)
			ns.report["bar spark"] = ("%s (%s)"):format(picked, how)
		else
			-- Nothing of Blizzard's to be had here, so something certain instead.
			pcall(spark.SetAtlas, spark, nil)
			spark:SetColorTexture(1, 0.97, 0.88, 0.9)
			pcall(spark.SetBlendMode, spark, "ADD")
			spark:SetSize(max(3, floor(height * 0.18 * scale + 0.5)), tall)
			ns.report["bar spark"] = "drawn here: this client has none of the manager's spark art"
		end
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", bar:GetStatusBarTexture() or bar, "RIGHT", 0, 0)
		-- An empty bar has its fill squeezed to nothing at the left hand end, and the spark rides
		-- the end of the fill, so on a row with no heal on it the spark sat against the left edge
		-- looking like a mark on the plate. It belongs to a bar that is actually running.
		local function follow(value)
			if bar.tlSpark then bar.tlSpark:SetShown((tonumber(value) or 0) > 0.001) end
			-- The same watch says how fast the game is draining this bar, which is what lets it be
			-- carried on smoothly between those updates. Our own writes are skipped: timing them
			-- would be timing ourselves.
			if bar.tlOurs then return end
			local v, now = tonumber(value), GetTime()
			if not v then bar.tlSeen = nil return end
			local seen = bar.tlSeen
			local rate
			if seen and seen.at and now > seen.at and seen.value and v < seen.value then
				rate = (seen.value - v) / (now - seen.at)
				-- A jump far too big to be a countdown is a new heal landing, not a drain.
				if rate > 2 then rate = nil end
			end
			bar.tlSeen = { value = v, at = now, rate = rate }
		end
		if not bar.tlSparkHooked then
			bar.tlSparkHooked = true
			pcall(bar.HookScript, bar, "OnValueChanged", function(_, value) follow(value) end)
		end
		local okV, current = pcall(bar.GetValue, bar)
		follow(okV and current or 0)
	else
		if bar.tlSpark then bar.tlSpark:Hide() end
		ns.report["bar spark"] = "off"
	end
	ns.report["bar frame"] = (hasFrame and not forced) and "copied from the client" or "made here"

	if icon then self:ShapeIcon(icon, iconSize, already) end

	-- The fonts the manager uses, once there is art to size them against.
	if name and time then
		local f1, s1, g1 = ns.SkinFont("nameFont", height)
		pcall(name.SetFont, name, f1, s1, g1)
		local f2, s2, g2 = ns.SkinFont("durFont", height)
		pcall(time.SetFont, time, f2, s2, g2)
	end
end

-- The mask and the shadow on one icon.
--
-- Measured art first, the manager's own atlases by name second, nothing third. The shadow here is
-- not a border: on this client it is the icon overlay, drawn OVER the picture and reaching further
-- across it than down, which is why it is placed by a rectangle rather than an inset.
--
-- "already" is how many layers of that overlay are on the icon before this addon draws any, which
-- is one on a row the game fills, because the game draws its own.
function Skin:ShapeIcon(icon, size, already)
	local p = ns.Profile() or {}
	if not icon.tlMasks and icon.AddMaskTexture then
		icon.tlMasks = {}
		local defs = self.iconMasks
		local how = "measured off the manager"
		if not defs or #defs == 0 then
			defs = AtlasExists(ICON_MASK_ATLAS) and { { atlas = ICON_MASK_ATLAS, rect = { l = 0, r = 0, t = 0, b = 0 } } } or {}
			how = #defs > 0 and "the manager's own mask, by name" or "none: this client has no mask art"
		end
		for _, def in ipairs(defs) do
			local okM, m = pcall(function() return icon:GetParent():CreateMaskTexture() end)
			if okM and m then
				local set = def.atlas and pcall(m.SetAtlas, m, def.atlas) or (def.file and pcall(m.SetTexture, m, def.file))
				if set then
					m:ClearAllPoints()
					m:SetPoint("TOPLEFT", icon, "TOPLEFT", -(def.rect.l or 0) * size, (def.rect.t or 0) * size)
					m:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", (def.rect.r or 0) * size, -(def.rect.b or 0) * size)
					if pcall(icon.AddMaskTexture, icon, m) then icon.tlMasks[#icon.tlMasks + 1] = m
					else pcall(m.Hide, m) end
				else
					pcall(m.Hide, m)
				end
			end
		end
		ns.report["icon mask"] = ("%s (%d on)"):format(how, #icon.tlMasks)
	end

	-- How deep the shadow goes. One layer is what the manager draws; two is what its icons read as,
	-- and a row the game fills already carries one of its own.
	local want = tonumber(p.shadowLayers) or 2
	if want < 0 then want = 0 elseif want > 4 then want = 4 end
	local layers = max(0, want - (already or 0))

	icon.tlShadow = icon.tlShadow or {}
	for _, t in ipairs(icon.tlShadow) do t:Hide() end
	local defs = {}
	for _, def in ipairs(self.iconUnder or {}) do defs[#defs + 1] = def end
	for _, def in ipairs(self.iconOver or {}) do defs[#defs + 1] = def end
	local how = "measured off the manager"
	if #defs == 0 then
		if AtlasExists(ICON_OVERLAY_ATLAS) then
			defs = { { atlas = ICON_OVERLAY_ATLAS, rect = ICON_OVERLAY_RECT, layer = "OVERLAY" } }
			how = "the manager's own overlay, by name"
		else
			how = "none: this client has no icon overlay art"
		end
	end
	local made = 0
	for layer = 1, layers do
		for _, def in ipairs(defs) do
			made = made + 1
			local t = icon.tlShadow[made]
			if not t then
				local under = def.layer == "BACKGROUND" or def.layer == "BORDER"
				local okT, made2 = pcall(function()
					return icon:GetParent():CreateTexture(nil, under and "BACKGROUND" or "OVERLAY", nil, under and -3 or 1)
				end)
				t = okT and made2 or nil
				if t then icon.tlShadow[made] = t end
			end
			if t then
				local set = def.atlas and pcall(t.SetAtlas, t, def.atlas) or (def.file and pcall(t.SetTexture, t, def.file))
				if set then
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", icon, "TOPLEFT", -(def.rect.l or 0) * size, (def.rect.t or 0) * size)
					t:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", (def.rect.r or 0) * size, -(def.rect.b or 0) * size)
					t:Show()
				else
					t:Hide()
				end
			end
		end
	end
	ns.report["icon shadow"] = ("%s, %d of %d layers drawn here"):format(how, layers, want)
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
