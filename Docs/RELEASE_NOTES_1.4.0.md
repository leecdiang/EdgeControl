# EdgeControl 1.4.0

Adds independent adjustment speed and privacy-preserving false-touch protection.

## New

- Adjustment speed is independently selectable as Precise (`0.50×`), Standard (`0.70×`), or Fast (`0.95×`) and affects only post-activation value gain.
- False-touch protection is independently selectable as Strong, Standard, or Light. It combines 600/350/200ms typing windows with 0.6%/0.8%/1.0% left and 1.2%/1.5%/1.9% right edge-birth ranges.
- Existing continuous-sensitivity preferences migrate to the nearest adjustment-speed preset.
- EdgeControl queries only the elapsed time since the last Quartz key-down event. It does not install a keyboard event tap, inspect key values, or store keyboard activity.
- Recent typing can reject an idle or pre-activation edge lifecycle. The rejection stays latched until every finger lifts, so a palm cannot activate merely by remaining down until the timer expires.
- An already active volume or brightness gesture is never interrupted by the typing guard.
- Adjustment speed is pinned at activation. Admission-setting changes while a finger is down discard that lifecycle until lift.
- Lower-half-only remains an independent optional filter and is no longer the only strong palm-protection choice.

## Included reliability fixes

- Includes the 1.3.1 built-in-brightness routing fix: transient panel enumeration failures no longer implicitly route a built-in-only Mac to External DDC.
- Brightness gestures pin their activation backend, and display changes safely end only an in-flight brightness session before refresh.

## Tests

- Twelve new regressions cover typing rejection/latching, Active continuity, profile timing and asymmetric entry ranges, hard-rule invariance, speed gain, legacy migration, invalid preferences, and invalid Quartz elapsed-time handling.
- The source suite now contains 52 XCTest methods.

## Validation required

- Run all 52 tests and Release/Universal 2 builds on macOS.
- Physically verify all three adjustment-speed and false-touch-protection presets, including the 600ms, 350ms, and 200ms boundaries and both asymmetric entry strips.
- On a clean macOS account, prove that the elapsed-time query does not trigger Accessibility or Input Monitoring prompts.
- Repeat the 1.3.1 built-in-only brightness matrix. External Magic Trackpad, external DDC, Intel runtime, Developer ID signing, and notarization remain unverified.
