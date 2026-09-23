# Changelog

## 1.0.0

- First release. A readout of health, mana, what a Life Tap costs and how many taps your floor leaves room for, ending in one word: TAP, tap ok, WAIT or no need. `/tapline`, or `/lifetap`. Everything is saved per character.
- Whether anything is healing you is answered three ways, and the readout always says which one it is giving. **read**: the aura itself, wherever this client will part with it. **estimated**: while blind, a gain in health that nothing you did accounts for is a tick, and two about three seconds apart is somebody healing you, marked with a ~ because it is late by up to a tick and cannot name the spell. **drawn**: bars the game fills itself, which stay right through a fight and which this addon deliberately does not read.
- Mana is checked before affordability, so a red WAIT means something: there is no decision to make while the mana is there, whatever the health is doing.
- Sounds are split by who plays them. **applied** and **lapsed** are handed to the game against every rank of every heal, so they fire in combat with no addon involvement at all. **estimate** and **ready** are this addon's own and default to silent, so they do not double up on the game's.
- Your own Drain Life, Death Coil, bandages, healthstones and healing potions open a short window where gains are put down to you. Siphon Life and Demon Armor's regeneration are left out on purpose: they tick for far less than the smallest gain counted, so their size sorts them out without blinding the estimate for half a minute.
- Every rank of each heal is resolved at load and checked against the client, because aura slots and registered sounds take spell ids rather than names. An id that comes back under a different name is dropped rather than believed.
- `/tapline debug` walks every call the addon leans on and prints what each one did: missing, refused and in whose words, or answered with a secret value. It leads with how many frames the tick has run for, since a display that never updates and a client that refuses to answer look the same from outside.
