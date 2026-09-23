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
	{ "UnitHealth",            "UnitHealth",            function() return UnitHealth("player") end },
	{ "UnitHealthMax",         "UnitHealthMax",         function() return UnitHealthMax("player") end },
	{ "UnitPower (mana)",      "UnitPower",             function() return UnitPower("player", (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0) end },
	{ "UnitPowerMax (mana)",   "UnitPowerMax",          function() return UnitPowerMax("player", (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0) end },
	{ "UnitGetIncomingHeals",  "UnitGetIncomingHeals",  function() return UnitGetIncomingHeals("player") end },
	{ "PlayerFrameHealthBar",  "PlayerFrameHealthBar",  function() return PlayerFrameHealthBar:GetValue() end },
	{ "PlayerFrameManaBar",    "PlayerFrameManaBar",    function() return PlayerFrameManaBar:GetValue() end },
	{ "InCombatLockdown",      "InCombatLockdown",      function() return InCombatLockdown() and 1 or 0 end },
	{ "IsSpellKnown(Life Tap)", "IsSpellKnown",         function() return IsSpellKnown(11689) and 1 or 0 end },
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
end

function ns.Debug()
	local S, p = ns.state, ns.Profile()
	Print("v" .. ns.VERSION .. " on " .. tostring(ns.charKey))
	if not p then Print("  |cffff5050the saved settings never loaded|r") return end

	-- The decisive number. A panel that never updates and a client that refuses to answer look
	-- exactly alike from the outside, and this tells them apart at a glance.
	Print(("  driver: %d frames, %d samples taken; panel %s, bars %s"):format(
		S.stats.driver, S.stats.samples, YesNo(ns.Panel and ns.Panel.frame), YesNo(ns.Panel and ns.Panel.container)))
	if S.stats.driver == 0 then Print("  |cffff5050the tick is not running at all, which is the first thing to fix|r") end

	ns.Probe()
	Print(("  what it settled on: health %s, mana %s"):format(
		(S.hp and S.hpMax) and (tostring(S.hp) .. "/" .. tostring(S.hpMax) .. " via " .. tostring(S.hpSource)) or ("|cffff5050none|r (" .. tostring(S.hpWhy) .. ")"),
		(S.mp and S.mpMax) and (tostring(S.mp) .. "/" .. tostring(S.mpMax)) or ("|cffff5050none|r (" .. tostring(S.mpWhy) .. ")")))

	local cost, why = ns.Cost()
	Print(("  a tap costs %s (%s)%s"):format(tostring(cost), tostring(why),
		S.rankGuess and ", though the client would not say which ranks you know" or ""))
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
	Print(("  sounds: applied %d, lapsed %d, estimate %d, ready %d; %d handed to the game, %d refused%s"):format(
		p.sndApplied or 0, p.sndLapsed or 0, p.sndEstimate or 0, p.sndReady or 0,
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
	Print("  /tapline - show or hide the readout")
	Print("  /tapline bars - show or hide the heal bars the game draws")
	Print(("  /tapline reserve <percent> - health to keep back after a tap (now %s)"):format(tostring(p.reserve)))
	Print(("  /tapline mana <percent> - only speak up below this much mana (now %s)"):format(tostring(p.manaAt)))
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

	if sub == "" then
		p.shown = not p.shown
		ns.Panel:Refresh(GetTime())
		Print("Readout " .. (p.shown and "shown." or "hidden."))
	elseif sub == "help" then
		ns.Usage()
	elseif sub == "bars" then
		p.bars = not (p.bars ~= false)
		if p.bars then ns.Panel:BuildBars() end
		ns.Panel:Refresh(GetTime())
		Print("Heal bars " .. (p.bars and "shown." or "hidden.")
			.. (p.bars and (InCombatLockdown and InCombatLockdown()) and " The game will not build them in combat, so they will appear once the fight ends." or ""))
	elseif sub == "reserve" and n then
		p.reserve = max(0, min(90, n))
		Print(("Keeping %d%% of your health back."):format(p.reserve))
	elseif sub == "mana" and n then
		p.manaAt = max(0, min(100, n))
		Print(("Speaking up below %d%% mana."):format(p.manaAt))
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
		local keys = { applied = "sndApplied", lapsed = "sndLapsed", estimate = "sndEstimate", ready = "sndReady" }
		if which == "" or not keys[which] or not v then
			SoundList()
			Print(("  now: applied %d, lapsed %d, estimate %d, ready %d"):format(
				p.sndApplied or 0, p.sndLapsed or 0, p.sndEstimate or 0, p.sndReady or 0))
			Print("  /tapline sound applied|lapsed|estimate|ready <number>")
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
	elseif sub == "probe" then
		ns.Probe()
	else
		ns.Usage()
	end
end

SLASH_TAPLINE1 = "/tapline"
SLASH_TAPLINE2 = "/lifetap"
SlashCmdList.TAPLINE = Command
