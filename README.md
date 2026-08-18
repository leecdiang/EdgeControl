# EdgeControl

> Two edges. Two controls. Nothing else.

[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文**](README_zh.md)

<img src="assets/icon-512.png" alt="EdgeControl icon" width="128" height="128" align="left">

EdgeControl is an open-source, offline macOS menu-bar utility that maps a deliberate physical-edge ingress on a built-in or selected external Apple trackpad to continuous volume or brightness control.

<br clear="left" />

## Usage

**The gesture starts from the machine's body, not on the trackpad.**

1. Slide a finger **from the laptop body onto the trackpad's left or right edge** (the finger enters the trackpad from outside).
2. Immediately after entering, slide **up or down** along the edge.
3. The left edge and right edge are independently assignable: Off / Volume / Brightness.
4. A finger that first touches the trackpad **interior** never triggers — even if it later slides to an edge.

This is not a plain "touch the edge, then move" gesture: the contact must be **born at the extreme edge** (the entry strip) and establish clear vertical intent within a short deadline. Interior-born contacts are permanently rejected for the whole contact lifetime, and any multi-touch frame rejects the entire current lifecycle until every finger lifts.

## Status

Version 1.5.1 preserves the native menu and delivers the zero-cross, Strong-pulse lifecycle, and multi-display DDC reliability fixes. Version 1.6.0 builds on it with a custom frosted menu, grouped Settings, and three HUD color styles. Version 1.6.1 fixes the experimental DDC reply field offset, adds a complete ad-hoc bundle signature, and updates the docs. See [BUILD_REPORT.md](BUILD_REPORT.md) for the current evidence boundary.

The gesture recognizer, typing protection, value mapping, brightness routing, trackpad-selection policy, detent, haptic, and settings layers are covered by 61 unit-test methods. Code that depends on undocumented macOS ABIs is dynamically loaded (`dlopen`/`dlsym`), fails closed, and treats missing symbols as feature unavailability rather than fatal errors.

## Features

- Physical left-edge and right-edge ingress recognition
- Independent edge assignment: Off, Volume, or Brightness
- Master, volume, brightness, haptic, HUD, adjustment-speed, false-touch-protection, launch-at-login, and external-DDC settings
- Independent three-level adjustment speed: Precise (`0.50×`), Standard (`0.70×`), or Fast (`0.95×`)
- Independent false-touch protection: Strong (`600ms`, narrow edge birth), Standard (`350ms`), or Light (`200ms`, wider edge birth)
- Continuous relative mapping anchored to the volume/brightness captured at gesture activation, so entering at a high or low position never causes an immediate value jump
- CoreAudio volume control with default-output re-resolution and unsupported-device handling
- Built-in display brightness through runtime-loaded DisplayServices
- Optional, isolated DDC/CI VCP `0x10` external-display backend (experimental, off by default)
- Per-gesture brightness-backend pinning: External DDC is considered only when explicitly enabled and available; transient built-in enumeration failures are retried without false DDC errors; multi-display writes reuse the connection that answered the initial read
- Three-level haptic strength: Light uses sparser subtle ticks, Standard preserves the original 2% feel, and Strong uses a firmer public AppKit pattern with its pending second pulse cancelled at gesture end/reset
- Optional lower-half start filter: contacts born above the trackpad midline are rejected, while accepted gestures continue to adjust relative to the current value
- Trackpad source selection: Automatic / Built-in trackpad / External Magic Trackpad, with persistent preference, visible active-device status, and manual rescan
- Pointer freeze only after the gesture reaches `Active`; the system restores the cursor if the app dies
- Compact 144×40 single-row HUD with a capsule-clipped system blur, denser frosted veil, subtle highlight border, and opaque accessibility fallback
- System / Classic / Aurora HUD palettes that color the progress fill while preserving neutral, appearance-aware glass and text
- Custom lightweight menu-bar popover with live trackpad status, edge-action cards, and Haptic/HUD quick controls
- Grouped four-tab Settings interface with stable sizing and clear Controls, Feedback, Devices, and About sections
- `LSUIElement` menu-bar app with no Dock icon
- Synthetic gesture tests; no physical trackpad required for recognizer tests
- No account, network, analytics, telemetry, or backend

## Recent typing protection

Version 1.4.0 queries Quartz only for the elapsed time since the last key-down event; it does not install a key-event tap, inspect key values, or store keyboard activity. Recent typing blocks only idle or pre-activation edge contacts. A blocked contact stays rejected until every finger lifts, while an already active volume or brightness gesture continues normally.

Adjustment speed and false-touch protection are independent. Speed changes only the post-activation value gain. Protection selects the typing window and physical edge-birth range: Strong uses 600ms and 0.6%/1.2% left/right strips, Standard uses 350ms and 0.8%/1.5%, and Light uses 200ms and 1.0%/1.9%. The asymmetric ranges preserve the measured left/right hardware behavior.

The 450ms intent deadline, 3% candidate corridor, 8% Active corridor, 0.80 directionality, vertical-intent threshold, interior-birth rejection, and multi-touch latch never weaken with the selected profile. Existing continuous-sensitivity preferences migrate to the nearest three-level adjustment-speed preset.

## Start in lower half only

With "Start in lower half only" enabled (Settings > Devices), only contacts born at or below the normalized trackpad midline can become gestures. Contacts born above it are rejected for their entire lifetime, which helps when the upper half tends to catch a resting palm or stray touch. Once accepted, adjustment is still relative to the volume or brightness captured at activation; the finger's entry height is never written directly as a value. At the default gain, 50% of normalized vertical travel is enough to span the full adjustment range.

## External Magic Trackpad (experimental)

Since version 1.3.0, EdgeControl can explicitly select a built-in or external trackpad in Settings > Devices. Automatic mode preserves the 1.2.x `MTDeviceCreateDefault` path. Explicit selection dynamically resolves `MTDeviceCreateList`, `MTDeviceIsBuiltIn`, and `MTDeviceGetSensorSurfaceDimensions`; external candidates must be non-built-in and report a landscape touch surface. This is designed to reject portrait-oriented devices such as Magic Mouse and must be confirmed on real hardware. If the required private symbols or a matching device are unavailable, the app fails closed with a visible error.

Connect or disconnect a trackpad, then use "Rescan Trackpads" (or restart the app). Sleep/wake also reopens the selected source. External selection currently chooses the first matching Magic Trackpad and requires hardware validation before this release is published; automatic hot-plug switching and per-device calibration are not claimed.

## Requirements

- Validated on macOS 26.5 (Apple Silicon, MacBook Air). Other macOS versions and Intel are untested — treat as experimental.
- Xcode 26.x was used for validation. The deployment target is macOS 13; other Xcode versions are not yet part of the tested matrix.
- A built-in Force Touch trackpad, or an Apple Magic Trackpad for the experimental external-input path.

Private interfaces can vary by OS release and hardware. External DDC support is experimental and off by default.

## Build

```bash
./Scripts/build_release.sh test
./Scripts/build_release.sh build
```

The script disables code signing for local compilation when no `DEVELOPMENT_TEAM` is present, then re-signs the built app ad-hoc with a complete bundle signature (`codesign --force --sign -`), so both slices carry an ad-hoc signature and `_CodeSignature/CodeResources` exists. No Developer ID is available on this machine; see [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md) for the production path.

## Package a drag-to-Applications DMG

```bash
./Scripts/package_dmg.sh \
  ./build/DerivedData/Build/Products/Release/EdgeControl.app \
  ./dist/EdgeControl-1.6.0-macOS.dmg
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

The recognizer transitions through `idle → entryCandidate → entryConfirmed → active`. Interior birth, recent typing, wrong initial direction, timeout, identity changes, corridor exit, and multi-touch produce terminal rejection for the current lifecycle. Active zero-cross protection remains anchored to the direction that caused activation, so a slow reversal cannot hide inside the baseline deadband. Typing rejection and `multiTouchRejected` reset only on an empty frame.

## Permissions

The 1.3.0 baseline required no TCC permissions (no Accessibility, Input Monitoring, Screen Recording, or Full Disk Access). The 1.4.0 implementation only queries elapsed time through public CoreGraphics and never reads key values, but its clean-account no-prompt behavior must be revalidated before release and on every target macOS version.

## Privacy and networking

EdgeControl has no networking code, telemetry, analytics, account system, cloud service, or backend. It does not intentionally persist touch traces. Debug builds can print raw/normalized contact diagnostics because `EDGE_DEBUG_LOGGING` is defined for both Swift and C in the Debug configuration. Release compilation excludes those diagnostic paths.

## Private APIs and distribution

EdgeControl uses undocumented/private macOS interfaces and is not intended for Mac App Store distribution. The intended channel is a signed and notarized GitHub Release DMG. Private frameworks are opened with `dlopen`/`dlsym`; missing symbols are treated as feature unavailability rather than fatal errors.

EdgeControl is not affiliated with Apple Inc.

## Clean-room notice

This implementation was written independently for this repository. No Verge, Slidr, EdgeBar, Sleight, MonitorControl, or GPL source code was copied. Product names are mentioned only as ecosystem context. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).
