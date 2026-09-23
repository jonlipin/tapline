# Changelog

## 1.2.0

- The log settled every open question at once. On this client your **current** health, mana and health percentage are all secret, and so is incoming-heal prediction, but the **maximums are not**: `UnitHealthMax` and `UnitPowerMax` hand over real numbers, as does `UnitLevel`. `issecretvalue` was also cleared of suspicion, since it answers false for a plain 1 and for a string.
- So the readout now says the most useful true thing it can: what a tap costs against your actual maximum, as a number and a share, and what health to stay above. Your own health bar is the only thing that knows where you are, and the panel says so rather than pretending otherwise.
- The alert the game plays when a heal lands on you is switched **on** by default now. It is the one feature here that works end to end, and shipping it silent made the addon look like it did nothing. A sound you turn off stays off.
- Every sample attempt is counted, not only the ones that answered. The report read "0 samples taken" while the tick had run 632 times, which is exactly the confusion that counter exists to prevent.
- `/tapline debug` now lists each rank of Life Tap, whether this character knows it, and the description the client gives for it. The cost is parsed out of that text, so when the number looks wrong that is where to look.

### Confirmed working, from the same log

- All five handovers to a game-drawn slot are accepted here: `SetIcon`, `SetDurationBar`, `SetDurationText`, `SetSpellName`, `SetApplicationCount`. Three slots of three built.
- The rank ids written from memory were almost all right: Renew 10 of 10, Rejuvenation 11 of 11, Regrowth 9 with one the client has never heard of.

## 1.1.0

- Confirmed in game, and it settles the design: **this client hands your own health and mana back as secret values.** Not refused, not missing. `UnitHealth`, `UnitPower`, `PlayerFrame.healthbar`, the deep `PlayerFrameContent...HealthBarsContainer.HealthBar`, every one of them secret, out of combat, with auras perfectly readable at the same moment. An addon may hold a secret value but never look inside it, so there is no arithmetic to be done on your own health here, by this addon or any other.
- So the readout stops pretending. When the numbers are secret it shrinks to what it does know, which is what a tap costs and what is heading your way, and says in one line that the bars below are the real answer. A panel of error text sitting over the game was worse than no panel; that detail lives in `/tapline debug` now.
- Added one last resort before giving up: a percentage. Nameplates need one, so `UnitPercentHealthFromGUID` may be open where the number is not, and a percentage is enough for both things that matter here. A floor reads perfectly well in per cent, and the tick clock only ever cared how big a jump was against your maximum. If that call works, the estimate and the floor come back on their own, with the readout saying a percentage is all it was given.
- Fixed a real mistake: mana that could not be read was being taken for a full mana bar, so the verdict would answer "no need" for the whole of a fight on a client that keeps mana secret. That is the one answer that is certainly wrong. Unknown mana now drops the question instead of answering it.
- `/tapline log` writes the whole report into `TaplineDB.log` with the colour codes stripped. A long report has only ever reached me as a photograph of the screen, which catches about a third of it; saved, it can be read off disk after a `/reload`.

## 1.0.1

- Health and mana come back from this client as **secret values**, not as numbers: the first in-game run said "UnitHealth secret". So the readout now hunts for a bar it can read instead. The player frame has been rebuilt since the old global names were right, and `PlayerFrameHealthBar` does not exist here, so a list of candidate paths is walked and `/tapline debug` reports which of them exist and what each one gave.
- `/tapline debug` now starts by asking whether `issecretvalue` itself can be trusted, since if it calls a plain 1 secret then nothing else it says means anything. It also probes health on the target and the pet, the percentage call, and the level, to find out whether this is about the player specifically or about unit data as a whole.
- Fixed: one pcall wrapped every handover to a game-drawn slot, so the first refusal threw away the icon, the bar and the text with it and the game fell back to drawing its own presentation wherever it liked. Each handover is guarded on its own now, the slot frame is never resized (which the game refuses outright, and was the call that was failing), and the report says which handovers this client accepts.
- Fixed: the placeholder icons under the bars asked for the spell by name, which gets a warlock nothing, because the client answers that out of your own spellbook. They ask by rank id now.

## 1.0.0

- First release. A readout of health, mana, what a Life Tap costs and how many taps your floor leaves room for, ending in one word: TAP, tap ok, WAIT or no need. `/tapline`, or `/lifetap`. Everything is saved per character.
- Whether anything is healing you is answered three ways, and the readout always says which one it is giving. **read**: the aura itself, wherever this client will part with it. **estimated**: while blind, a gain in health that nothing you did accounts for is a tick, and two about three seconds apart is somebody healing you, marked with a ~ because it is late by up to a tick and cannot name the spell. **drawn**: bars the game fills itself, which stay right through a fight and which this addon deliberately does not read.
- Mana is checked before affordability, so a red WAIT means something: there is no decision to make while the mana is there, whatever the health is doing.
- Sounds are split by who plays them. **applied** and **lapsed** are handed to the game against every rank of every heal, so they fire in combat with no addon involvement at all. **estimate** and **ready** are this addon's own and default to silent, so they do not double up on the game's.
- Your own Drain Life, Death Coil, bandages, healthstones and healing potions open a short window where gains are put down to you. Siphon Life and Demon Armor's regeneration are left out on purpose: they tick for far less than the smallest gain counted, so their size sorts them out without blinding the estimate for half a minute.
- Every rank of each heal is resolved at load and checked against the client, because aura slots and registered sounds take spell ids rather than names. An id that comes back under a different name is dropped rather than believed.
- `/tapline debug` walks every call the addon leans on and prints what each one did: missing, refused and in whose words, or answered with a secret value. It leads with how many frames the tick has run for, since a display that never updates and a client that refuses to answer look the same from outside.
