# BUILD_REPORT — EdgeControl 1.0.0

Date: 2026-08-16/17
Status: **RELEASE READY (ad-hoc signed)**

## Environment

| Item | Value |
|---|---|
| Mac model | MacBook Air (Apple Silicon) |
| CPU architecture | arm64 |
| macOS | 26.5.2 |
| Xcode | 26.6 (Build 17F113) |
| Swift | 6.3.3 |
| Deployment target | macOS 13.0 |
| Swift concurrency | strict complete |

## Build

| Item | Result |
|---|---|
| Debug build | PASS |
| Release build | PASS |
| Unit tests | PASS — 23/23 (GestureEngine 12, Mapping 3, Detent 2, Settings 3, HapticEngine 2, +1 timeout regression) |
| Release verbose touch logging | OFF (EDGE_DEBUG_LOGGING is Debug-only; verified via binary inspection) |
| No network/telemetry | PASS (otool/nm: no network frameworks, no analytics symbols) |

## Hardware validation

| Item | Result | Evidence |
|---|---|---|
| Private MultitouchSupport loads | PASS | Callback fires on macOS 26.5 arm64 |
| MT contact ABI | PASS | Raw byte dump proved stride is 96 bytes (not 80); ghost contacts eliminated |
| Raw touch output (id/birth/current/dx/dy/fingers/phase) | PASS | Live traces |
| Left ingress up (A) | PASS | 8–339 ms activation latencies |
| Left ingress down (B) | PASS | |
| Right ingress up/down (C) | PASS | 11–16 ms activation latencies |
| Interior-born rejection (D/E) | PASS | Never activates, entire contact lifetime |
| Edge tap without ingress (F) | PASS | No activation |
| Inward run to center (G) | PASS | Corridor-exit cancel |
| Pause beyond deadline then move (H) | PASS | No activation |
| Natural diagonal (I) | PASS* | Corner-press diagonals without vertical intent correctly rejected |
| Two-finger scroll (J) | PASS | Never activates |
| Two-finger → lift one (K) | PASS | Latched until all fingers lift |
| Real-use false triggers | PASS | 1–2 min typing/scrolling: 0 activations |
| CoreAudio volume 25/50/75% | PASS | Exact round-trip (osascript ground truth) |
| Volume continuous mapping | PASS | Slow/fast/reverse; 0% and 100% clamps, no out-of-bounds |
| Built-in brightness 25/50/75% | PASS | Exact round-trip via DisplayServices |
| Brightness full range in one swipe | PASS | Down-swipe → 0.000 (screen black), up-swipe → 1.000 |
| Haptic (public backend) | PASS | Activation tick + 5% detents; LSUIElement background app |
| Haptic (private actuator) | NOT SUPPORTED | MTActuator* symbols absent on macOS 26.5; graceful fallback |
| Cursor freeze | PASS | Frozen only while Active; restores on end/cancel/error/quit; SIGKILL test proves system resets association |
| Sleep/wake | PASS | Trackpad, haptic, volume, brightness all recover |
| External DDC | NOT TESTED | No external monitor on validation machine; experimental toggle, off by default |

\* I: a slide-in from the bottom-right corner that stayed pinned in the corner with no vertical intent was rejected (`initialMotionNotInward`), which is the correct outcome; natural diagonals with vertical intent activate.

## Permissions

**No TCC permissions are required.** Raw touch, volume, built-in brightness, and haptic were all verified while the app ran as an `LSUIElement` menu-bar app with no Accessibility, Input Monitoring, Screen Recording, or Full Disk Access granted. No TCC prompts appeared. (Re-validate per macOS version.)

## Signing

- Ad-hoc (`codesign --force --deep --sign -`). No Developer ID certificate present on the validation machine.
- Production notarization requires Developer ID credentials — see [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md).

## Notarization

NOT PERFORMED (no credentials). Ad-hoc DMG is the local deliverable.

## DMG

- `dist/EdgeControl-1.0.0-macOS.dmg` — drag-to-Applications layout verified:
  - `EdgeControl.app` at (145, 175), `Applications` symlink at (410, 175), icon size 104
  - Built with `Scripts/package_dmg.sh` (hdiutil + Finder AppleScript only, no third-party tools)
- Install flow verified: mount → copy app to /Applications → eject → launch → menu bar item appears → settings persist → relaunch works → gestures work.

## Known limitations / experimental

- macOS 26.5 only validated; Intel and other macOS versions untested.
- Native macOS OSD (volume/brightness overlay) cannot be triggered via distributed notifications on macOS 26; the app's own HUD provides visual feedback instead.
- Private trackpad actuator haptics absent on this OS; public haptics are used.
- External DDC: experimental, off by default, untested (no external display).
