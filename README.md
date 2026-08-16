# EdgeControl

> Two edges. Two controls. Nothing else.

EdgeControl is an open-source, offline macOS menu-bar utility that maps a deliberate physical-edge ingress on a MacBook trackpad to continuous volume or brightness control.

The intended gesture is not “start near an edge.” A contact must first appear in a very narrow edge-entry strip and establish vertical intent within a short deadline. A contact first observed in the trackpad interior is permanently rejected until that finger lifts. Any multi-touch frame rejects the entire current lifecycle until every finger lifts.

## Status

Hardware-validated on macOS 26.5 (Apple Silicon MacBook Air) on 2026-08-16/17. See [BUILD_REPORT.md](BUILD_REPORT.md) for the per-item PASS/FAIL matrix and [Docs/GestureTuning.md](Docs/GestureTuning.md) for the tuned recognizer values.

The gesture recognizer, value mapping, detent, and settings layers are covered by 23 unit tests. Code that depends on undocumented macOS ABIs is dynamically loaded (`dlopen`/`dlsym`), fails closed, and treats missing symbols as feature unavailability rather than fatal errors.

## Features

- Physical left-edge and right-edge ingress recognition
- Independent edge assignment: Off, Volume, or Brightness
- Master, volume, brightness, haptic, HUD, sensitivity, launch-at-login, and external-DDC settings
- Continuous value mapping from the gesture’s activation value (full trackpad height maps to the full 0–100% range)
- CoreAudio volume control with default-output re-resolution and unsupported-device handling
- Built-in display brightness through runtime-loaded DisplayServices
- Optional, isolated DDC/CI VCP `0x10` external-display backend (experimental, off by default)
- Activation haptic plus 5% value detents with hysteresis and rate limiting
- Pointer freeze only after the gesture reaches `Active`; the system restores the cursor if the app dies
- Custom non-activating AppKit/SwiftUI HUD
- `LSUIElement` menu-bar app with no Dock icon
- Synthetic gesture tests; no physical trackpad required for recognizer tests
- No account, network, analytics, telemetry, or backend

## Requirements

- Validated on macOS 26.5 (Apple Silicon). Other macOS versions and Intel are untested — treat as experimental.
- Xcode 26.x used for validation; the project also builds with Xcode 15+ (deployment target macOS 13).
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
  ./dist/EdgeControl-1.0.0-macOS.dmg
```

The script uses only macOS-provided tools (`hdiutil`, Finder/AppleScript, `codesign`, `xcrun`). It stages `EdgeControl.app` on the left and an `Applications` symlink on the right, then converts to a compressed read-only DMG. Verified layout: App at (145,175), Applications at (410,175), icon size 104.

## Gesture model

Tuned values (see [Docs/GestureTuning.md](Docs/GestureTuning.md) for evidence):

| Parameter | Value | Notes |
| --- | ---: | --- |
| Entry strip | 1.5% from either physical edge | Birth must land here; interior births are permanently rejected |
| Control corridor | 8% from the active edge | Leaving it cancels the gesture |
| Minimum inward travel | 0.0 | Edge-pinned contacts report x pinned at the edge; inward character is enforced by birth-in-strip + outward-motion rejection |
| Minimum vertical movement | 1.5% | Must appear within the entry deadline |
| Entry deadline | 800 ms | Tuned for the observed dwell-then-push pattern; pauses beyond it never activate |

The recognizer transitions through `idle → entryCandidate → entryConfirmed → active`. Interior birth, wrong initial direction, timeout, identity changes, corridor exit, and multi-touch produce terminal rejection for the current lifecycle. `multiTouchRejected` remains latched as fingers go from two to one and resets only on an empty frame.

## Permissions

Validated on this machine: **no TCC permissions are required** (no Accessibility, Input Monitoring, Screen Recording, or Full Disk Access). This was verified while the app ran as an `LSUIElement` menu-bar app. Re-validate on other macOS versions.

## Privacy and networking

EdgeControl has no networking code, telemetry, analytics, account system, cloud service, or backend. It does not intentionally persist touch traces. Debug builds print raw/normalized contact diagnostics because `EDGE_DEBUG_LOGGING` is defined in the Debug Xcode configuration; Release builds do not define that flag (verified via binary inspection).

## Private APIs and distribution

EdgeControl uses undocumented/private macOS interfaces and is not intended for Mac App Store distribution. The intended channel is a signed and notarized GitHub Release DMG. Private frameworks are opened with `dlopen`/`dlsym`; missing symbols are treated as feature unavailability rather than fatal errors.

EdgeControl is not affiliated with Apple Inc.

## Clean-room notice

This implementation was written independently for this repository. No Verge, Slidr, EdgeBar, Sleight, MonitorControl, or GPL source code was copied. Product names are mentioned only as ecosystem context. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).
