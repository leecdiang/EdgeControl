# Haptic Validation

Date: 2026-08-16
Machine: MacBook Air (Apple Silicon arm64), macOS 26.5.2, Xcode 26.6

## Public backend (NSHapticFeedbackManager) — BASELINE VALIDATED

- `NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)`
- Works while the app is a background LSUIElement menu-bar app with no key window (validated during normal use; no TCC prompt).
- Activation tick: one pulse when a gesture reaches Active state. Diang confirms the tap is clearly perceptible.
- Standard detent ticks: one alignment pulse per crossed 2% bucket; hysteresis 0.008 prevents boundary jitter and the 30ms cooldown limits very fast swipes.

### Three-level strength profiles

AppKit exposes feedback patterns, not an amplitude parameter. EdgeControl therefore implements three perceived-strength profiles without guessing private actuator constants:

| Profile | Public pattern | Detents | Status |
|---|---|---|---|
| Light | `.alignment` | 4% | LOCAL_VALIDATION_REQUIRED |
| Standard | `.alignment` | 2% | Preserves the existing implementation |
| Strong | `.generic` | 2% | LOCAL_VALIDATION_REQUIRED |

All profiles keep hysteresis `0.008` and the 30ms rate limit. The selected profile is pinned for the gesture. Physical intensity is hardware- and macOS-dependent, so the Light/Strong feel must be checked on both built-in and external Force Touch trackpads before release.

## Private trackpad actuator backend — NOT SUPPORTED on this OS

- Symbols `MTActuatorCreateFromDevice`, `MTActuatorOpen`, `MTActuatorActuate`, `MTActuatorClose` are **absent** from MultitouchSupport.framework and from every system private framework on macOS 26.5 (verified via `strings`/`nm` across all private frameworks).
- `TrackpadActuatorBackend.isAvailable` therefore returns false; `HapticEngine.selectedBackend()` falls back to the public backend. Graceful degradation confirmed — the app runs normally with public haptics.
- The backend remains behind `EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1` and is disabled by default.

## Notes

- No competitor haptic constants were copied; pattern values were never needed because the actuator API does not exist on this OS.
- TCC permissions required: none (see BUILD_REPORT.md Permissions).
