-- Tapline data: the spells this addon has to know about by id rather than by name.

local ADDON, ns = ...

-- ------------------------------------------------------------------
-- Ranks
--
-- Blizzard's aura slots are handed spell ids, not a name, and so is a registered sound. A heal
-- somebody else casts on you is therefore invisible unless every rank they might cast is listed.
-- The ids here are written from memory and checked against the client at runtime by ns.Ranks: one
-- that comes back under a different name is dropped, so a wrong guess costs the coverage of that
-- rank and nothing else. "/tapline debug" says how many of each the client agreed with.
-- ------------------------------------------------------------------
ns.RANK_IDS = {
	["Renew"] = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315 },
	["Rejuvenation"] = { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 },
	["Regrowth"] = { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980 },
	-- Riptide and Wild Growth are this client's own spells rather than any other version's, so
	-- these ids are a starting guess. The real ones are learned from the game: see ns.Learn.
	["Riptide"] = { 61295, 61299, 61300, 61301 },
	["Wild Growth"] = { 48438, 53248, 53249, 53251 },
	["Life Tap"] = { 1454, 1455, 1456, 11687, 11688, 11689 },
}

-- The heals over time another player can put on you: how long each runs and how far apart its ticks
-- are. The period is what lets a run of health gains be recognised as one spell; the duration is
-- what puts a time on it when the auras themselves cannot be read.
-- A heal listed here that this client does not have is withheld: its ranks resolve to nothing,
-- and a row is only drawn for a heal the client agrees exists. So a guess costs nothing but the
-- line it is written on, and the ones below reach past vanilla deliberately, because this
-- client turns out to have spells from later than that.
ns.HOTS = {
	{ name = "Renew", duration = 15, period = 3 },
	{ name = "Rejuvenation", duration = 12, period = 3 },
	{ name = "Regrowth", duration = 21, period = 3 },
	-- Durations taken from this client's own spell text: Riptide heals "an additional 445 over 15
	-- sec", Wild Growth "336 over 7 sec".
	{ name = "Riptide", duration = 15, period = 3 },
	{ name = "Wild Growth", duration = 7, period = 1 },
}

-- What a Life Tap costs in health, by rank. The client's own spell description is asked first and
-- this is the fallback; "/tapline cost <health>" overrides both.
ns.LIFE_TAP_COST = { [1454] = 30, [1455] = 89, [1456] = 170, [11687] = 290, [11688] = 424, [11689] = 594 }

-- Healing you cause yourself. Its gains are not a healer's, so they are set aside for the window of
-- seconds given here, counted from the cast, matched on the lowercased spell name containing the key.
--
-- The list and the windows are both kept short, because every second a window is open is a second a
-- healer's tick is thrown away with it. Siphon Life is deliberately absent: it ticks for far less
-- than the smallest gain this addon counts, at every rank and every level, so its size sorts it out
-- without blinding the estimate for the half minute it runs. Demon Armor's regeneration goes the
-- same way. Health Funnel costs you health rather than giving it, so it never needs a window.
ns.OWN_HEALS = {
	["drain life"] = 7, ["death coil"] = 3, ["bandage"] = 9,
	["healthstone"] = 3, ["healing potion"] = 3, ["rejuvenation potion"] = 3,
}

-- ------------------------------------------------------------------
-- Sounds
--
-- Two different things are going on here. A sound this addon plays itself needs only a sound kit
-- entry. A sound handed to the game with C_UnitAuras.AddAuraSound needs a sound FILE id, and only
-- the entries that have one can be used for the alerts that matter, the ones that fire in combat
-- where this addon cannot see the aura at all. Those are marked "(combat)" in the list.
--
-- Saved settings store the index, so entries are only ever appended to the end.
-- ------------------------------------------------------------------
ns.SOUNDS = {
	{ "Mystic chime",  "TUTORIAL_POPUP",        7355 },
	{ "Gem clink",     "PUT_DOWN_GEMS",         1221 },
	{ "Explosion",     "ALARM_CLOCK_WARNING_3", 12889, 567333 },
	{ "Whisper toast", "UI_BNET_TOAST",         18019 },
	{ "Auction gong",  "AUCTION_WINDOW_OPEN",   5274 },
	{ "Map ping",      "MAP_PING",              3175 },
	{ "Raid warning",  "RAID_WARNING",          8959,  567397 },
	{ "Ready check",   "READY_CHECK",           8960,  567478 },
	{ "Level up",      "LEVELUP",               888,   567431 },
	{ "Alarm clock 1", "ALARM_CLOCK_WARNING_1", 12867, 567388 },
	{ "Alarm clock 2", "ALARM_CLOCK_WARNING_2", 12888, 567399 },
	{ "Flag taken",    "PVP_FLAG_TAKEN",        8174,  567275 },
}
