# EdgeControl 1.5.1

A focused reliability update for edge gestures, Strong haptics, and multi-display DDC.

## Fixed

- Zero-cross cancellation is anchored to the gesture's committed activation direction, closing the gradual deadband-crossing bypass.
- Pending secondary Strong pulses are lifecycle-owned and cancelled on gesture end or wake reset.
- External DDC writes reuse the connection that answered the initial session read.
- Haptic enablement and strength controls are colocated in Settings.
- Bundle build metadata now follows `CURRENT_PROJECT_VERSION` (build 2).

## Tests and validation

- Four new regressions bring the source suite to 60 XCTest methods.
- Source-side repository validation passes.
- Run `OPENCLAW_VALIDATE_1.5.1.md` on macOS before publishing; real haptic and DDC behavior cannot be established by synthetic tests alone.
