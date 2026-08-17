# EdgeControl

> Two edges. Two controls. Nothing else.

[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文**](README_zh.md)

<img src="assets/icon-512.png" alt="EdgeControl icon" width="128" height="128" align="left" style="margin-right: 16px;">

EdgeControl is an open-source, offline macOS menu-bar utility that maps a deliberate physical-edge ingress on a MacBook trackpad to continuous volume or brightness control.

## Usage

**The gesture starts from the machine's body, not on the trackpad.**

1. Slide a finger **from the laptop body onto the trackpad's left or right edge** (the finger enters the trackpad from outside).
2. Immediately after entering, slide **up or down** along the edge.
3. The left edge and right edge are independently assignable: Off / Volume / Brightness.
4. A finger that first touches the trackpad **interior** never triggers — even if it later slides to an edge.

This is not a plain "touch the edge, then move" gesture: the contact must be **born at the extreme edge** (the entry strip) and establish clear vertical intent within a short deadline. Interior-born contacts are permanently rejected for the whole contact lifetime, and any multi-touch frame rejects the entire current lifecycle until every finger lifts.

## Status

Hardware-validated on macOS 26.5 (Apple Silicon MacBook Air) on 2026-08-16/17. See [BUILD_REPORT.md](BUILD_REPORT.md) for the per-item PASS/FAIL matrix and [Docs/GestureTuning.md](Docs/GestureTuning.md) for the tuned recognizer values.

The gesture recognizer, value mapping, detent, haptic, and settings layers are covered by 31 unit tests. Code that depends on undocumented macOS ABIs is dynamically loaded (`dlopen`/`dlsym`), fails closed, and treats missing symbols as feature unavailability rather than fatal errors.

## Features

- Physical left-edge and right-edge ingress recognition
- Independent edge assignment: Off, Volume, or Brightness
- Master, volume, brightness, haptic, HUD, sensitivity, launch-at-login, and external-DDC settings
- Continuous value mapping from the gesture’s activation value (full trackpad height maps to the full 0–100% range)
- CoreAudio volume control with default-output re-resolution and unsupported-device handling
- Built-in display brightness through runtime-loaded DisplayServices
- Optional, isolated DDC/CI VCP `0x10` external-display backend (experimental, off by default)
- Activation haptic plus 2% value detents with hysteresis and rate limiting
- Optional lower-half-only mode: edge control responds only below the trackpad midline (midline = 100%, bottom = 0%); contacts born above the midline are rejected
- Pointer freeze only after the gesture reaches `Active`; the system restores the cursor if the app dies
- Compact 148×42 single-row HUD: native Liquid Glass on macOS 26, ultra-thin material fallback on macOS 13–15
- `LSUIElement` menu-bar app with no Dock icon
- Synthetic gesture tests; no physical trackpad required for recognizer tests
- No account, network, analytics, telemetry, or backend

## Lower half only

By default, the full trackpad height maps to the full 0-100% range. With the "Lower half only" setting enabled (Settings > System), edge control responds only to the lower half of the trackpad: the midline maps to 100%, the very bottom to 0%. Contacts that first touch above the midline are rejected, which helps when the upper half of the trackpad tends to catch resting palms or stray touches. Positions are normalized per trackpad, so the midline adapts to every Mac model automatically.

## Requirements

- Validated on macOS 26.5 (Apple Silicon, MacBook Air). Other macOS versions and Intel are untested — treat as experimental.
- Xcode 26.x was used for validation. The deployment target is macOS 13; other Xcode versions are not yet part of the tested matrix.
- A built-in Force Touch trackpad for the intended UX.

Private interfaces can vary by OS release and hardware. External DDC support is experimental and off by default.

## Build

```bash
./Scripts/build_release.sh test
./Scripts/build_release.sh build
```

The script disables code signing for local compilation when no `DEVELOPMENT_TEAM` is present. Release signing is ad-hoc on this machine (no Developer ID available); see [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md) for the production path.

## Package a drag-to-Applications DMG

```bash
./Scripts/package_dmg.sh \
  ./build/DerivedData/Build/Products/Release/EdgeControl.app \
  ./dist/EdgeControl-1.2.0-macOS.dmg
```

The script uses only macOS-provided tools (`hdiutil`, Finder/AppleScript, `codesign`, `xcrun`). It stages `EdgeControl.app` on the left and an `Applications` symlink on the right, then converts to a compressed read-only DMG. Verified layout: App at (145,175), Applications at (410,175), icon size 104.

## Gesture model

Tuned values (see [Docs/GestureTuning.md](Docs/GestureTuning.md) for evidence):

| Parameter | Value | Notes |
| --- | ---: | --- |
| Left entry strip | 0.8% | Birth must land here; interior births are permanently rejected |
| Right entry strip | 1.5% | Wider to match right-edge birth positions observed on the reference machine |
| Pre-activation corridor | 3% from the candidate edge | Prevents a horizontal swipe from travelling inward and becoming eligible later |
| Active control corridor | 8% from the active edge | Preserves comfortable control room; leaving it cancels the gesture |
| Minimum inward travel | 0.0 | Edge-pinned contacts report x pinned at the edge; inward character is enforced by birth-in-strip + outward-motion rejection |
| Minimum vertical movement | 1.5% | Must appear within the entry deadline |
| Directionality | 80% | At least 80% of the pre-activation vertical path must remain in one direction |
| Entry deadline | 450 ms | Keeps measured 256–331ms deliberate entries and rejects the former 620ms dwell-then-push case |

The recognizer transitions through `idle → entryCandidate → entryConfirmed → active`. Interior birth, wrong initial direction, timeout, identity changes, corridor exit, and multi-touch produce terminal rejection for the current lifecycle. `multiTouchRejected` remains latched as fingers go from two to one and resets only on an empty frame.

## Permissions

Validated on this machine: **no TCC permissions are required** (no Accessibility, Input Monitoring, Screen Recording, or Full Disk Access). This was verified while the app ran as an `LSUIElement` menu-bar app. Re-validate on other macOS versions.

## Privacy and networking

EdgeControl has no networking code, telemetry, analytics, account system, cloud service, or backend. It does not intentionally persist touch traces. Debug builds can print raw/normalized contact diagnostics because `EDGE_DEBUG_LOGGING` is defined for both Swift and C in the Debug configuration. Release compilation excludes those diagnostic paths.

## Private APIs and distribution

EdgeControl uses undocumented/private macOS interfaces and is not intended for Mac App Store distribution. The intended channel is a signed and notarized GitHub Release DMG. Private frameworks are opened with `dlopen`/`dlsym`; missing symbols are treated as feature unavailability rather than fatal errors.

EdgeControl is not affiliated with Apple Inc.

## Clean-room notice

This implementation was written independently for this repository. No Verge, Slidr, EdgeBar, Sleight, MonitorControl, or GPL source code was copied. Product names are mentioned only as ecosystem context. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).
