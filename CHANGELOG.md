# Changelog

## 1.5.0

- **Fixed: a bigger icon ran into the bar.** The frame drawn around an icon reaches past the picture on every side, and by a share of the icon rather than a fixed number of pixels, so it reaches further the further you push the size. A gap of four pixels was fine at the default and was simply run over at half again. The gap now grows with the icon, the icon is inset so its frame stays inside the row instead of hanging off the left, and the bar takes exactly the room that is left. The row also grows tall enough to hold a bigger icon, so rows stop running into each other as well.

That frame art was being measured against the bar's height rather than the icon's, which is what let it reach across in the first place. It follows the icon now, and across and down separately, because it is not square: it reaches 0.200 of the icon sideways and 0.175 down.

- **A close button on the Life Tap readout.** That window is the part of this addon that can say least on this client, so it should be easy to put away: click the X, or use the tickbox in the options, or `/tapline show`.
- **Closing the readout no longer takes the heal bars with it.** They shared one switch, which meant putting away the window that knows nothing also took away the one thing that works. They are separate now.
- **New: only show heals that are actually on you.** A tickbox in the options, or `/tapline only`. An empty row draws nothing at all and leaves the game's own row, which is the only thing here that knows whether a heal is there, to show itself. The row keeps its place so the game's slot above it keeps its place, and the preview still draws in this mode so a layout can still be judged.

## 1.4.0

- **The options live in the game's own options window now**, under AddOns, as a canvas category: Blizzard hosts a frame and Tapline draws it. `/tapline` opens it there. If the game will not open its panel, which on this client it sometimes will not, the same page appears in a window of Tapline's own instead, and the report says which happened.

That is deliberately only half of the settings API. The other half, registering proxy settings so Blizzard stores the values, is what put this addon's mark on Blizzard's own code here once before and had the nameplates throwing "attempt to compare a secret number value". None of it is used: every value is read from and written to Tapline's own saved settings, and Blizzard is only lending the page a home. The tests assert that no proxy setting is ever registered.

### What is on the page

- **Bar width**, **bar height** and **icon size**, the icon set as a share of the bar's height so it stays in proportion. The bar takes whatever room the icon gives up.
- **Bar opacity**, **background opacity** and **border opacity** as separate sliders, so the rows can be solid over a box that is barely there, or the other way about.
- **Scale**, and a **health to keep back** slider.
- Tickboxes for the heal bars, the readout, the preview, and plain bars.
- **An alert on/off tickbox** that does not forget which sound was chosen, and a picker for the heal-landed and ran-out sounds. Files this client refuses are greyed out and cannot be chosen at all.
- Buttons for resetting the layout, playing every sound in turn, and printing the self report.

### Underneath

- Changing a size rebuilds the rows, because a slot the game has placed cannot be resized afterwards. Changing a colour or an opacity does not: that would throw away the game's slots for the sake of a tint. A rebuild asked for during a fight waits and happens the moment it ends.

## 1.3.2

- **Fixed: every alert had gone silent.** The report showed "0 handed to the game, 60 refused". The file ids in the list were written from memory, and the game does not complain about a bad one: `AddAuraSound` simply hands back nothing. So moving the default off the explosion moved it onto a file this client will not take, and turned all sound off without a word. Each file is now offered once at login against a real spell and taken straight back out, only the accepted ones are ever used, and a choice the game refuses is swapped for one it accepts with a line saying so.
- `/tapline debug` now reports **where the frames actually are**: shown, visible, how many anchors, position, size, alpha and scale, for the readout, the bars holder, the container, every row and every slot, plus how many times the refresh has reached each. Everything the report said about the bars was "built fine", which is true and useless when nothing is on screen; building a row and putting it somewhere visible are different problems.
- `/tapline plain` turns the copied art off entirely and rebuilds, so the Cooldown Manager look can be ruled in or out in one command.

Also read out of the last report, with thanks to the client for finally being specific: Life Tap on this build converts **30 health into 87 mana** at rank 1 and **69 into 126** at rank 2, and this character knows those two. The written-down vanilla numbers were wrong for this server, which is exactly why the cost is read out of the spell's own description first.

## 1.3.1

- **Fixed: 1.3.0 stopped showing bars for Renew and the rest.** Dressing a row in the Cooldown Manager's art was done while the row was being built, and it was not walled off, so one refused call took the whole row down with it. Worse, the pieces were being made on a frame of ours placed inside the game's slot rather than on the slot itself, and the slot will only draw regions that are its own. Between them, a heal landing on you produced nothing at all.
- The pieces are made straight onto the frame that owns them again, which is what worked before 1.3.0. The art goes on afterwards, inside its own guard, so the worst it can do now is leave a plain bar that works. The skin cannot throw at all any more: a bad atlas name, a missing template or a refused mask is reported and stepped over.
- One row that will not build no longer costs the others, or the slots under them.
- `/tapline debug` gained a "bar art" line saying whether the manager's look went on, and if not, in whose words it was refused. A refusal inside the skin is no longer overwritten by the name of the skin we were hoping for.

### And the reason it got past me

The offline harness passed 105 checks on the broken build, because its stub let regions be created anywhere and never refused anything. It now records which frame made each region, can be told to refuse children the way a forbidden frame does, and carries three checks that fail on the 1.3.0 code: that a slot's regions belong to the slot, that a refused skin still leaves a working row, and that one bad row does not stop the rest.

## 1.3.0

- **The explosion is gone.** The alert was switched on by taking the first entry in the list that had a sound file behind it, and that entry is the one called Explosion, so every heal landing on you set off a detonation. The default is a quieter cue now, anyone who was handed the explosion is moved off it once, and a sound chosen on purpose is never touched. The list is looked up by name rather than by position, which is what caused this.
- `/tapline sound try` plays every sound the game can make in a fight, one every two seconds, announcing each one's number as it goes. The names in the list were written from memory against file ids and only two have ever been confirmed by ear. Tell me which number sounded like what and the names get fixed.
- **The bars wear the Cooldown Manager's own art.** A manager bar is found at runtime and measured: the real fill texture or atlas, its colour, the pieces around it and how far each reaches past the bar, all stored as fractions of the bar's height so they scale with it. Naming an atlas and hoping is how you get art of the wrong shape. With no donor to copy, a hand-made frame in the same spirit is used, and `/tapline debug` says which is in use.
- **A timer on every bar**, written the way the manager writes them: "6 s", "1 m", and tenths under a second. Counted down rather than rounded, because a bar reading 7 with 6.4 left is lying in the direction that gets you killed.
- **A preview.** `/tapline test`, or the tickbox in the options, runs every row on a made-up countdown at the real heal's own speed, so the layout can be judged without waiting on a healer.
- **An options window**, built out of the client's own widgets with sliders for everything numeric: show the readout, show the bars, preview, bar width, bar height, scale, health to keep back, and both game-played sounds as a row of numbered buttons that play when pressed. `/tapline` opens it; `/tapline show` is now what toggles the readout.

It is deliberately Tapline's own window rather than a page in Blizzard's settings: on this client, registering proxy settings or opening the settings panel from addon code puts the addon's mark on Blizzard's own, and the game then starts refusing its own reads.

- Bar width and height are settings, and changing either rebuilds the game's slots, since a slot cannot be resized once the game has placed it.

## 1.2.1

- The report now writes itself into `TaplineDB.log` a few seconds after every login, to the log alone and not to chat, and starts the log fresh each time. The old way needed `/tapline log` to be typed **before** the reload, and getting that order wrong left the previous session's report sitting on disk looking exactly like the current one. A plain `/reload` is now enough, and what is on disk is always this session rather than a mixture of two.
- Each report is stamped with the addon version and the time it was written, so there is no guessing about which build produced it.
- `/tapline log` still works and still prints to chat as well.

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
