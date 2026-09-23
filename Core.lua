-- Tapline: should this health become mana?
--
-- A warlock asks that question every fight, and answering it wants two things: how much health
-- there is, and whether more is on the way. This client is unhelpful about both.
--
-- Health and mana were meant to be the easy half. They are not aura data, so the expectation was
-- that they could be read in a fight like any other number. They cannot: verified in game on
-- 2026-09-23, out of combat and with auras perfectly readable, UnitHealth and UnitPower hand back
-- SECRET VALUES, and so does every player frame bar that exists here. An addon may hold such a
-- value but not look inside it, so there is no arithmetic to be done on your own health at all.
-- What is left is a percentage, if this client will give one, and that is tried last.
--
-- Whether anything is healing you is harder still. While addon restrictions are up, every read of
-- an aura errors or comes back secret, the UNIT_AURA payload lists are secret, and the combat log
-- is closed to addons. The game will play a sound for us and draw a slot for us, but neither tells
-- the addon anything: there is no callback behind either.
--
-- So the question is answered three ways, and the panel always says which answer it is giving:
--
--   read       wherever the auras are legible, the heal is read straight off you and the time
--              shown is the real one.
--   estimated  while blind, the health itself is watched. A gain that nothing you did accounts for
--              is a tick, and two of them about three seconds apart is somebody healing you. That
--              reading is late by up to one tick, it cannot name the spell, and a tick landing in
--              the same tenth of a second as a hit is lost in the arithmetic, so it is marked ~.
--   drawn      the game is asked to draw the heals itself, in slots it keeps right through a
--              fight. This addon cannot read what it drew, but you can, and that is the version to
--              trust when the two disagree.
--
-- Everything that reads the client is written to report what it was refused rather than to go
-- quiet, because on this client "it did not work" is never the useful half of the answer.
-- "/tapline debug" prints the lot.

local ADDON, ns = ...

ns.VERSION = "1.1.0"
ns.report = {}

local floor, max, min = math.floor, math.max, math.min
local strlower = string.lower

-- ------------------------------------------------------------------
-- Talking
-- ------------------------------------------------------------------
-- Everything printed is also kept in the saved variables, because the useful output here is a long
-- report and the only way it has reached me so far is a photograph of the screen. Saved, it can be
-- read off disk after a /reload instead.
local LOG_CAP = 800
local pending = {}
function ns.LogLine(text)
	local line = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local db = ns.db
	if not db then
		pending[#pending + 1] = line
		if #pending > LOG_CAP then table.remove(pending, 1) end
		return
	end
	if type(db.log) ~= "table" then db.log = {} end
	if #pending > 0 then
		for _, held in ipairs(pending) do db.log[#db.log + 1] = held end
		pending = {}
	end
	db.log[#db.log + 1] = line
	while #db.log > LOG_CAP do table.remove(db.log, 1) end
end

function ns.Print(msg)
	if issecretvalue and issecretvalue(msg) then msg = "(secret value)" end
	msg = tostring(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffcc66ffTapline:|r " .. msg)
	ns.LogLine(msg)
end
local Print = ns.Print

function ns.YesNo(v) return v and "|cff40ff40yes|r" or "|cffff5050no|r" end
local YesNo = ns.YesNo

-- ------------------------------------------------------------------
-- Secret values
--
-- This client does not always refuse a read. Sometimes it answers with a value an addon may hold
-- but not look inside, and letting one of those reach arithmetic taints everything downstream.
-- ------------------------------------------------------------------
function ns.Clean(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end
local Clean = ns.Clean

-- The reason a read did not produce a number. The three walls want three different answers: a
-- function this client does not have, a call it refuses, and a number handed over as a secret.
local function Reason(err)
	if issecretvalue and issecretvalue(err) then return "refused, with a secret value" end
	local ok, text = pcall(tostring, err)
	if not ok then return "refused" end
	-- The client puts its own file and line on the front; the message is the useful part.
	return "refused: " .. (text:gsub("^.-%.lua:%d+:%s*", ""))
end

-- A number from the client, or nil and why not.
function ns.Read(fn, ...)
	if type(fn) ~= "function" then return nil, "no such function" end
	local ok, v = pcall(fn, ...)
	if not ok then return nil, Reason(v) end
	if issecretvalue and issecretvalue(v) then return nil, "secret" end
	if type(v) ~= "number" then return nil, "gave a " .. type(v) end
	return v, nil
end
local Read = ns.Read

function ns.AurasSecret()
	if C_Secrets and C_Secrets.ShouldAurasBeSecret then
		local ok, v = pcall(C_Secrets.ShouldAurasBeSecret)
		return ok and Clean(v) == true
	end
	return false
end

-- ------------------------------------------------------------------
-- Spells
-- ------------------------------------------------------------------
function ns.SpellInfo(idOrName)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, idOrName)
		if ok and type(info) == "table" and Clean(info.name) then
			return Clean(info.name), Clean(info.iconID) or Clean(info.originalIconID), Clean(info.spellID)
		end
	end
	if GetSpellInfo then
		local ok, name, _, icon, _, _, _, id = pcall(GetSpellInfo, idOrName)
		if ok and Clean(name) then return Clean(name), Clean(icon), Clean(id) end
	end
end

-- Every spell id that stands for a named spell: the ranks written down in Data.lua, kept only where
-- this client agrees the id carries that name. A rank the client has not loaded yet resolves to
-- nothing, so those are asked for and tried again a few times before the answer is left alone.
local rankIndex, rankState = nil, {}
ns.rankState = rankState

function ns.Ranks(name)
	if type(name) ~= "string" or type(ns.RANK_IDS) ~= "table" then return nil end
	if not rankIndex then
		rankIndex = {}
		for spell, ids in pairs(ns.RANK_IDS) do rankIndex[strlower(spell)] = { spell = spell, ids = ids } end
	end
	local row = rankIndex[strlower(name)]
	if not row then return nil end
	local st = rankState[row.spell]
	if not st then
		st = { ids = {}, tries = 0, kept = 0, dropped = 0, pending = #row.ids }
		rankState[row.spell] = st
	end
	if st.pending > 0 and st.tries < 4 then
		st.tries = st.tries + 1
		st.kept, st.dropped, st.pending = 0, 0, 0
		local want = strlower(row.spell)
		for _, id in ipairs(row.ids) do
			local n = ns.SpellInfo(id)
			if n and strlower(n) == want then
				st.ids[id] = true
				st.kept = st.kept + 1
			elseif n then
				st.dropped = st.dropped + 1
			else
				st.pending = st.pending + 1
				if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
			end
		end
	end
	if st.kept == 0 then return nil end
	return st.ids
end

-- ------------------------------------------------------------------
-- Saved settings, per character
-- ------------------------------------------------------------------
local DEFAULTS = {
	shown = true,
	scale = 1,
	alpha = 1,
	reserve = 25,    -- per cent of maximum health to keep back after a tap
	manaAt = 50,     -- only speak up once mana is at or below this per cent
	tickPct = 2,     -- a gain smaller than this share of maximum health is not somebody's heal
	rank = nil,      -- nil: the highest rank of Life Tap this character knows
	cost = nil,      -- overrides what the client says a tap costs
	sndApplied = 0,  -- handed to the game: fires the moment a listed heal lands, in combat too
	sndLapsed = 0,   -- ditto for one running out
	sndEstimate = 0, -- played by this addon when the tick clock notices a heal the game never named
	sndReady = 0,    -- played by this addon when the panel turns to TAP
	bars = true,     -- ask the game to draw the heal bars
	barX = nil, barY = nil,
}
ns.DEFAULTS = DEFAULTS

local function CharKey()
	local name = (UnitName and UnitName("player")) or "Unknown"
	local realm = (GetRealmName and GetRealmName()) or "Realm"
	return tostring(name) .. "-" .. tostring(realm)
end

function ns.InitDB()
	if type(TaplineDB) ~= "table" then TaplineDB = {} end
	TaplineDB.chars = type(TaplineDB.chars) == "table" and TaplineDB.chars or {}
	local key = CharKey()
	local p = type(TaplineDB.chars[key]) == "table" and TaplineDB.chars[key] or {}
	TaplineDB.chars[key] = p
	for k, v in pairs(DEFAULTS) do
		if p[k] == nil then p[k] = v end
	end
	ns.db, ns.p, ns.charKey = TaplineDB, p, key
	return p
end

local function Profile() return ns.p end
ns.Profile = Profile

-- ------------------------------------------------------------------
-- State
-- ------------------------------------------------------------------
local S = {
	ticks = {},
	hot = {},
	own = {},
	stats = { driver = 0, samples = 0, gains = 0, small = 0, mine = 0, refills = 0, heals = 0, runs = 0, awake = 0 },
}
ns.state = S

-- True while this client is hiding aura data, which is when the estimate has to stand in for a
-- reading. Where the aura can be read, the estimator is left off: health regenerating on its own
-- out of combat ticks at a size not far off a low-rank heal, and would read as a healer.
function ns.Blind()
	return ns.AurasSecret() or S.auraReadFailed == true
end
local Blind = ns.Blind

-- ------------------------------------------------------------------
-- Health and mana
--
-- These are not aura data, so the expectation is that they can be read in combat like any other
-- number. Whether that holds on this client is the single thing the whole panel rests on, so each
-- read keeps its refusal and the panel shows it rather than saying "unreadable".
-- ------------------------------------------------------------------
-- Where a health or mana bar might be found. The player frame is not the object it used to be on
-- this client, and a name that was right for years is worth nothing here, so every candidate is
-- tried and the report says which of them exist at all.
ns.BAR_PATHS = {
	health = {
		"PlayerFrameHealthBar",
		"PlayerFrame.healthbar",
		"PlayerFrame.HealthBar",
		"PlayerFrame.healthBar",
		"PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar",
		"PlayerFrame.healthBarContainer.healthBar",
	},
	mana = {
		"PlayerFrameManaBar",
		"PlayerFrame.manabar",
		"PlayerFrame.ManaBar",
		"PlayerFrame.manaBar",
		"PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar",
	},
}

-- Walks a dotted path from the globals. Every step is guarded: an index on a forbidden object is
-- an error here, not a nil.
function ns.Resolve(path)
	local obj = _G
	for part in tostring(path):gmatch("[^%.]+") do
		if type(obj) ~= "table" then return nil end
		local ok, v = pcall(function() return obj[part] end)
		if not ok or v == nil then return nil end
		obj = v
	end
	return obj
end

-- The first bar on the list that will give up a pair of plain numbers.
local function FromBar(which)
	local tried = {}
	for _, path in ipairs(ns.BAR_PATHS[which] or {}) do
		local bar = ns.Resolve(path)
		if not bar then
			tried[#tried + 1] = path .. " (missing)"
		else
			local v, why = Read(bar.GetValue, bar)
			if not v then
				tried[#tried + 1] = path .. " " .. tostring(why)
			else
				local ok, _, hi = pcall(bar.GetMinMaxValues, bar)
				hi = ok and Clean(hi) or nil
				if type(hi) == "number" and hi > 0 then
					ns.report[which .. " bar"] = path
					return v, hi, nil
				end
				tried[#tried + 1] = path .. " has no maximum"
			end
		end
	end
	return nil, nil, "no bar to read either (" .. table.concat(tried, "; ") .. ")"
end

function ns.ReadVitals()
	local hp, hpWhy = Read(UnitHealth, "player")
	local hpMax, maxWhy = Read(UnitHealthMax, "player")
	local source = "UnitHealth"
	if not hp or not hpMax or hpMax <= 0 then
		local why = hpWhy or maxWhy or "gave nothing"
		local v, hi, barWhy = FromBar("health")
		if v and hi then
			hp, hpMax, source = v, hi, "the player frame's bar"
			S.hpWhy = "UnitHealth " .. why .. ", reading the player frame instead"
		else
			hp, hpMax = nil, nil
			S.hpWhy = "UnitHealth " .. why .. "; " .. tostring(barWhy)
		end
	else
		S.hpWhy = nil
	end
	-- Last resort: a percentage. Nameplates need one, so it may be open where the number is not,
	-- and it is enough for both things that matter. A floor reads as well in per cent ("never tap
	-- under 40") and the tick clock only ever cared how big a jump was against your maximum.
	S.percentOnly = false
	if not hp and UnitPercentHealthFromGUID and UnitGUID then
		local okG, guid = pcall(UnitGUID, "player")
		guid = okG and Clean(guid) or nil
		if guid then
			local pct = Read(UnitPercentHealthFromGUID, guid)
			if pct and pct > 0 then
				hp, hpMax, source = pct, 100, "a percentage only"
				S.percentOnly = true
				S.hpWhy = nil
			end
		end
	end
	S.hpSource = hp and source or nil

	local mana = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
	local mp, mpWhy = Read(UnitPower, "player", mana)
	local mpMax, mpMaxWhy = Read(UnitPowerMax, "player", mana)
	if not mp or not mpMax or mpMax <= 0 then
		local why = mpWhy or mpMaxWhy or "gave nothing"
		local v, hi, barWhy = FromBar("mana")
		if v and hi then
			mp, mpMax = v, hi
			S.mpWhy = "UnitPower " .. why .. ", reading the player frame instead"
		else
			mp, mpMax = nil, nil
			S.mpWhy = "UnitPower " .. why .. "; " .. tostring(barWhy)
		end
	else
		S.mpWhy = nil
	end

	S.incoming = Read(UnitGetIncomingHeals, "player")
	return hp, hpMax, mp, mpMax
end

-- ------------------------------------------------------------------
-- Heals over time: reading the aura
-- ------------------------------------------------------------------
local MAX_AURA_INDEX = 40

-- The live heal over time on you, where this client will part with it. Returns name, seconds left
-- and the row from the list. Sets S.auraReadFailed, which is what turns the estimate on.
function ns.ReadHot()
	if ns.AurasSecret() then S.auraReadFailed = true return nil end
	local C = C_UnitAuras
	if not C then S.auraReadFailed = true return nil end
	local now = GetTime()
	local best, bestRow, bestLeft
	local answered = false

	-- By name first: one call per heal, and no walking a list that may be full of secrets.
	if C.GetAuraDataBySpellName then
		for _, row in ipairs(ns.HOTS or {}) do
			local ok, a = pcall(C.GetAuraDataBySpellName, "player", row.name, "HELPFUL")
			if ok then
				if type(a) == "table" and not (issecretvalue and issecretvalue(a)) then
					-- A table whose own fields are secret is not an answer, it is a refusal wearing
					-- a table, and believing it would report a heal with no time on it forever.
					local name = Clean(a.name)
					if name then
						answered = true
						local expires = Clean(a.expirationTime)
						local left = (type(expires) == "number" and expires > 0) and (expires - now) or nil
						if not best or (left or 0) > (bestLeft or 0) then best, bestRow, bestLeft = name, row, left end
					end
				elseif a == nil then
					-- Nothing on you under that name is a real answer, and the commonest one.
					answered = true
				end
			end
		end
	end
	if best then S.auraReadFailed = false return best, bestLeft, bestRow end

	-- Otherwise walk the buffs. Guarded per index: asking for a secret one is an error here, not a
	-- secret answer, and one error would take the whole sweep down.
	if C.GetAuraDataByIndex then
		local wanted = {}
		for _, row in ipairs(ns.HOTS or {}) do wanted[strlower(row.name)] = row end
		for i = 1, MAX_AURA_INDEX do
			local secret = false
			if C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret then
				local okS, v = pcall(C_Secrets.ShouldUnitAuraIndexBeSecret, "player", i, "HELPFUL")
				secret = (not okS) or Clean(v) ~= false
			end
			if not secret then
				local ok, a = pcall(C.GetAuraDataByIndex, "player", i, "HELPFUL")
				if not ok then break end
				answered = true
				if type(a) ~= "table" then break end
				local name = Clean(a.name)
				local row = name and wanted[strlower(name)]
				if row then
					local expires = Clean(a.expirationTime)
					local left = (type(expires) == "number" and expires > 0) and (expires - now) or nil
					if not best or (left or 0) > (bestLeft or 0) then best, bestRow, bestLeft = name, row, left end
				end
			end
		end
	end
	S.auraReadFailed = not answered
	return best, bestLeft, bestRow
end

-- ------------------------------------------------------------------
-- Heals over time: the estimate
-- ------------------------------------------------------------------
local MIN_PERIOD, MAX_PERIOD = 2.2, 3.9
local LAPSE_GRACE = 1.6
local REFILL_SHARE = 0.5

-- A cast of yours that heals you over the next few seconds. Its gains are yours, not a healer's.
function ns.NoteOwnCast(spellId)
	local name = ns.SpellInfo(spellId)
	if type(name) ~= "string" then return end
	local l = strlower(name)
	for key, window in pairs(ns.OWN_HEALS or {}) do
		if l:find(key, 1, true) then
			S.own[key] = GetTime() + window
			S.ownName = name
			return key
		end
	end
end

local function OwnWindow(now)
	local open
	for key, until_ in pairs(S.own) do
		if until_ and until_ > now then open = key else S.own[key] = nil end
	end
	return open
end

-- One reading of health and mana. Everything the estimate knows comes from the gaps between these.
function ns.Sample(now)
	local hp, hpMax, mp, mpMax = ns.ReadVitals()
	if not hp or not hpMax or hpMax <= 0 then
		S.readable = false
		return
	end
	S.readable = true
	S.stats.samples = S.stats.samples + 1
	local lastHp, lastMax = S.hp, S.hpMax
	S.hp, S.hpMax, S.mp, S.mpMax = hp, hpMax, mp, mpMax
	-- A buff that raises your maximum raises the current health with it, and that is not a heal.
	if not lastHp or lastMax ~= hpMax then return end
	local gain = hp - lastHp
	if gain <= 0 then return end
	S.stats.gains = S.stats.gains + 1
	if gain > hpMax * REFILL_SHARE then
		S.stats.refills = S.stats.refills + 1
		return
	end
	local p = Profile()
	local least = max(1, hpMax * ((p and p.tickPct) or DEFAULTS.tickPct) / 100)
	if gain < least then
		S.stats.small = S.stats.small + 1
		S.lastSmall = gain
		return
	end
	local own = OwnWindow(now)
	if own then
		S.stats.mine = S.stats.mine + 1
		S.lastMineAt, S.lastMineKey = now, own
		return
	end
	if not Blind() then
		-- The aura itself can be read out here, so there is nothing to guess at, and guessing would
		-- turn ordinary health regeneration into a healer.
		S.stats.awake = S.stats.awake + 1
		return
	end
	ns.HealTick(now, gain)
end

function ns.HealTick(now, amount)
	S.stats.heals = S.stats.heals + 1
	S.lastHeal = { at = now, amount = amount }
	local ticks = S.ticks
	local prev = ticks[#ticks]
	ticks[#ticks + 1] = { at = now, amount = amount }
	while #ticks > 10 do table.remove(ticks, 1) end
	if not prev then return end
	local gap = now - prev.at
	if gap < MIN_PERIOD or gap > MAX_PERIOD then return end
	local hot = S.hot
	if not hot.active then
		hot.active = true
		hot.startedAt = prev.at
		hot.name, hot.duration = ns.NameFor()
		S.stats.runs = S.stats.runs + 1
		local p = Profile()
		-- The game already plays its own sound the instant a heal it was handed an id for lands, so
		-- this one is silent by default: turned on it fires a few seconds later, on the second tick,
		-- and earns its place only for heals the game never announced.
		if p and (p.sndEstimate or 0) > 0 then ns.PlaySound(p.sndEstimate) end
	end
	hot.period = gap
	hot.lastTick = now
	hot.amount = amount
	hot.expires = (hot.startedAt or now) + (hot.duration or 15)
	-- A heal still ticking has not finished, whatever the guessed duration said.
	if hot.expires < now + gap then hot.expires = now + gap end
end

-- What to call a run of ticks. A heal actually read off you in the last minute is the best answer;
-- failing that the longest of the known heals, so the time errs towards more rather than less.
function ns.NameFor()
	local seen = S.seen
	if seen and seen.at and GetTime() - seen.at < 60 then return seen.name, seen.duration end
	local longest
	for _, row in ipairs(ns.HOTS or {}) do
		if not longest or row.duration > longest.duration then longest = row end
	end
	return "a heal over time", longest and longest.duration or 15
end

function ns.CheckLapse(now)
	local hot = S.hot
	if not hot.active then return end
	-- No sound on a lapse: the game plays that one itself, off the aura going away rather than off
	-- a tick that merely failed to show up.
	if now > (hot.lastTick or 0) + (hot.period or 3) + LAPSE_GRACE then hot.active = false end
end

-- ------------------------------------------------------------------
-- What a tap costs
-- ------------------------------------------------------------------
-- The ranks of Life Tap this character has, highest last.
function ns.TapRanks()
	local ids = ns.Ranks("Life Tap")
	local all = (ns.RANK_IDS and ns.RANK_IDS["Life Tap"]) or {}
	local list = {}
	for _, id in ipairs(all) do
		if not ids or ids[id] then
			local known = true
			if IsSpellKnown then
				local ok, v = pcall(IsSpellKnown, id)
				if ok then known = Clean(v) == true end
			elseif IsPlayerSpell then
				local ok, v = pcall(IsPlayerSpell, id)
				if ok then known = Clean(v) == true end
			end
			if known then list[#list + 1] = id end
		end
	end
	if #list == 0 then
		-- The client would not say which ranks you have, so take them all and let the panel show
		-- which one it settled on.
		for _, id in ipairs(all) do
			if not ids or ids[id] then list[#list + 1] = id end
		end
		S.rankGuess = true
	else
		S.rankGuess = false
	end
	return list
end

-- Held for a few seconds: the panel asks ten times a second and the answer involves the spellbook.
local costCache = {}
function ns.Cost()
	local p = Profile()
	local now = GetTime()
	if costCache.at and costCache.rank == (p and p.rank) and costCache.set == (p and p.cost)
		and now - costCache.at < 5 then
		return costCache.cost, costCache.why
	end
	local cost, why = ns.ReckonCost()
	costCache = { at = now, rank = p and p.rank, set = p and p.cost, cost = cost, why = why }
	return cost, why
end

function ns.ReckonCost()
	local p = Profile()
	if p and tonumber(p.cost) then return tonumber(p.cost), "set by you" end
	local id = p and tonumber(p.rank)
	if not id then
		local list = ns.TapRanks()
		id = list[#list]
	end
	if not id then return nil, "no rank of Life Tap found" end
	S.rankId = id
	-- The client's own words first: the description carries the real number.
	if C_Spell and C_Spell.GetSpellDescription then
		local ok, text = pcall(C_Spell.GetSpellDescription, id)
		text = ok and Clean(text) or nil
		if type(text) == "string" then
			local n = tonumber(text:match("(%d+)"))
			if n and n > 0 then return n, "the spell's own description" end
		end
	end
	local known = ns.LIFE_TAP_COST and ns.LIFE_TAP_COST[id]
	if known then return known, "written down for rank " .. tostring(id) end
	return nil, "unknown for spell " .. tostring(id)
end

-- ------------------------------------------------------------------
-- The answer
-- ------------------------------------------------------------------
-- What is known about healing arriving: a key, a line, and the seconds left when there is a number.
-- Worked out once a frame, since the verdict and the panel both want it and reading auras is the
-- expensive part.
function ns.Incoming()
	local now = GetTime()
	local memo = S.incomingMemo
	if memo and memo.at == now then return memo[1], memo[2], memo[3] end
	local a, b, c = ns.ReckonIncoming(now)
	S.incomingMemo = { a, b, c, at = now }
	return a, b, c
end

function ns.ReckonIncoming(now)
	local name, left, row = ns.ReadHot()
	if name then
		S.seen = { name = name, duration = row and row.duration or 15, at = now }
		if left and left > 0 then
			return "read", ("%s, %s left"):format(name, ns.FormatTime(left)), left
		end
		return "read", tostring(name), nil
	end
	local hot = S.hot
	if hot.active then
		local remaining = max(0, (hot.expires or now) - now)
		local nextIn = max(0, ((hot.lastTick or now) + (hot.period or 3)) - now)
		return "estimated", ("~ %s, about %s left, next tick %.1fs"):format(
			hot.name or "a heal", ns.FormatTime(remaining), nextIn), remaining
	end
	if S.incoming and S.incoming > 0 then
		return "cast", ("a heal of about %d is on its way"):format(S.incoming), nil
	end
	if Blind() then return "none", "nothing seen, and auras are hidden here", nil end
	return "none", "nothing on you", nil
end

-- Returns a key, the reasoning, and how many taps your floor leaves room for.
--   tap     health to spare and something is healing you
--   ok      health to spare, nothing coming
--   wait    a tap would put you under your own floor
--   spare   mana is fine, so there is nothing to ask
--   unknown the client would not say
function ns.Verdict()
	local p = Profile()
	if not p then return "unknown", "not loaded yet", 0 end
	local hp, hpMax = S.hp, S.hpMax
	if not S.readable or not hp or not hpMax or hpMax <= 0 then
		return "unknown", S.hpWhy or "this client will not say what your health is", 0
	end
	local cost = ns.Cost()
	local reserve = hpMax * (p.reserve or 25) / 100
	-- Mana that cannot be read must not be taken for mana you have. Assuming a full bar would
	-- mean answering "no need" for the whole of a fight on a client that keeps mana secret, which
	-- is the one answer that is certainly wrong. Unknown mana simply drops the question.
	local manaKnown = S.mp and S.mpMax and S.mpMax > 0
	local manaPct = manaKnown and (S.mp / S.mpMax * 100) or nil
	-- With only a percentage to go on there is no arithmetic to do on the cost: what a tap takes is
	-- a number of health and how much health you have is secret. The floor still works, because a
	-- floor is a percentage already, so the answer becomes "above your floor or not".
	if S.percentOnly then
		if hp <= reserve then
			return "wait", ("below your floor of %d%%"):format(p.reserve or 25), nil
		end
		if manaKnown and manaPct > (p.manaAt or 50) then
			return "spare", ("mana is above %d%%"):format(p.manaAt or 50), nil
		end
		local kind, label = ns.Incoming()
		if kind == "read" or kind == "estimated" or kind == "cast" then return "tap", label, nil end
		return "ok", "above your floor, nothing healing you", nil
	end
	if not cost or cost <= 0 then
		return "unknown", "no Life Tap rank found: /tapline cost <health>", 0
	end
	local room = floor((hp - reserve) / cost)
	if room < 0 then room = 0 end
	-- Mana first, so the red reading means something: there is no decision to make while the mana
	-- is there, whatever the health is doing.
	if manaKnown and manaPct > (p.manaAt or 50) then
		return "spare", ("mana is above %d%%"):format(p.manaAt or 50), room
	end
	if room < 1 then
		return "wait", ("a tap costs %d and your floor is %d%%"):format(cost, p.reserve or 25), 0
	end
	local kind, label = ns.Incoming()
	if kind == "read" or kind == "estimated" or kind == "cast" then return "tap", label, room end
	return "ok", "nothing is healing you", room
end

function ns.FormatTime(sec)
	if sec >= 3600 then return ("%dh"):format(floor(sec / 3600 + 0.5)) end
	if sec >= 60 then return ("%dm"):format(floor(sec / 60 + 0.5)) end
	if sec >= 10 then return ("%d"):format(floor(sec + 0.5)) end
	return ("%.1f"):format(sec)
end

-- ------------------------------------------------------------------
-- Sounds
-- ------------------------------------------------------------------
-- Played by this addon. Fine out of combat and fine in combat, since it is worked out from health
-- and mana rather than from an aura.
function ns.PlaySound(n)
	local c = ns.SOUNDS[n or 0]
	if not c then return nil, false end
	local id = (SOUNDKIT and SOUNDKIT[c[2]]) or c[3]
	local ok, willPlay = pcall(PlaySound, id, "SFX")
	ns.report["last sound"] = ("%s (kit %s) -> %s"):format(c[1], tostring(id), tostring(ok and willPlay))
	return c[1], ok and willPlay
end

-- Played by the GAME. C_UnitAuras.AddAuraSound registers a sound file against a spell id and a
-- trigger, and the client plays it itself, in combat too, where this addon cannot see the aura at
-- all. Nothing comes back: there is no callback, so the sound is all the alert there is. One
-- registration per rank per trigger, because the call takes an id rather than a name.
local regs = {}
ns.soundStats = { registered = 0, failed = 0, cleared = 0, lastError = nil }

-- Registrations live in the game, not in Lua: a reload forgets them here but not there. Their ids
-- are kept in the saved variables and removed on the next load before registering afresh.
function ns.ClearStaleSounds()
	local C = C_UnitAuras
	if not (C and C.RemoveAuraSound) or not ns.db then return end
	local old = ns.db.soundIds
	ns.db.soundIds = {}
	if type(old) ~= "table" then return end
	for _, id in pairs(old) do
		if pcall(C.RemoveAuraSound, id) then ns.soundStats.cleared = ns.soundStats.cleared + 1 end
	end
end

function ns.SyncSounds()
	local C = C_UnitAuras
	local p = Profile()
	if not (C and C.AddAuraSound and C.RemoveAuraSound) or not p then
		ns.report["aura sounds"] = "C_UnitAuras.AddAuraSound is not on this client"
		return
	end
	local trig = (Enum and Enum.UnitAuraSoundTrigger) or {}
	local triggers = { applied = trig.Added or 0, removed = trig.Removed or 2 }
	local picks = { applied = p.sndApplied, removed = p.sndLapsed }
	local wanted = {}
	for ev, trigger in pairs(triggers) do
		local choice = ns.SOUNDS[picks[ev] or 0]
		local file = choice and choice[4]
		if file then
			for _, row in ipairs(ns.HOTS or {}) do
				local ids = ns.Ranks(row.name)
				if ids then
					for id in pairs(ids) do
						wanted[("player:%d:%s:%d"):format(id, tostring(trigger), file)] =
							{ id = id, trigger = trigger, file = file }
					end
				end
			end
		end
	end
	for key, regId in pairs(regs) do
		if not wanted[key] then
			pcall(C.RemoveAuraSound, regId)
			regs[key] = nil
			if ns.db.soundIds then ns.db.soundIds[key] = nil end
			ns.soundStats.registered = ns.soundStats.registered - 1
		end
	end
	for key, w in pairs(wanted) do
		if not regs[key] then
			local ok, regId = pcall(C.AddAuraSound, w.trigger,
				{ unitToken = "player", spellID = w.id, soundFileID = w.file, outputChannel = "Master" })
			if ok and regId then
				regs[key] = regId
				ns.db.soundIds = ns.db.soundIds or {}
				ns.db.soundIds[key] = regId
				ns.soundStats.registered = ns.soundStats.registered + 1
			else
				ns.soundStats.failed = ns.soundStats.failed + 1
				ns.soundStats.lastError = tostring(regId)
			end
		end
	end
	ns.report["aura sounds"] = ("%d registered, %d refused"):format(ns.soundStats.registered, ns.soundStats.failed)
end

-- ------------------------------------------------------------------
-- The driver
--
-- One frame, events and a tick. The panel is polled rather than driven off UNIT_HEALTH alone,
-- because a client is not obliged to raise an event for every change and the estimate is only as
-- good as the sampling behind it. The count of ticks is kept, so "/tapline debug" can say whether
-- this is running at all: a panel that never updates and a client that refuses to answer look
-- exactly alike from the outside.
-- ------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.events = ev
local loaded = false

local function Startup()
	if loaded then return end
	loaded = true
	ns.InitDB()
	ns.ClearStaleSounds()
	ns.Sample(GetTime())
	if ns.Panel then ns.Panel:Init() end
	ns.SyncSounds()
	if C_Timer and C_Timer.After then
		C_Timer.After(2, function()
			for _, row in ipairs(ns.HOTS or {}) do ns.Ranks(row.name) end
			ns.Ranks("Life Tap")
			ns.SyncSounds()
			if ns.Panel then ns.Panel:BuildBars() end
		end)
	end
end
ns.Startup = Startup

function ns.OnEvent(event, a1, _, a3)
	if event == "ADDON_LOADED" then
		if a1 == ADDON then ns.InitDB() end
		return
	elseif event == "PLAYER_LOGIN" then
		Startup()
		return
	end
	if not loaded then return end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if a1 == "player" then ns.NoteOwnCast(a3) end
	elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" then
		if a1 == "player" then ns.Sample(GetTime()) end
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		-- Crossing in or out of a fight changes which answer is the good one; a carried estimate
		-- would only argue with the aura that can now be read.
		S.hot, S.ticks = {}, {}
		ns.Sample(GetTime())
		if event == "PLAYER_REGEN_ENABLED" and ns.Panel then ns.Panel:BuildBars() end
	elseif event == "PLAYER_ENTERING_WORLD" then
		S.hot, S.ticks = {}, {}
		S.hp, S.hpMax = nil, nil
		ns.Sample(GetTime())
		if ns.Panel then ns.Panel:BuildBars() end
	elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
		S.incomingMemo = nil
	end
end

ev:SetScript("OnEvent", function(_, event, a1, a2, a3) ns.OnEvent(event, a1, a2, a3) end)
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_SPELLCAST_SUCCEEDED",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
	"ADDON_RESTRICTION_STATE_CHANGED" }) do
	local ok = pcall(ev.RegisterEvent, ev, event)
	ns.report["event " .. event] = ok and "ok" or "refused"
end

local acc = 0
function ns.OnUpdate(elapsed)
	S.stats.driver = S.stats.driver + 1
	if not loaded then return end
	acc = acc + elapsed
	if acc < 0.1 then return end
	acc = 0
	local now = GetTime()
	ns.Sample(now)
	ns.CheckLapse(now)
	if ns.Panel then ns.Panel:Refresh(now) end
end
ev:SetScript("OnUpdate", function(_, elapsed) ns.OnUpdate(elapsed) end)
ev:Show()
