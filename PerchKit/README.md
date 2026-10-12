# PerchKit

The small piece of [Poff](../README.md) that decides **where a ghost can sit on your windows** and **when a window is being shaken**. Pure Swift, CoreGraphics only, no UI.

- `PerchFinder` picks a spot on the top edge of a real window. It skips edges hidden behind windows in front, keeps the ghost inside a screen, and leaves room between ghosts.
- `Occlusion` checks whether a point on a window is visible, given windows ordered front to back.
- `WindowMotionTracker` turns a stream of window frames into velocities, and flags a shake after **3 fast direction reversals within 1 second**.
- `DragShakeDetector` applies the same rule to anything you drag.

Coordinates are CG global coordinates (origin top-left of the main display, y down), the same space `CGWindowListCopyWindowInfo` uses for window bounds.

## Use

```swift
import PerchKit

var motion = WindowMotionTracker()
var rng = SystemRandomNumberGenerator()

// windows: front to back, e.g. from CGWindowListCopyWindowInfo (bounds only)
let result = motion.update(windows, at: ProcessInfo.processInfo.systemUptime)
if result.shaken.contains(window.id) { /* tumble off */ }

let spot = PerchFinder.find(windows: windows, ghostSize: GhostMetrics.size,
                            regions: screenFrames, taken: occupiedSpots, using: &rng)
```

## Test

```sh
swift test
```

MIT licensed. Only this folder is open source; the rest of Poff is not.
