# EdgeControl 1.7.5

Reliability improvements for edge gestures and built-in brightness.

- Deduplicate successful brightness writes within each gesture at DisplayServices Float precision, including repeated 0%/100% targets. Failed writes remain retryable and a new gesture starts with a fresh cache.
- Horizontal-only movement no longer rewrites volume or brightness. Leaving the edge corridor still cancels the gesture.
- Reject non-finite touch coordinates/timestamps and brightness values instead of allowing clamping to turn invalid data into an endpoint. Invalid touch data cancels active control and requires lift before reentry.
- Clear the previous built-in display ID when CoreGraphics successfully enumerates zero displays; preserve it only on query failure.
- Preserve a haptic detent crossing when the 30ms cooldown suppresses its feedback request. The next eligible movement can request feedback without requiring another full detent; returning to the original bucket or ending the gesture discards the crossing. No delayed feedback timer is introduced.
- Do not advance the haptic cooldown when neither backend can accept a request.
- Add 14 regression tests (90 total).

This release does not claim to fix or establish the cause of the reported Control Center brightness-repeat incident. No key events are synthesized. Entry thresholds, gain presets, HUD appearance, haptic patterns and cooldown duration, and DDC transport remain unchanged.

Validation and package hashes: see VALIDATION_1.7.5.md.
