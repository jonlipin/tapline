# Changelog

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
