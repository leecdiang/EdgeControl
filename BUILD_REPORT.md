# BUILD_REPORT — EdgeControl 1.3.0 source status

Date: 2026-08-17
Status: **AUTOMATED CHECKS PASSED; external-hardware matrix NOT TESTED (no Magic Trackpad/Mouse connected); publication pending physical external validation**

The 1.3.0 source includes all 1.2.1 changes plus experimental built-in/external trackpad selection, a fail-closed surface-shape guard designed to reject Magic Mouse, manual rescan, selected-device status, and a live-contact callback watchdog. The suite contains 35 test methods.

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
| Debug build | PASS | 2026-08-17 13:18 |
| Release build | PASS | 2026-08-17 13:19 |
| Universal 2 build (arm64 + x86_64) | PASS | ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO; lipo: x86_64 arm64 |
| Last binary unit-test run | PASS — 35/35 (GestureEngine 20, Mapping 4, Detent 2, Settings 7, HapticEngine 2) | 2026-08-17 13:19 |
| Current source test suite | 35 methods; all pass | includes external-surface shape guard + preference persistence tests |
| Current source HUD | 148×42 normal / 220×42 error; macOS 26 Liquid Glass + macOS 13–15 fallback; visual regression pending |
| Release verbose touch logging | PASS — strings: ECProbe 0, [RawTouch] 0, EDGE_RAW_DUMP 0 (Universal2 binary) |
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
| Palm-while-typing defense | BASELINE PASS / RETEST | 1.1.0 validated left strip 0.8%, ratio 0.75 and zero-cross cancellation; current source uses a 3% candidate corridor, ratio 0.80 and 450ms deadline |
| CoreAudio volume 25/50/75% | PASS | Exact round-trip (osascript ground truth) |
| Volume continuous mapping | PASS | Slow/fast/reverse; 0% and 100% clamps, no out-of-bounds |
| Built-in brightness 25/50/75% | PASS | Exact round-trip via DisplayServices |
| Brightness full range in one swipe | PASS | Down-swipe → 0.000 (screen black), up-swipe → 1.000 |
| Lower-half activation continuity | LOCAL VALIDATION REQUIRED | Starting at a high/low y must preserve the current value; only post-activation delta may change it |
| Trackpad automatic mode | BASELINE PASS / RETEST | Automatic preserves the 1.2.x default-device path; selected-kind metadata is informational |
| Explicit built-in selection | LOCAL VALIDATION REQUIRED | Default built-in is preferred; list enumeration is a fallback |
| Explicit external selection | LOCAL VALIDATION REQUIRED | Requires non-built-in identity and landscape sensor dimensions; first matching device wins |
| Magic Mouse rejection | LOCAL VALIDATION REQUIRED | Portrait sensor dimensions are rejected; confirm against every target device generation |
| External disconnect/rescan | LOCAL VALIDATION REQUIRED | 750 ms active-session callback watchdog restores cursor; manual Rescan must reopen input |
| Haptic (public backend) | BASELINE PASS / RETEST | Public activation tick passed; current 2% detents and external-device routing require regression |
| Haptic (private actuator) | NOT SUPPORTED | MTActuator* symbols absent on macOS 26.5; graceful fallback |
| Cursor freeze | PASS | Frozen only while Active; restores on end/cancel/error/quit; SIGKILL test proves system resets association |
| Sleep/wake | PASS | Trackpad, haptic, volume, brightness all recover |
| External DDC | NOT TESTED | No external monitor on validation machine; experimental toggle, off by default |

## 1.3.0 external-trackpad validation

| Item | Result | Evidence |
|---|---|---|
| MultitouchSupport ABI symbols (8/8) | PASS | dlopen+dlsym runtime probe: MTDeviceCreateDefault/CreateList/IsBuiltIn/GetSensorSurfaceDimensions/Start/Stop, MTRegister/UnregisterContactFrameCallback all present (2026-08-17) |
| Debug selection probe | PASS | `[ECProbe] selected trackpad kind=1 surface=14267x8509 selection=0` (Automatic, built-in, landscape) |
| Release probe exclusion | PASS | Universal2 binary strings: ECProbe 0, RawTouch 0, EDGE_RAW_DUMP 0 |
| Universal 2 | PASS | lipo: x86_64 arm64; DMG-mounted app verified fat; **Intel runtime unverified** (no Intel Mac) |
| Automatic, built-in only | PASS | App launches, built-in input active, no errors |
| Built-in gesture / no-jump / watchdog | UNIT-TEST PASS | 35/35 tests incl. no-jump mapping, preference persistence, shape guard; physical swipe regression pending on validation Mac |
| External Magic Trackpad (all matrix items) | NOT TESTED | No external Magic Trackpad/Mouse connected to validation Mac; required before publication per OPENCLAW_VALIDATE_1.3.0.md |
| Sleep/wake, rescan, disconnect watchdog (physical) | NOT TESTED | Physical external device required |
| DMG | PASS | dist/EdgeControl-1.3.0-macOS.dmg, hdiutil verify VALID, SHA-256 dbc671f88d2c85ea98ced1ee82f85d1fe2f50eaea821dca2e274c747e779062e |
| Install regression | PASS | Copied to /Applications, launched, running, dual-arch |

\* I: a slide-in from the bottom-right corner that stayed pinned in the corner with no vertical intent was rejected (`initialMotionNotInward`), which is the correct outcome; natural diagonals with vertical intent activate.

## Permissions

**No TCC permissions are required.** Raw touch, volume, built-in brightness, and haptic were all verified while the app ran as an `LSUIElement` menu-bar app with no Accessibility, Input Monitoring, Screen Recording, or Full Disk Access granted. No TCC prompts appeared. (Re-validate per macOS version.)

## Signing

- Ad-hoc (`codesign --force --deep --sign -`). No Developer ID certificate present on the validation machine.
- Production notarization requires Developer ID credentials — see [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md).

## Notarization

NOT PERFORMED (no credentials). Ad-hoc DMG is the local deliverable.

## DMG

- `dist/EdgeControl-1.1.0-macOS.dmg` — drag-to-Applications layout verified for the 1.1.0 baseline:
  - `EdgeControl.app` at (145, 175), `Applications` symlink at (410, 175), icon size 104
  - Built with `Scripts/package_dmg.sh` (hdiutil + Finder AppleScript only, no third-party tools)
- Install flow verified: mount → copy app to /Applications → eject → launch → menu bar item appears → settings persist → relaunch works → gestures work.

## Known limitations / experimental

- macOS 26.5 only validated; Intel and other macOS versions untested.
- Native macOS OSD (volume/brightness overlay) cannot be triggered via distributed notifications on macOS 26; the app's own HUD provides visual feedback instead.
- Private trackpad actuator haptics absent on this OS; public haptics are used.
- External DDC: experimental, off by default, untested (no external display).
- The current 450ms deadline, 3% candidate corridor, 0.80 directionality threshold, and 1.2.1 relative lower-half mapping require physical regression before packaging the next DMG.
- The new compact HUD requires checks on light/dark desktops, Reduce Transparency, Reduce Motion, multiple displays, and the macOS 13–15 fallback.
- Trackpad selection is experimental. Automatic mode remains the compatibility default. Explicit external mode chooses the first non-built-in landscape surface, rejects portrait surfaces, and requires manual **Rescan Trackpads** after connection changes.
- Multiple external trackpads, Touch Bar-era built-in enumeration, Magic Mouse filtering, Bluetooth loss, sleep/wake, and perceived haptic routing all require physical validation. No automatic hot-plug switching or per-device calibration is claimed.
