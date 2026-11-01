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

All profiles keep hysteresis `0.008` and the 30ms rate limit. The selected profile is pinned for the gesture. Strong's second pulse is scheduled 12ms later and cancelled if the gesture ends or wake recovery resets the engine. Physical intensity is hardware- and macOS-dependent, so the Light/Strong feel must be checked on both built-in and external Force Touch trackpads before release.

For 1.5.1, end a Strong gesture immediately after its primary tick and repeat across sleep/wake. No delayed secondary tick may be felt after end/reset; the two cancellation paths also have automated regressions.

## Private trackpad actuator backend — NOT SUPPORTED on this OS

- Symbols `MTActuatorCreateFromDevice`, `MTActuatorOpen`, `MTActuatorActuate`, `MTActuatorClose` are **absent** from MultitouchSupport.framework and from every system private framework on macOS 26.5 (verified via `strings`/`nm` across all private frameworks).
- `TrackpadActuatorBackend.isAvailable` therefore returns false; `HapticEngine.selectedBackend()` falls back to the public backend. Graceful degradation confirmed — the app runs normally with public haptics.
- The backend remains behind `EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1` and is disabled by default.

## Notes

- No competitor haptic constants were copied; pattern values were never needed because the actuator API does not exist on this OS.
- TCC permissions required: none (see BUILD_REPORT.md Permissions).

## 1.7.5 cooldown regression (2026-11-01)

A deterministic trace against the original HapticEngine reproduced a lost detent request: activation at 0.50/t=0 requested one pulse; 0.55/t=10ms crossed a detent but cooldown suppressed it; 0.551/t=40ms and 0.552/t=80ms requested no further feedback because the suppressed crossing had already advanced the bucket. This matches intermittent missing ticks during an otherwise working adjustment, not a proven complete hardware-feedback outage.

The fix commits the candidate detent bucket only after a request reaches an available backend, and advances cooldown only on that path. Repeating the trace requests a second pulse at 40ms and no duplicate at 80ms. Existing 30ms throttling, patterns, and Strong-secondary cancellation remain intact. No deferred detent timer is added; a return to the prior bucket or gesture end prevents stale replay. Four new XCTest regressions cover these cases and unavailable backends.

The public AppKit performer returns no hardware-delivery acknowledgement. Apple documents that the system may suppress requests and that the default performer depends on input device and preferences. Unit tests and the synthetic trace establish request behavior, not physical actuator delivery on macOS 27.0.1. Physical verification remains required.
