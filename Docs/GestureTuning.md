# Gesture Tuning

All values below were tuned from live hardware traces on the validation machine.

## Test machine

- MacBook Air, Apple Silicon (arm64)
- macOS 26.5.2
- Xcode 26.6, Swift 6.3.3

## Current values

The entry-strip and raw-contact values below come from the reference-machine traces. The 450ms deadline, 3% pre-activation corridor, and 0.80 directionality threshold are a subsequent false-trigger hardening decision and require a short physical regression run before the next binary release.

| Parameter | Value | Where | Rationale (evidence) |
| --- | ---: | --- | --- |
| `leftEntryStripWidth` | 0.008 | `EdgeGestureTypes.swift` | Deliberate left-edge births measured x ≈ 0.0–0.0018; resting-palm births during typing measured x ≈ 0.007–0.010. |
| `rightEntryStripWidth` | 0.015 | `EdgeGestureTypes.swift` | Right-edge births measured x ≈ 0.985–1.0, so the right strip remains wider. |
| `entryCorridor` | 0.03 | `EdgeGestureTypes.swift` | Before activation, remaining within 3% of the edge prevents a horizontal swipe from moving inward and becoming eligible later. |
| `controlCorridor` | 0.08 | `EdgeGestureTypes.swift` | After activation, 8% preserves comfortable vertical control; leaving it cancels the session. |
| `minimumInwardTravel` | 0.0 | `EdgeGestureTypes.swift` | See "Inward travel" below. |
| `outwardRejectionTravel` | 0.004 | `EdgeGestureTypes.swift` | A contact born in the strip that moves away from its edge (toward the pad edge) is rejected as `initialMotionNotInward`. |
| `minimumVerticalMove` | 0.015 | `EdgeGestureTypes.swift` | 1.5% of trackpad height must be covered within the entry deadline for activation ("obvious vertical motion"). |
| `directionalityRatio` | 0.80 | `EdgeGestureTypes.swift` | At least 80% of the pre-activation vertical path must remain in one direction; deliberate traces measured about 0.9+, palm jitter about 0.5–0.6. |
| `entryTimeout` | 0.450 s | `EdgeGestureTypes.swift` | See "Entry deadline" below. |

## Independent adjustment speed and false-touch protection

Adjustment speed is post-activation gain only: Precise `0.75×`, Standard `1.00×`, and Fast `1.35×`. The selected multiplier is pinned at activation. Legacy continuous-sensitivity values migrate to the nearest preset using midpoint thresholds `0.875` and `1.175`.

False-touch protection controls only the recent-typing window and contact-birth strips:

| Profile | Typing window | Left strip | Right strip |
| --- | ---: | ---: | ---: |
| Strong | 600ms | 0.006 | 0.012 |
| Standard | 350ms | 0.008 | 0.015 |
| Light | 200ms | 0.010 | 0.019 |

The 450ms deadline, 3% candidate corridor, 8% Active corridor, 0.80 directionality, 1.5% vertical intent, outward rejection, interior-birth latch and multi-touch latch remain identical across profiles. A contact rejected for recent typing stays rejected until all fingers lift; an Active gesture is never interrupted. Changing admission settings while a contact is down discards it until lift. These profile values are 1.4.0 product assumptions and require physical false-positive/false-negative tuning on the release machine.

## Inward travel (0.008 → 0.0)

The original constant required ≥0.8% inward travel before vertical intent counted. Live raw traces show that edge-pinned contacts report normalized x pinned at 0.0 (left) / 1.0 (right) while the finger slides vertically along the edge; the largest inward excursion ever measured during a slide-in was 0.0011 (0.11%). A positive threshold therefore made every physical edge ingress time out (observed: multiple left-edge slide-ins rejected at 250 ms with 0% inward travel).

Because the hardware pins edge X, physical ingress cannot be proven from X travel alone. It is approximated conservatively by:

1. Birth inside the narrow, independently tuned left/right entry strip;
2. remaining within the 3% pre-activation corridor;
3. `outwardRejectionTravel` — a strip-born contact that moves back toward its edge is rejected;
4. 1.5% vertical intent with at least 80% directional consistency inside 450ms.

Inside-born contacts still never activate: `beginLifecycle` rejects any birth outside the strip for the entire contact lifetime (spec D/E), verified live.

## Entry deadline (250 → 350 → 600 → 800 → 450 ms)

Sequential tuning from live traces of natural slide-ins:

- 250 ms rejected gestures whose vertical push started at 256–331 ms.
- 350 ms recovered 288–331 ms cases but still rejected a 620 ms dwell-then-push.
- 600 ms rejected a 620 ms dwell (the finger rested at the edge before pushing).
- 800 ms accepted the observed dwell-then-push pattern (real vertical motion started ~620 ms after birth, then covered 40% of the height decisively).
- 450 ms is the current product decision: it retains the measured 256–331ms deliberate gestures but intentionally rejects the 620ms dwell because the intended gesture is "enter, then immediately move vertically".

Spec H (pause beyond the deadline, then move → no activation) now rejects any candidate that has not established vertical intent within 450ms. Once a gesture becomes Active, this deadline no longer limits its duration.

## Candidate and active corridors

The candidate and active phases deliberately use different widths. A candidate that goes beyond 3% is terminally rejected until lift, preventing an ordinary inward/horizontal swipe from later turning vertical. After activation, the wider 8% corridor remains available for comfortable adjustment. Synthetic tests cover both rejection at 3.1% and continued Active operation at 6%.

## Directionality hardening (0.75 → 0.80)

The reference traces separated palm jitter (~0.5–0.6) from deliberate slides (~0.9+) cleanly. Raising the threshold to 0.80 also rejects a borderline 0.75 oscillating path. This requirement applies only before activation; deliberate fine adjustment remains available after the session is Active.

## Haptic detents (UX feel, Diang-verified)

- Detent interval 2% (50 value boundaries across the full range).
- Hysteresis 0.008 prevents re-crossing the same boundary from micro-jitter.
- Pulse cooldown 30 ms: preserves denser 2% feedback at normal swipe speed while rate-limiting very fast movement.

## Value mapping (gain 1.15 → 2.0)

With gain 1.15 a single swipe from a mid-trackpad activation could only cover ~55% of the range, so 0% and 100% were unreachable in one gesture (Diang: "滑到最低后不是 0"). With gain 2.0 the full trackpad height (normalized y ∈ [0, 1]) maps to the full value range: sliding to the bottom/top edge clamps to 0/1 from any initial value. Verified live: one down-swipe reached 0.000 (screen black), one up-swipe reached 1.000. Per-device normalization keeps the behavior consistent across Mac models with different trackpad sizes.

## Polarity (y-axis)

On this machine the MultitouchSupport normalized y grows with physical upward motion (y = 0 is the bottom of the trackpad). An upward swipe therefore yields positive deltaY, and `target = initial + deltaY × gain` increases the value — matching volume/brightness key convention. Verified with a directed up-swipe (volume 30 → 59) then down-swipe. Re-validate the sign on other hardware/OS combos.
