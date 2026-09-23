# Changelog

## 1.10.3

- **The spark is Blizzard's own art again, not a coloured rectangle.** 1.10.2 drew one here because a copied texture that does not render is indistinguishable from no texture at all, and there was no way from inside the addon to tell them apart. There is: `C_Texture.GetAtlasInfo` answers outright whether this client has a given atlas. That settles the problem that had dogged the whole skin.

So the spark is taken in three goes, best first:

1. the piece measured off the manager's own bar, if its atlas really exists here
2. the manager's spark asked for by name, if that exists
3. a plain sliver drawn here, only when this client has neither

The middle step earns its place because the donor bar is not always carrying a spark at the moment it is read: a bar with nothing running has nothing at its end to measure.

Where the real art is used it keeps that art's own proportions, scaled to your bar height, so it is Blizzard's shape rather than a rectangle of mine. `/tapline debug` names which of the three you got, and which atlas.

### On the harness, again

The checks passed on the version that could not find the atlas, because the stub client had never been told the Cooldown Manager's atlas names and so denied having any of them. It knows them now, and three checks were added: that the real art is preferred where it exists, that it keeps its own proportions, and that the drawn fallback only appears where the client genuinely has nothing. Two of them failed before this fix.

## 1.10.2

- **The spark is drawn here now, always, even when the client offers one of its own.**

Everything else in the look is copied on the principle that the client knows best. For the spark that principle broke down: a copied texture that does not render looks exactly like no texture at all, and there is no way from inside the addon to tell those two apart. The spark also has to sit precisely where the fill ends, which is the one place a wrongly measured piece shows most. So it is drawn here, where its size, its colour and its position are known, and any copied one is put away rather than left to fight it.

It is wider than a hairline and slightly taller than the bar, so it reads on a bar fifteen or twenty pixels high, which is where these usually end up. A tickbox turns it off, or `/tapline spark`.

- For the record, since it came up: the preview draws through the same bar and the same skin as a real heal, so anything missing there is missing in earnest. A test bar is not a different thing.

## 1.10.1

- **Removed: "Health to keep back", and the mana percentage that went with it.** Both fed one function, the verdict that decided whether a tap would put you under your floor, and that verdict has been called by nothing at all since the readout which displayed it was taken out. The sliders moved a number that no longer reached anything. The settings, the commands and the verdict itself are gone.

### What is still in there from the old idea

The tick estimate is the last of it: the thing that watched your health for the jumps a heal makes, back when that was the only way to guess whether one was on you. It shows up in two places now, the "incoming says" line in `/tapline debug` and the optional "estimate" sound.

It is also no longer much good. Health is read once a second now rather than thirty times, because nothing on screen needs it, and a clock built on catching three-second ticks wants far closer attention than that.

So it is worth deciding rather than leaving: it can have its sampling back and keep working, or it can follow the readout out of the door. Nothing else depends on it either way.

## 1.10.0

- **The Life Tap cost readout is gone.** It was the idea the addon started from, and this client killed it: health and mana come back as secret values, so the window could only ever show what a tap costs, a number that never changes and that the spell tooltip already gives you. What is left is what actually works, which is the heal bars the game draws and the alert it plays. The setting, the command and the code are all out.

  Health is still read once a second, purely so `/tapline debug` can keep saying what this client will and will not part with. It used to be read thirty times a second to be refused thirty times.

- **The minimap button is back.** A tickbox, or `/tapline minimap`. Left click opens the options, right click shows or hides the heal bars, and it drags round the edge of the map.
- **Both gap sliders are back, and both go smaller than before.** The gap beside the icon starts clear of the frame art round the icon, and can be wound all the way down to nothing, so the bar begins where the picture ends. The gap between rows genuinely reaches zero now: every row used to be padded by the reach of that art whether it needed the room or not, and the padding sat behind the setting where no winding could reach it. It goes down to -20 as well.
- **The spark and the icon shadow are back**, along with the frame. Each part of the look is asked for separately and made here only where the client will not give it up, so a bar can never come out worse than a plain one. The skin looks on the status bar as well as the item frame, which is where the manager actually keeps its frame, backing and spark, and measures decoration against the bar's own width rather than multiples of its height, which was throwing full-length art away.
- **Bar background opacity** is its own slider, separate from the box behind the rows, and changing it does not rebuild the game's slots.
- **Redraws a second** is a slider, 5 to 60. It governs the parts this addon draws, which now means the preview. The heal bars themselves are filled by the game and animate at its pace, not ours, so winding this up will not make those smoother.
- **Always draw a frame round the bar** is a tickbox, for when the copied art is there but not to taste.

Still out, one command away each: growing the rows upwards, packing them together, one bar for any heal at all, and the preview letting heals fall off.

## 1.9.0

This is the 1.5.0 build put back, with the "only heals that are actually on you" option taken out. Everything released between the two is gone. The history is all still in the repository, so any of it can be brought back on its own.

### Back to how 1.5.0 was

- The bars wear the frame, the fill and the icon art that 1.5.0 drew, which is the look that was right.
- One row per heal, each in its own place.
- The gap beside the icon follows the icon's size, so a bigger icon still cannot run into the bar.
- The preview runs every row on a steady countdown.
- The Life Tap readout keeps its close button, and closing it still leaves the heal bars alone.
- Options live in the game's own options window, under AddOns.

### Taken out

- **Only heals that are actually on you.** Gone entirely: the setting, the command and the code.

### Gone with the revert, and easy to put back one at a time

- the minimap button
- the sliders for the gap beside the icon and the gap between rows, and the row gap reaching zero
- growing the rows upwards
- packing the rows together
- one bar for any heal at all
- the preview letting heals fall off and come back
- the skin walking the status bar for its frame and spark

Say which of those you want and it comes back on top of this, one at a time, so nothing has to be taken on trust again.

## 1.8.2

- **Fixed: the bars lost their frame, and never had a spark.** 1.8.1 taught the skin to find the art the client keeps on the bar, and then the hand-made frame stopped being drawn, because the test for whether to draw it was "did we copy anything at all". One stray texture was enough to switch it off, and if that texture was not a frame the bar simply lost its edge. Each part of the look is asked for separately now:

  - a **frame** is a piece that reaches past what it frames, so a backing sitting inside the bar no longer counts as one
  - a **spark** is a piece narrow against the bar's length
  - the **icon's shadow** is the manager's overlay atlas

  Whichever of those the client does not give up is made here instead, and the report says which came from where. A bar can no longer come out worse than the plain one.

- **Always draw a frame round the bar** is a tickbox, and `/tapline edge`, for when the copied art is there but not to taste.

- **Packing the rows now asks the game to do it.** 1.7.0 handed every row every heal and assumed the game would fill them from the front. It does not: it keeps each heal in its own row and leaves the hole where the others would be, which is exactly what you saw. This addon cannot close that gap itself, because which rows are filled is aura data and secret here, which is the whole reason the game draws them.

  So packing now asks for the mechanism the game has for a list that changes length: an aura group rather than fixed slots, given the same spell ids and a layout to pack them into. The fixed slots stay as the fallback if the game refuses, and `/tapline debug` says which one is running.

  If the group turns out to ignore the spell list and show every buff you have, turn it off and tell me. **One bar for any heal** needs nothing from the game at all and is still the arrangement to trust.

## 1.8.1

- **Fixed: no spark, and no shadow on the icons.** Both came from the same place. The skin was reporting "0 pieces", meaning it had copied the manager's fill colour and nothing else, and there were two reasons for that stacked on top of each other.

First, it only looked at the donor item frame's own regions. The Cooldown Manager keeps its frame, its backing and its spark on the **status bar**, not on the item, so there was never anything to find. It now walks the item, the bar, and one level of children beneath the item.

Second, and worse, the filter that decides what counts as decoration measured a piece's width in multiples of the bar's **height**. A bar is about ten times as wide as it is tall, so the bar's own full-length frame looked like something enormous and was thrown out. It is measured against the bar's own width now, so full-length art is kept and only genuinely oversized things are skipped.

- **The spark is treated as a spark.** A piece that is narrow against the bar's length keeps its own size and rides the end of the fill, travelling with it, instead of being stretched from one end to the other like a plate.
- `/tapline debug` now lists every piece of art it copied, by atlas name, and says where the icon's shadow came from or that this client has no overlay atlas for it.

### And the harness, which had been passing on nothing

The 177 checks passed on the broken version, because the stub's donor had no art on its bar for the code to miss. There is a proper one now, shaped the way the real thing is: the icon on the item, and the frame, backing and spark on the bar, at real coordinates. Nine checks run against it and six of them failed on the old code, including the width filter throwing away full-length art and the spark being stretched instead of parked at the fill's edge.

## 1.8.0

- **New: one bar for any heal at all.** A tickbox in the options, or `/tapline single`. It draws a single row and gives that one slot every rank of every heal, so whichever of them is on you shows there, with its own icon, its own name and its own countdown, and nothing shows when none is. It does not matter which heal it is as long as there is one, and this says exactly that.

This is the sturdiest of the three arrangements, because it asks nothing of the game beyond what is already proven: one slot, one list of spell ids, which is what has been working all along. Packing rows together has to assume the game fills its slots from the front; one row has nothing to assume.

- **The preview lets heals run out now.** It used to sit there with every row permanently full, which is no use at all for judging a layout that changes shape. A previewed heal runs for its real length, falls off, waits, and comes back, and the rows are offset so they do not do it in step. Which way the rows grow, whether they pack together, and what "only heals that are actually on you" really looks like can all be watched instead of guessed at.
- Turning on "only heals that are actually on you" no longer hides the preview: a previewed row now properly disappears between heals and comes back, which is the point of previewing it.

## 1.7.0

- **Fixed: "only heals that are on you" left three empty squares behind.** Four things were being faded out, the icon, the bar and the two labels, but the frame art, the plate and the icon's shadow are put on by the skin and belong to the row rather than to those four, so they stayed. The row itself goes now, which takes everything drawn on it with it. The game's own row is not a child of ours, so it still shows.
- **A growth direction.** Rows run down from the top of the box by default, or up from the bottom. Tickbox in the options, or `/tapline grow up` and `/tapline grow down`.
- **The rows can pack together**, with no gap left for a heal you do not have. Tickbox in the options, or `/tapline collapse`. Best paired with "only heals that are actually on you".

### How the packing works, and its one catch

Tapline cannot see which rows are filled. Whether a heal is on you is aura data, and on this client that is secret to addons in combat, which is the whole reason the game draws these rows rather than the addon. So it cannot move the filled ones up.

What it does instead is hand **every** row **every** heal, and let the game fill them from the front. The game decides which row a heal lands in, and it fills the first before the second. That gets what you have sitting together at the front with no holes, without this addon knowing anything.

The catch: a row can no longer say in advance which heal it is waiting for, because any of them could land in it. So while packing is on, an empty row shows no icon and no name. With "only heals that are on you" turned on as well it makes no difference, since an empty row shows nothing at all.

This arrangement is **not yet confirmed in game**. If the game turns out to put the same heal in every row, or to leave the first empty, say so and it goes back in a minute: the one row per heal arrangement is still the default and is untouched.

## 1.6.1

- **Fixed: winding the row gap down to nothing still left the rows far apart.** The gap slider was working; the row height underneath it was not. Every row was being padded by the reach of the icon's frame art, about a tenth of the icon on each side, whether anything needed the room or not. That padding sat behind the setting and could not be wound out. A row is now as tall as the taller of the bar and the icon and no taller, so at a gap of nothing the rows sit exactly one row apart.

The frame round an icon is a soft edge, and a little overlap between rows is what the Cooldown Manager itself does, so how close rows sit is left entirely to the slider now.

- The row gap goes down to **-20** as well as up to 30, for pulling a big icon's rows together. It stops short of one row sitting entirely on top of the next however far it is wound.
- The gap beside the icon is untouched: it still cannot be set low enough to put the bar back under the icon's frame, because that one is added to the minimum rather than replacing it.

## 1.6.0

- **A button on the minimap**, with a tickbox in the options to turn it off and `/tapline minimap` to do the same. Left click opens the options, right click puts the Life Tap readout away or brings it back, and it can be dragged round the edge of the map to wherever suits. Its own button rather than a library: this addon has no libraries and is not growing one for a round button. The ring art is asked for by file id before it is used, because textures that have existed for twenty years are not guaranteed to render on this build, and a plain dark disc stands in if it is not there.
- **A gap slider for the room beside the icon**, and another for the room between rows. The icon one is added to the least that avoids an overlap rather than replacing it, so however far it is wound down the bar still starts after the icon's frame art has finished. `/tapline gap` and `/tapline rowgap` do the same from the command line.

### Locked in

The working build is tagged `known-good-1.5.0` in the repository and zipped at `Tapline-1.5.0.zip`, verified in game: bars drawing in and out of combat, 30 aura sounds registered with the game, 7 of 7 sound files accepted. Everything in this release is additive and in its own file or its own setting; nothing reaches into the row-building or slot code that took three attempts to get right.

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
