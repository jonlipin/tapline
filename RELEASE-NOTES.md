## 1.17.2

### Fixed
- Error on every tick: `calling 'GetWidth' on bad self (Attempt to access forbidden object)`. The bars handed to the game become forbidden objects, and the spark glide was calling methods on them. They are now marked as the game's when handed over, and neither the glide nor the smoothing touches them. Their countdown is secret anyway, so there was never anything to do with them.
- Any other bar the client has since made forbidden is detected by asking `IsForbidden`, and skipped from then on.
