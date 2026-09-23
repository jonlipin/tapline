# Tapline

Should this health become mana? A small readout for warlocks on the WoW: Forever client (Interface 16001).

Tapline shows your health and mana, what one Life Tap costs, how many taps your own floor leaves room for, and whether anything is healing you. It settles on one word: **TAP**, **tap ok**, **WAIT** or **no need**.

`/tapline` opens it. `/lifetap` works too.

## Whether anything is healing you

This is the hard part, and Tapline answers it three ways. It always says which answer it is giving, because the three are not equally trustworthy.

- **read** — wherever the auras are legible, the heal over time is read straight off you and the time shown is the real one.
- **estimated** — in combat this client hides aura data from addons completely: every read errors or comes back secret, the aura events carry secret tables, and the combat log is closed. So the health itself is watched instead. A gain that nothing you did accounts for is a tick, and two of them about three seconds apart is somebody healing you. It is marked with a `~`, because it is late by up to one tick, it cannot name the spell, and a tick landing in the same tenth of a second as a hit is lost in the arithmetic.
- **drawn** — the bars under the readout are not Tapline's. Each one is a slot the **game** fills, handed the spell ids of every rank of one heal, and the game keeps it right through a fight. Tapline cannot read what it drew, and does not try. That is exactly why it is worth having: it is the one display here that cannot be wrong. Trust it when the three disagree.

## Sounds

`/tapline sound` lists them. Two of the four are not played by Tapline at all:

- **applied** and **lapsed** are handed to the game with `C_UnitAuras.AddAuraSound`, against every rank of every heal. The client plays them itself the instant a heal lands on you or falls off, in combat included. Nothing comes back to the addon, so the sound is the whole alert.
- **estimate** and **ready** are Tapline's own: the tick clock noticing a heal the game never announced, and the readout turning to TAP. Both are worked out from health and mana rather than from an aura, so they still fire in a fight.

Only the sounds with a file behind them can be handed to the game. Those are marked `(combat)` in the list.

## Your own healing

Drain Life, Death Coil, bandages, healthstones and healing potions open a short window during which gains are put down to you rather than to a healer. Siphon Life and Demon Armor's regeneration are deliberately left out: they tick for far less than the smallest gain Tapline counts, so their size sorts them out without blinding the estimate for half a minute at a time.

`/tapline tick <percent>` moves that floor if a low-rank heal is being missed, or if something of yours keeps tripping it.

## Commands

| Command | What it does |
| --- | --- |
| `/tapline` | show or hide the readout (`/lifetap` works too) |
| `/tapline bars` | show or hide the heal bars the game draws |
| `/tapline reserve <percent>` | health to keep back after a tap |
| `/tapline mana <percent>` | only speak up below this much mana |
| `/tapline tick <percent>` | smallest health gain counted as a healer's |
| `/tapline cost <health>` \| `auto` | what one tap costs, if the client will not say |
| `/tapline rank <1-6>` \| `auto` | which rank of Life Tap to reckon with |
| `/tapline sound` | list the sounds, and set applied, lapsed, estimate or ready |
| `/tapline scale <0.5-2>` | size of both displays |
| `/tapline reset` | put both displays back in the middle |
| `/tapline debug` | what this client actually let the addon read |

Drag either display to move it. Positions, and everything else, are saved per character.

## `/tapline debug`

Send this with any report. It walks every call Tapline leans on and prints what each one did: whether the global exists, whether the call was refused and in whose words, whether the answer came back as a secret value. It leads with how many frames the tick has run for, because a display that never updates and a client that refuses to answer look exactly alike from the outside.

## Notes

- The rank ids in `Data.lua` are written from memory and checked against the client at load. One that comes back under a different name is dropped, so a wrong guess costs the coverage of that rank and nothing else. `/tapline debug` says how many of each the client agreed with.
- Aura slots take spell ids rather than a name, which is why the ranks matter: a heal cast on you by somebody else is invisible to the game's own display unless the rank they cast is in the list.
