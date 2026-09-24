# Tapline

Bars showing the heals over time ticking on you, so a warlock knows when it is safe to Life Tap.

Drawn by the game itself, so they keep working in combat, where this client hides aura data from addons completely.

`/tapline` opens the options.

## The point of it

Life Tap turns your health into mana, and the question is never really whether you can afford the health. It is whether that health is coming back.

A heal over time ticking on you answers it. If a Renew or a Rejuvenation is running, the cost is already being paid back and you can tap without thinking about it. If nothing is on you, the same tap is just health you do not get back, and the second or third one in a row is how a warlock dies to a pull that was going fine.

That is all this addon is for. A row appears when a heal lands on you and counts down while it runs, sitting wherever you put it, so the answer is in the corner of your eye while you are casting. The sound is there for when you are not looking at all: a noise means a heal just landed, which means tap now.

A row for each heal over time that can be on you: Renew, Rejuvenation, Regrowth, Riptide, Wild Growth. Each shows the spell's own icon, its name and a countdown, and appears only while that heal is actually running.

## Why the game draws them and not this addon

On this client, whether an aura is on you is secret to addons in combat. Every read of one errors or comes back as a value an addon may hold but never look inside, the aura events carry secret tables, and the combat log is closed. So no addon here can tell you what is ticking on you. It is not a matter of trying harder.

What the game will do is draw it for you. Handed the spell ids of a heal, it will keep a bar right through a fight and fill it in from data the addon is not allowed to see. Tapline supplies the ids, the art and the position; the game supplies the truth. Nothing is read back, because nothing can be.

The same goes for the alert: it is registered with the game, and the game plays it. There is no callback, so the sound is the whole of the message.

That means one honest limit. **Tapline cannot tell you anything about a heal, only show you.** It has no idea which of these bars is filled at any moment, and nothing it does can depend on that.

## Spell ids are learned, not assumed

Forever has spells of its own: Riptide and Wild Growth are new here, as are Penance, Lava Burst, Mangle and others. Ids taken from any other version of the game are guesses, and the game must be given ids rather than names.

So Tapline watches what lands on you. Any helpful aura whose name is one of the heals it cares about has its spell id remembered and announced, kept account wide, so whichever character was standing near a druid teaches the rest. A heal it has no id for is not drawn at all, rather than left as a row that can never fill.

If one is missing and you would rather not wait, `/tapline learn` takes a spell id, or a spell link shift clicked into the chat box.

## The look

The bars wear the Cooldown Manager's own art, copied at runtime and **measured** rather than guessed at: the real fill, the frame, the spark, the icon's mask and the shadow round it, each stored as a share of the bar or icon it belongs to, so they keep their shape at any size. Where this client has not got a piece, one is made here instead, and `/tapline debug` says which you got for each.

## Options

`/tapline`, or Esc, Options, AddOns, Tapline. It is Tapline's own page hosted in the game's window rather than a Blizzard settings page, deliberately: registering settings the Blizzard way puts an addon's mark on Blizzard's own code on this client, and the game then starts refusing its own reads.

| | |
| --- | --- |
| Bar width, bar height, icon size | the shape of a row |
| Gap between icon and bar, gap between rows | spacing, both able to close to nothing |
| Bar opacity, bar background opacity | the row itself |
| Background opacity, border opacity | the box behind the rows |
| Scale | all of it together |
| Icon shadow depth, spark size | 0 to 4 layers, and how big the spark is |
| Redraws a second | how often the preview is redrawn |
| The heal bars, a button on the minimap | what to show |
| Preview | run the bars on a made-up timer, to judge a layout without a healer |
| A spark at the end of the fill | on or off |
| Always draw a frame round the bar | when the copied art is not to taste |
| Plain bars | skip the copied art entirely |
| Make a noise when a heal lands | and which sound, for landing and for running out |

The sound names are half guesswork against file ids, so press a number to hear it. Greyed out means this client refuses that file. `/tapline sound try` plays every one in turn.

## Commands

| Command | What it does |
| --- | --- |
| `/tapline` | open the options page |
| `/tapline learn <spell id or link>` | teach it a heal this client has that it cannot name |
| `/tapline forget` | throw away every learned spell id |
| `/tapline bars` | show or hide the heal bars |
| `/tapline test` | run the bars on a made-up timer |
| `/tapline width <120-480>` \| `height <14-56>` | the size of one row |
| `/tapline gap <-40-40>` \| `rowgap <-20-30>` | room beside the icon, and between rows |
| `/tapline spark` \| `sparksize <0.5-4>` | the mark at the end of the fill |
| `/tapline shadow <0-4>` | how deep the shadow round an icon is |
| `/tapline edge` | always draw a frame round the bar |
| `/tapline plain` | turn the copied art off |
| `/tapline barbg <0-1>` | how dark the plate inside a bar is |
| `/tapline rate <5-60>` | how often the preview is redrawn |
| `/tapline minimap` | show or hide the minimap button |
| `/tapline sound` | list the sounds and set them |
| `/tapline debug` | what this client actually let the addon read |
| `/tapline reset` | put the bars back in the middle |

Drag the bars to move them. Everything is saved per character; learned spell ids are shared by all of them.

## `/tapline debug`

Send this with anything that looks wrong. It walks every call the addon leans on and prints what each one did: missing, refused and in whose words, or answered with a secret value. It also says where every frame actually is, which art was copied and which was made here, and how many times the tick has run, because a display that never updates and a client that refuses to answer look identical from the outside.

The whole report is written into `TaplineDB.log` a few seconds after every login, so it can be read off disk after a `/reload` without catching it in chat.

## Notes

- Built for the WoW: Forever client (Interface 16001).
- The minimap button opens the options on a left click and hides the bars on a right click, and drags round the edge of the map.
- Tapline once had a Life Tap readout, which is where the name comes from, and it was removed. Your own health and mana are secret to addons on this client too, so it could never do the arithmetic it was meant for: it could only show what a tap costs, which the spell tooltip already tells you. Knowing whether a heal is on you turns out to be the half of the question that can still be answered, and the half worth answering.
