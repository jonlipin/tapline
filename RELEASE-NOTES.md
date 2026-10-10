## 1.18.0 - 2026-10-10

### Added
- A Look section in the options with a window style: Automatic, Blizzard or Dark. Automatic uses EllesmereUI's look when it is running and Blizzard's otherwise. Dark is a flat dark style built in and needs no other addon. A Dark background opacity slider sets how much of the world shows through it, grayed out unless Dark is chosen. Switching from Blizzard to a drawn style happens at once; leaving a drawn style takes a reload, and Tapline offers one.
- `/tapline style auto | blizzard | dark` sets the window style from chat, or steps to the next one with no word after it.
- Under Dark or EllesmereUI the heal bars go flat: a fill in the style's accent color, a dark track with a thin edge and square icons, on the game's bars and on Tapline's own rows underneath them alike, so the swap between them stays invisible. The box behind the bars goes flat too and keeps its background and border opacity settings. A change of style or accent remakes the bars, waiting for the end of a fight if you are in one.
- EllesmereUI support: Tapline's options window follows EllesmereUI's look and accent color. The window shows a copy of the page of its own to restyle, so the same page in Esc > Options keeps the game's look. The minimap button is never restyled.

### Fixed
- The options page in Esc > Options could open empty the first time, if Tapline's own window had borrowed the page before then.
- The page Tapline's window borrowed was never given back, so the game's page could stay empty. It now comes back whenever the game's page opens, and a window left showing nothing closes.
- The close button on Tapline's options window works in combat.
- The minimap button stays where a minimap button collector, such as EllesmereUI's, puts it, instead of jumping back to the edge of the map.
