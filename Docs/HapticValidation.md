# Haptic Validation

Date: 2026-08-16
Machine: MacBook Air (Apple Silicon arm64), macOS 26.5.2, Xcode 26.6

## Public backend (NSHapticFeedbackManager) — VALIDATED

- `NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)`
- Works while the app is a background LSUIElement menu-bar app with no key window (validated during normal use; no TCC prompt).
- Activation tick: one pulse when a gesture reaches Active state. Diang confirms the tap is clearly perceptible.
- Detent ticks: one pulse per crossed 5% bucket, hysteresis 0.008 prevents boundary jitter.

### Tuning (Diang-verified feel)

| Setting | Value | Rationale |
|---|---|---|
| Detent interval | 5% (0.05) | 20 steps across the full range; Diang requested "从顶端到低端二十下" (20 ticks per full-range swipe) |
| Hysteresis | 0.008 | Suppresses repeated crossing of the same boundary from micro-jitter |
| Pulse cooldown | 0.05s | 120ms felt too sparse (max ~8 pulses/s). 50ms renders all 20 five-percent steps as discrete ticks at normal swipe speed (~20Hz cap) while clipping the >30Hz buzz of very fast flicks |

Verified live: slow full-range swipe = ~20 distinct ticks; fast flick = discrete ticks, no continuous buzz. Diang: "合适" (appropriate).

## Private trackpad actuator backend — NOT SUPPORTED on this OS

- Symbols `MTActuatorCreateFromDevice`, `MTActuatorOpen`, `MTActuatorActuate`, `MTActuatorClose` are **absent** from MultitouchSupport.framework and from every system private framework on macOS 26.5 (verified via `strings`/`nm` across all private frameworks).
- `TrackpadActuatorBackend.isAvailable` therefore returns false; `HapticEngine.selectedBackend()` falls back to the public backend. Graceful degradation confirmed — the app runs normally with public haptics.
- The backend remains behind `EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1` and is disabled by default.

## Notes

- No competitor haptic constants were copied; pattern values were never needed because the actuator API does not exist on this OS.
- TCC permissions required: none (see BUILD_REPORT.md Permissions).
