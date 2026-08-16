# Gesture Tuning

All values below were tuned from live hardware traces on the validation machine.

## Test machine

- MacBook Air, Apple Silicon (arm64)
- macOS 26.5.2
- Xcode 26.6, Swift 6.3.3

## Final values

| Parameter | Value | Where | Rationale (evidence) |
| --- | ---: | --- | --- |
| `entryStripWidth` | 0.015 | `EdgeGestureTypes.swift` | 1.5% from each physical edge. Live births on this machine land at x = 0.0 (left) and x = 1.0 / 0.99 (right) for slide-ins; interior births (x > 0.015) are rejected permanently. |
| `controlCorridor` | 0.08 | `EdgeGestureTypes.swift` | 8% from the active edge. A slide-in that keeps running toward the center exits the corridor and cancels (spec G), verified live. |
| `minimumInwardTravel` | 0.0 | `EdgeGestureTypes.swift` | See "Inward travel" below. |
| `outwardRejectionTravel` | 0.004 | `EdgeGestureTypes.swift` | A contact born in the strip that moves away from its edge (toward the pad edge) is rejected as `initialMotionNotInward`. |
| `minimumVerticalMove` | 0.015 | `EdgeGestureTypes.swift` | 1.5% of trackpad height must be covered within the entry deadline for activation ("obvious vertical motion"). |
| `entryTimeout` | 0.800 s | `EdgeGestureTypes.swift` | See "Entry deadline" below. |

## Inward travel (0.008 → 0.0)

The original constant required ≥0.8% inward travel before vertical intent counted. Live raw traces show that edge-pinned contacts report normalized x pinned at 0.0 (left) / 1.0 (right) while the finger slides vertically along the edge; the largest inward excursion ever measured during a slide-in was 0.0011 (0.11%). A positive threshold therefore made every physical edge ingress time out (observed: multiple left-edge slide-ins rejected at 250 ms with 0% inward travel).

The inward character of the gesture is now enforced by:

1. Birth inside the 1.5% entry strip (only possible by entering from the physical outside), and
2. `outwardRejectionTravel` — a strip-born contact that moves back toward its edge is rejected.

Inside-born contacts still never activate: `beginLifecycle` rejects any birth outside the strip for the entire contact lifetime (spec D/E), verified live.

## Entry deadline (250 → 350 → 600 → 800 ms)

Sequential tuning from live traces of natural slide-ins:

- 250 ms rejected gestures whose vertical push started at 256–331 ms.
- 350 ms recovered 288–331 ms cases but still rejected a 620 ms dwell-then-push.
- 600 ms rejected a 620 ms dwell (the finger rested at the edge before pushing).
- 800 ms accepts the observed dwell-then-push pattern (real vertical motion started ~620 ms after birth, then covered 40% of the height decisively).

Spec H (pause beyond the deadline, then move → no activation) still holds: a 488 ms and a >800 ms deliberate pause were both rejected.

## Haptic detents (UX feel, Diang-verified)

- Detent interval 5% (20 ticks across the full range — Diang requested "从顶端到低端二十下").
- Hysteresis 0.008 prevents re-crossing the same boundary from micro-jitter.
- Pulse cooldown 50 ms: renders all twenty 5% steps as discrete ticks at normal swipe speed (~20 Hz cap) while clipping the >30 Hz buzz of very fast flicks. Diang rated the final feel "合适".

## Value mapping (gain 1.15 → 2.0)

With gain 1.15 a single swipe from a mid-trackpad activation could only cover ~55% of the range, so 0% and 100% were unreachable in one gesture (Diang: "滑到最低后不是 0"). With gain 2.0 the full trackpad height (normalized y ∈ [0, 1]) maps to the full value range: sliding to the bottom/top edge clamps to 0/1 from any initial value. Verified live: one down-swipe reached 0.000 (screen black), one up-swipe reached 1.000. Per-device normalization keeps the behavior consistent across Mac models with different trackpad sizes.

## Polarity (y-axis)

On this machine the MultitouchSupport normalized y grows with physical upward motion (y = 0 is the bottom of the trackpad). An upward swipe therefore yields positive deltaY, and `target = initial + deltaY × gain` increases the value — matching volume/brightness key convention. Verified with a directed up-swipe (volume 30 → 59) then down-swipe. Re-validate the sign on other hardware/OS combos.
