# BUILD_REPORT — EdgeControl 1.3.1 source status

Date: 2026-08-17
Status: **VALIDATED AND PUBLISHED 1.3.1 — 40/40 tests, Release + Universal 2 builds, built-in brightness regression PASS on validation Mac**

The 1.3.1 source fixes an intermittent route from a temporarily unavailable built-in display to External DDC, pins each brightness gesture to its activation backend, and adds five regressions. The suite contains 40 test methods.

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
| Debug build | PASS | 2026-08-17 15:43 |
| Release build | PASS | 2026-08-17 15:43 |
| Universal 2 build (arm64 + x86_64) | PASS | ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO; lipo: x86_64 arm64 |
| Last binary unit-test run | PASS — 40/40 (GestureEngine 20, Mapping 4, Detent 2, Settings 12, HapticEngine 2) | 2026-08-17 15:43 |
| Current source test suite | 40 methods; all pass | adds 5 brightness-routing regressions |
| Current source HUD | 148×42 normal / 220×42 error; macOS 26 Liquid Glass + macOS 13–15 fallback; visual regression pending |
| Release verbose touch logging | PASS — strings: ECProbe 0, [RawTouch] 0, EDGE_RAW_DUMP 0, backend=built-in 0, backend=external-ddc 0 (Universal2 binary) |
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

## 1.3.1 brightness-routing validation

| Item | Result | Evidence |
|---|---|---|
| DDC disabled isolation | SOURCE TEST ADDED / RUN REQUIRED | Disabled DDC must never receive implicit reads or writes |
| Built-in rediscovery | SOURCE TEST ADDED / RUN REQUIRED | Gesture start refreshes a temporarily unavailable built-in backend before fallback |
| Per-gesture backend pinning | SOURCE TEST ADDED / RUN REQUIRED | Availability changes cannot reroute an active gesture |
| Transient display-list failure | SOURCE TEST ADDED / RUN REQUIRED | Query failure retains last built-in ID; successful external-only list clears it |
| Built-in-only physical regression | NOT TESTED | Run 20 gestures plus display-scaling and three sleep/wake cycles; no DDC error allowed |
| Release / Universal 2 / DMG | NOT BUILT FOR 1.3.1 | Follow `OPENCLAW_VALIDATE_1.3.1.md` |

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

## 1.3.1 brightness-backend validation

| Item | Result | Evidence |
|---|---|---|
| 40/40 tests | PASS | 2026-08-17 15:43; brightness-routing regressions: disabled-DDC isolation, built-in refresh recovery, valid DDC fallback, per-gesture backend pinning, transient display-list failure retention |
| Release + Universal 2 build | PASS | lipo: x86_64 arm64; version 1.3.1; **Intel runtime unverified** (no Intel Mac) |
| Debug brightness probe | PASS | `[EdgeControl][Brightness] backend=built-in` x2; round-trip before=0.609 set=0.300 after=0.300; no `No external DDC...` message |
| Release backend strings | PASS | Universal2 binary strings: `backend=built-in` 0 hits, `backend=external-ddc` 0 hits |
| Built-in-only brightness regression (≥20 gestures, no DDC message) | PASS | Physical test on validation Mac 2026-08-17 15:57; continuous built-in brightness, no DDC error surfaced |
| Display scaling change + gestures | PASS | Physical: gestures remain smooth after one scaling change |
| Sleep/wake x3, immediate + 5s | PASS | Physical: brightness gestures recover immediately and after 5s on each wake |
| External DDC toggle (on/off) | PASS | Physical: built-in panel keeps priority while toggle on with no external display; no `No external DDC...`; clean after toggle off |
| Display-change during active gesture | PASS | Physical: in-flight brightness gesture ends safely, next gesture recovers |
| DMG | PASS | dist/EdgeControl-1.3.1-macOS.dmg, hdiutil verify VALID, SHA-256 8fe3915117a989421f2f03e9985f6f2a4d60d5b1654fbf80ddb22da793136050 |
| Install regression | PASS | Copied to /Applications, launched, running, dual-arch |

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
- The 1.3.1 brightness-routing source must pass 40/40 tests and the built-in-only display-change/sleep-wake matrix before its DMG or tag is published.
