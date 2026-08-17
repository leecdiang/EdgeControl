# EdgeControl 1.2.1

A stability release that removes value jumps when a lower-half edge gesture begins.

## Fixed

- Lower-half mode no longer writes the finger's absolute entry height directly to volume or brightness. Entering near the midline can no longer force the value toward 100%.
- Every accepted gesture now anchors to the system value captured at activation and applies only cumulative vertical movement after that. Activation itself leaves the value unchanged.
- The repository validation guard now accepts added tests while still failing if the suite drops below the 32-test baseline. CI was previously blocked by a hard-coded count of 29.

## Clarified

- "Start in lower half only" is an admission filter. Contacts born above the normalized trackpad midline are rejected; accepted gestures use the same relative adjustment as normal mode.
- Settings and README text now describe the no-jump behavior accurately.

## Validation

- Repository validation, all 32 unit tests, and a clean Release build pass.
- With the lower-half start filter on, entering at low, middle, and high positions keeps the value unchanged on the first frame; movement after activation stays continuous in both directions.
- Compact HUD, 2% haptics, Release logging guards, DMG install flow, and SHA-256 rechecked.

SHA-256: `46f58e1192fb089dc346925fe3cc6da9c92245cfcede115ebeea3b164a01e041`
