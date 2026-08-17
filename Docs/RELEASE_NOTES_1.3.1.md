# EdgeControl 1.3.1

Brightness-backend reliability fix for MacBooks without an external display.

## Fixed

- A transient built-in display enumeration failure no longer routes brightness control to External DDC when DDC is disabled or unavailable.
- A failed CoreGraphics display-list query preserves the last known built-in display ID; a successful list with no built-in display still clears it for clamshell mode.
- Each brightness gesture pins the backend selected at activation, preventing a display notification from switching the gesture between the built-in panel and DDC.
- Display reconfiguration and DDC setting changes safely end an in-flight brightness session before refreshing backends; volume gestures are unaffected.
- Gesture start retries built-in display discovery before considering the explicitly enabled DDC fallback.
- Misleading `No external DDC display is available` errors are no longer emitted on a built-in-only Mac, even if the experimental toggle was previously enabled but no DDC connection exists.

## Tests

- Five brightness-routing regressions cover disabled-DDC isolation, built-in refresh recovery, valid DDC fallback, per-gesture backend pinning, and transient display-list failure retention.
- The source suite now contains 40 XCTest methods.

## Validation required

- Run all 40 tests and Release/Universal 2 builds on macOS.
- On a built-in-only Mac, repeat brightness gestures before and after display-parameter notifications and sleep/wake; no DDC error may appear.
- External DDC remains experimental and requires a real compatible monitor before support is claimed.
