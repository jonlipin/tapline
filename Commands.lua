-- Tapline's commands, and the self report.
--
-- The report is the important half. This addon cannot be tested against the real client from
-- outside it, and on a client that hides things from addons "it did not work" is never the useful
-- part of the answer: which call was refused, and in what words, is. So /tapline debug walks every
-- API this addon leans on and prints what each one actually did.

local ADDON, ns = ...

local Print, YesNo, Clean = ns.Print, ns.YesNo, ns.Clean
local floor, max, min = math.floor, math.max, math.min

-- ------------------------------------------------------------------
-- The probe
-- ------------------------------------------------------------------
-- Each row: a label, the global's name, and a call to try. The name is checked separately from the
-- call, because a function that is missing and a function that refuses are different problems.
local PROBES = {
	-- First, whether the secret test itself can be trusted. If issecretvalue says a plain 1 is
	-- secret then nothing below means anything, and the fault is here rather than in the client.
	{ "issecretvalue(1)",      "issecretvalue",         function() return issecretvalue(1) end },
	{ "issecretvalue('x')",    "issecretvalue",         function() return issecretvalue("x") end },
	{ "UnitHealth(player)",    "UnitHealth",            function() return UnitHealth("player") end },
	{ "UnitHealthMax(player)", "UnitHealthMax",         function() return UnitHealthMax("player") end },
	{ "UnitHealth(target)",    "UnitHealth",            function() return UnitHealth("target") end },
	{ "UnitHealth(pet)",       "UnitHealth",            function() return UnitHealth("pet") end },
	{ "UnitPower (mana)",      "UnitPower",             function() return UnitPower("player", (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0) end },
	{ "UnitPowerMax (mana)",   "UnitPowerMax",          function() return UnitPowerMax("player", (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0) end },
	{ "UnitPercentHealth",     "UnitPercentHealthFromGUID", function() return UnitPercentHealthFromGUID(UnitGUID("player")) end },
	{ "UnitGetIncomingHeals",  "UnitGetIncomingHeals",  function() return UnitGetIncomingHeals("player") end },
	{ "UnitLevel(player)",     "UnitLevel",             function() return UnitLevel("player") end },
	{ "InCombatLockdown",      "InCombatLockdown",      function() return InCombatLockdown() end },
	{ "AurasSecret",           "C_Secrets",             function() return C_Secrets.ShouldAurasBeSecret() end },
	{ "IsSpellKnown(Life Tap)", "IsSpellKnown",         function() return IsSpellKnown(11689) end },
}

local function Describe(fn)
	local ok, v = pcall(fn)
	if not ok then
		if issecretvalue and issecretvalue(v) then return "|cffff5050refused with a secret value|r" end
		local okT, text = pcall(tostring, v)
		text = okT and text or "?"
		return "|cffff5050refused|r: " .. (text:gsub("^.-%.lua:%d+:%s*", ""))
	end
	if issecretvalue and issecretvalue(v) then return "|cffff9040secret value|r" end
	if v == nil then return "|cffff9040nil|r" end
	return "|cff40ff40" .. type(v) .. "|r " .. tostring(v)
end

function ns.Probe()
	Print("what this client will say:")
	for _, row in ipairs(PROBES) do
		local exists = _G[row[2]] ~= nil
		Print(("  %-24s global %s, call %s"):format(row[1], YesNo(exists), exists and Describe(row[3]) or "not tried"))
	end
	-- The player frame has been rebuilt more than once and the old global names are worth nothing
	-- here, so every candidate is walked and reported: something on this list may still be readable
	-- even when the plain call is not.
	Print("  bars the health might be read off instead:")
	for which, paths in pairs(ns.BAR_PATHS or {}) do
		for _, path in ipairs(paths) do
			local bar = ns.Resolve(path)
			Print(("    %-12s %-62s %s"):format(which, path,
				bar and ("found, value " .. Describe(function() return bar:GetValue() end)) or "|cffff5050missing|r"))
		end
	end
	-- Where the frames actually are. Everything above can report success while nothing is on
	-- screen, because building a row and putting it somewhere visible are different problems, and
	-- guessing which one has gone wrong has already cost two rounds.
	local function Where(label, f)
		if not f then Print(("    %-14s |cffff5050does not exist|r"):format(label)) return end
		local okS, isShown = pcall(function() return f:IsShown() end)
		local okV, isVis = pcall(function() return f:IsVisible() end)
		local okR, l, t, w, h = pcall(function() return f:GetLeft(), f:GetTop(), f:GetWidth(), f:GetHeight() end)
		local okP, points = pcall(function() return f:GetNumPoints() end)
		local okA, alpha = pcall(function() return f.GetEffectiveAlpha and f:GetEffectiveAlpha() or f:GetAlpha() end)
		local okC, scale = pcall(function() return f:GetEffectiveScale() end)
		Print(("    %-14s shown %s, visible %s, anchors %s, at %s,%s size %sx%s, alpha %s, scale %s"):format(
			label,
			okS and tostring(isShown) or "?", okV and tostring(isVis) or "?",
			okP and tostring(points) or "?",
			okR and tostring(Clean(l) and floor(Clean(l)) or l) or "?",
			okR and tostring(Clean(t) and floor(Clean(t)) or t) or "?",
			okR and tostring(Clean(w) and floor(Clean(w)) or w) or "?",
			okR and tostring(Clean(h) and floor(Clean(h)) or h) or "?",
			okA and tostring(alpha) or "?", okC and tostring(scale) or "?"))
	end
	Print("  where the frames actually are:")
	Where("bars holder", ns.Panel and ns.Panel.bars)
	Where("container", ns.Panel and ns.Panel.container)
	for i, cell in ipairs((ns.Panel and ns.Panel.cells) or {}) do
		Where("cell " .. i, cell)
		Where("  its bar", cell.bar)
		Where("  its icon", cell.icon)
	end
	local slots = ns.Panel and ns.Panel.container and rawget(ns.Panel.container, "slots")
	if type(slots) == "table" then
		for key, slot in pairs(slots) do
			-- The slot frame is forbidden, so even asking where it is has to be guarded.
			Where("slot " .. tostring(key), slot.frame)
		end
	end
	Print(("    refreshes: panel %d, bars %d"):format(ns.state.stats.refresh or 0, ns.state.stats.barRefresh or 0))

	if next(ns.slotCalls or {}) then
		Print("  what the game let us hand to a slot:")
		for method, result in pairs(ns.slotCalls) do
			Print(("    %-22s %s"):format(method, result == "ok" and "|cff40ff40ok|r" or ("|cffff5050" .. tostring(result) .. "|r")))
		end
	end
end

function ns.Debug()
	local S, p = ns.state, ns.Profile()
	Print("v" .. ns.VERSION .. " on " .. tostring(ns.charKey))
	if not p then Print("  |cffff5050the saved settings never loaded|r") return end

	-- The decisive number. A panel that never updates and a client that refuses to answer look
	-- exactly alike from the outside, and this tells them apart at a glance.
	Print(("  driver: %d frames, %d health reads; bars %s, container %s"):format(
		S.stats.driver, S.stats.samples, YesNo(ns.Panel and ns.Panel.bars), YesNo(ns.Panel and ns.Panel.container)))
	if S.stats.driver == 0 then Print("  |cffff5050the tick is not running at all, which is the first thing to fix|r") end

	ns.Probe()
	Print(("  what it settled on: health %s, mana %s"):format(
		(S.hp and S.hpMax) and (tostring(S.hp) .. "/" .. tostring(S.hpMax) .. " via " .. tostring(S.hpSource)) or ("|cffff5050none|r (" .. tostring(S.hpWhy) .. ")"),
		(S.mp and S.mpMax) and (tostring(S.mp) .. "/" .. tostring(S.mpMax)) or ("|cffff5050none|r (" .. tostring(S.mpWhy) .. ")")))

	Print(("  maximums, which are NOT secret here: health %s, mana %s, level %s"):format(
		tostring(S.hpMaxApi), tostring(S.mpMaxApi), tostring(select(1, ns.Read(UnitLevel, "player")))))
	local cost, why = ns.Cost()
	Print(("  a tap costs %s (%s)%s"):format(tostring(cost), tostring(why),
		S.rankGuess and ", though the client would not say which ranks you know" or ""))
	-- Which ranks this character actually has, and what the client says each one does. The cost is
	-- read out of that description, so when the number looks wrong this is where to look.
	for i, id in ipairs((ns.RANK_IDS and ns.RANK_IDS["Life Tap"]) or {}) do
		local known = ns.Read(function() return IsSpellKnown(id) and 1 or 0 end)
		local text
		if C_Spell and C_Spell.GetSpellDescription then
			local okD, d = pcall(C_Spell.GetSpellDescription, id)
			d = okD and Clean(d) or nil
			text = type(d) == "string" and d:gsub("%s+", " "):sub(1, 90) or tostring(d)
		end
		Print(("    rank %d (%d): known %s, description %s"):format(i, id,
			known == nil and "would not say" or (known == 1 and "yes" or "no"), tostring(text)))
	end
	Print(("  auras: secret right now %s, last read %s, so the answer is %s"):format(
		YesNo(ns.AurasSecret()), S.auraReadFailed and "|cffff5050refused|r" or "allowed",
		ns.Blind() and "estimated" or "read"))
	local st = S.stats
	Print(("  gains seen %d: %d too small, %d your own, %d refills, %d while the aura was readable, %d counted as a healer's (%d runs)"):format(
		st.gains, st.small, st.mine, st.refills, st.awake, st.heals, st.runs))
	local hot = S.hot
	if hot.active then
		Print(("  estimate running: %s, period %.2fs, last tick %.1fs ago, about %s left"):format(
			tostring(hot.name), hot.period or 0, GetTime() - (hot.lastTick or 0),
			ns.FormatTime(max(0, (hot.expires or 0) - GetTime()))))
	else
		Print("  estimate: nothing running")
	end
	local kind, line = ns.Incoming()
	Print(("  incoming says: [%s] %s"):format(kind, line))
	for _, row in ipairs(ns.HOTS or {}) do
		local st2 = ns.rankState and ns.rankState[row.name]
		Print(("  %s: %s ranks agreed, %s dropped, %s still unknown after %s tries"):format(row.name,
			st2 and st2.kept or "?", st2 and st2.dropped or "?", st2 and st2.pending or "?", st2 and st2.tries or "?"))
	end
	local ss = ns.soundStats
	Print(("  sounds: applied %d, lapsed %d, estimate %d; %d handed to the game, %d refused%s"):format(
		p.sndApplied or 0, p.sndLapsed or 0, p.sndEstimate or 0,
		ss.registered, ss.failed, ss.lastError and (" (" .. tostring(ss.lastError) .. ")") or ""))
	local keys = {}
	for k in pairs(ns.report) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do Print("  " .. k .. ": " .. tostring(ns.report[k])) end
end

-- ------------------------------------------------------------------
-- Commands
-- ------------------------------------------------------------------
local function SoundList()
	Print("  0 - silent")
	for i, c in ipairs(ns.SOUNDS) do
		Print(("  %d - %s%s"):format(i, c[1], c[4] and " |cff40ff40(combat)|r" or ""))
	end
end

function ns.Usage()
	local p = ns.Profile() or {}
	Print("v" .. ns.VERSION .. ", commands:")
	Print("  /tapline - open the options page, in the game's own options window where it will")
	Print("  /tapline learn <spell id or link> - teach it a heal this client has that it cannot name")
	Print("  /tapline forget - throw away every learned spell id and start again")
	Print("  /tapline minimap - show or hide the button on the minimap")
	Print("  /tapline gap <-40-40> | rowgap <-20-30> - room beside the icon, and between rows")
	Print("  /tapline edge - always draw a frame round the bar, even if the client gave us one")
	Print("  /tapline spark - the mark at the end of the fill, on or off")
	Print("  /tapline sparksize <0.5-4> - how big it is against the bar")
	Print("  /tapline shadow <0-4> - how deep the shadow round an icon is")
	Print("  /tapline rate <5-60> - how often the readout and the preview are redrawn")
	Print("  /tapline barbg <0-1> - how dark the plate inside a bar is")
	Print("  /tapline test - run the bars on a made-up timer, to judge the layout")
	Print("  /tapline plain - turn the copied art off, to see whether it is what is in the way")
	Print("  /tapline width <120-480> | height <14-56> - the size of one heal bar")
	Print("  /tapline sound try - play every sound the game can make in a fight, in order")
	Print("  /tapline bars - show or hide the heal bars the game draws")
	Print(("  /tapline tick <percent> - smallest health gain counted as a healer's (now %s)"):format(tostring(p.tickPct)))
	Print("  /tapline cost <health> | auto - what one tap costs, if the client will not say")
	Print("  /tapline rank <1-6> | auto - which rank to reckon with")
	Print("  /tapline sound - list the sounds; applied | lapsed | estimate | ready <n> to set one")
	Print("  /tapline scale <0.5-2> - size of both displays")
	Print("  /tapline reset - put both back in the middle")
	Print("  /tapline debug - what this client actually let the addon read (send this with a report)")
end

local function Command(msg)
	if not ns.p then ns.Startup() end
	local p = ns.Profile()
	if not p then Print("the saved settings are not loaded yet.") return end
	local sub, tail = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	sub = string.lower(sub or "")
	local n = tonumber(tail)

	if sub == "" or sub == "options" or sub == "config" then
		if ns.Options then
			Print(ns.Options:Toggle() and "Options open." or "Options closed.")
		else
			Print("The options page could not be built. /tapline debug says what the client refused.")
		end
	elseif sub == "help" then
		ns.Usage()
	elseif (sub == "gap" or sub == "rowgap") and n then
		if sub == "gap" then p.gapExtra = max(-40, min(40, n)) else p.rowGap = max(-20, min(30, n)) end
		ns.Panel:Rebuild()
		local m = ns.Panel:RowMetrics()
		Print(("Icon to bar %d, row to row %d."):format(m.gap, m.pitch - m.rowH))
	elseif sub == "learn" then
		if tail == "" then
			Print("Give it a spell id, or shift click a spell into the chat box and paste the link.")
			local missing = {}
			for _, hot in ipairs(ns.HOTS or {}) do
				if not ns.Ranks(hot.name) then missing[#missing + 1] = hot.name end
			end
			Print(#missing > 0 and ("Still without an id: " .. table.concat(missing, ", "))
				or "Every heal on the list has an id already.")
		else
			ns.Teach(tail)
		end
	elseif sub == "forget" then
		ns.db.learned = {}
		ns.db.quietAboutMissing = nil
		-- Emptied, not replaced: the table is held as an upvalue inside Core, so swapping it here
		-- would leave the two looking at different things and the report reading off a ghost.
		for key in pairs(ns.rankState or {}) do ns.rankState[key] = nil end
		Print("Forgot every learned spell id. Type /reload to start again from what is written down.")
	elseif sub == "minimap" then
		p.minimap = not (p.minimap ~= false)
		if ns.MinimapButton then ns.MinimapButton:Refresh() end
		if ns.Options then ns.Options:Refresh() end
		Print("Minimap button " .. (p.minimap and "shown." or "hidden."))
	elseif sub == "shadow" and n then
		p.shadowLayers = max(0, min(4, n))
		ns.Panel:Rebuild()
		if ns.Options then ns.Options:Refresh() end
		Print(("Icon shadow %d deep. One is what the manager draws, two is how its icons read."):format(p.shadowLayers))
	elseif sub == "sparksize" and n then
		p.sparkScale = max(0.5, min(4, n))
		ns.Panel:Rebuild()
		if ns.Options then ns.Options:Refresh() end
		Print(("Spark at %.1f times the bar."):format(p.sparkScale))
	elseif sub == "spark" then
		p.spark = not (p.spark ~= false)
		ns.Panel:Rebuild()
		if ns.Options then ns.Options:Refresh() end
		Print("Spark " .. (p.spark and "on." or "off."))
	elseif sub == "edge" then
		p.edge = (p.edge == "always") and "auto" or "always"
		ns.Panel:Rebuild()
		if ns.Options then ns.Options:Refresh() end
		Print(p.edge == "always" and "Always drawing a frame round the bar."
			or "Drawing a frame only where the client did not give us one.")
	elseif sub == "barbg" and n then
		p.barBgAlpha = max(0, min(1, n))
		ns.Panel:Restyle()
		if ns.Options then ns.Options:Refresh() end
		Print(("Bar background at %.2f."):format(p.barBgAlpha))
	elseif sub == "rate" and n then
		p.rate = max(5, min(60, n))
		Print(("Redrawing %d times a second. The heal bars themselves are filled by the game and animate at its pace, not this one."):format(p.rate))
	elseif sub == "plain" then
		p.plain = not p.plain
		ns.Panel:Rebuild()
		Print(p.plain and "Art off: plain bars, nothing copied from the client." or "Art on: the bars wear the Cooldown Manager look again.")
	elseif sub == "test" then
		p.test = not p.test
		if p.test then p.bars = true ns.Panel:BuildBars() end
		ns.Panel:Refresh(GetTime())
		if ns.Options then ns.Options:Refresh() end
		Print(p.test and "Preview on: the bars run on a made-up timer so the layout can be judged." or "Preview off.")
	elseif (sub == "width" or sub == "height") and n then
		if sub == "width" then p.barW = max(120, min(480, n)) else p.barH = max(14, min(56, n)) end
		ns.Panel:Rebuild()
		Print(("Bars are %d by %d."):format(p.barW, p.barH))
	elseif sub == "bars" then
		p.bars = not (p.bars ~= false)
		if p.bars then ns.Panel:BuildBars() end
		ns.Panel:Refresh(GetTime())
		Print("Heal bars " .. (p.bars and "shown." or "hidden.")
			.. (p.bars and (InCombatLockdown and InCombatLockdown()) and " The game will not build them in combat, so they will appear once the fight ends." or ""))
	elseif sub == "tick" and n then
		p.tickPct = max(0.2, min(20, n))
		Print(("A gain of %.1f%% of your health or more counts as a healer's."):format(p.tickPct))
	elseif sub == "cost" then
		if tail == "" or tail == "auto" then
			p.cost = nil
			local c, why = ns.Cost()
			Print("Working the cost out again: " .. tostring(c) .. " (" .. tostring(why) .. ").")
		elseif n then
			p.cost = n
			Print(("A tap costs %d health."):format(n))
		end
	elseif sub == "rank" then
		local all = (ns.RANK_IDS and ns.RANK_IDS["Life Tap"]) or {}
		if tail == "" or tail == "auto" then
			p.rank = nil
			Print("Using the highest rank of Life Tap found.")
		elseif n and all[n] then
			p.rank = all[n]
			local c, why = ns.Cost()
			Print(("Rank %d: a tap costs %s (%s)."):format(n, tostring(c), tostring(why)))
		else
			Print("Ranks 1 to " .. tostring(#all) .. ", or auto.")
		end
	elseif sub == "sound" then
		local which, value = tail:match("^(%S*)%s*(%S*)$")
		which = string.lower(which or "")
		local v = tonumber(value)
		if which == "try" then ns.SoundTry() return end
		local keys = { applied = "sndApplied", lapsed = "sndLapsed", estimate = "sndEstimate" }
		if which == "" or not keys[which] or not v then
			SoundList()
			Print(("  now: applied %d, lapsed %d, estimate %d"):format(
				p.sndApplied or 0, p.sndLapsed or 0, p.sndEstimate or 0))
			Print("  /tapline sound applied|lapsed|estimate <number>")
			Print("  applied and lapsed are handed to the game, so they play in combat. estimate and ready are this addon's own.")
			return
		end
		p[keys[which]] = max(0, min(#ns.SOUNDS, v))
		local choice = ns.SOUNDS[p[keys[which]]]
		if choice then ns.PlaySound(p[keys[which]]) end
		ns.SyncSounds()
		Print(("%s: %s%s"):format(which, choice and choice[1] or "silent",
			(choice and not choice[4]) and " |cffff9040(this one cannot be played in combat: pick one marked combat)|r" or ""))
	elseif sub == "scale" and n then
		p.scale = max(0.5, min(2, n))
		ns.Panel:Place()
		Print(("Scale %.2f."):format(p.scale))
	elseif sub == "reset" then
		p.x, p.y, p.barX, p.barY = nil, nil, nil, nil
		p.scale, p.alpha = 1, 1
		ns.Panel:Place()
		Print("Both displays put back in the middle.")
	elseif sub == "debug" then
		ns.Debug()
	elseif sub == "log" then
		-- The report is long and a photograph of the screen only ever catches part of it. Saved, it
		-- can be read off disk once the client has written the saved variables out.
		ns.Debug()
		local n = (ns.db and type(ns.db.log) == "table") and #ns.db.log or 0
		Print(("%d lines kept. Type /reload, then the report is in TaplineDB.log in this character's SavedVariables."):format(n))
	elseif sub == "probe" then
		ns.Probe()
	else
		ns.Usage()
	end
end

SLASH_TAPLINE1 = "/tapline"
SLASH_TAPLINE2 = "/lifetap"
SlashCmdList.TAPLINE = Command
