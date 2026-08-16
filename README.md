# EdgeControl

> Two edges. Two controls. Nothing else.

EdgeControl is an open-source, offline macOS 13+ menu-bar utility that maps a deliberate physical-edge ingress on a MacBook trackpad to continuous volume or brightness control.

The intended gesture is not “start near an edge.” A contact must first appear in a very narrow edge-entry strip, move inward, and establish vertical intent within a short deadline. A contact first observed in the trackpad interior is permanently rejected until that finger lifts. Any multi-touch frame rejects the entire current lifecycle until every finger lifts.

## Status

This repository is a complete cloud-authored implementation and handoff, not a claim of hardware validation. The pure gesture, mapping, detent, and settings tests are included. Code that depends on undocumented macOS ABIs is dynamically loaded, fails closed, and is explicitly marked `LOCAL_VALIDATION_REQUIRED`.

The repository has **not** been compiled or run on a real Mac in the environment where it was created. Begin with [HANDOFF_TO_OPENCLAW.md](HANDOFF_TO_OPENCLAW.md) and [Docs/LOCAL_VALIDATION_REQUIRED.md](Docs/LOCAL_VALIDATION_REQUIRED.md).

## Features

- Physical left-edge and right-edge ingress recognition
- Independent edge assignment: Off, Volume, or Brightness
- Master, volume, brightness, haptic, HUD, sensitivity, and launch-at-login settings
- Continuous value mapping from the gesture’s activation value
- CoreAudio volume control with default-output re-resolution and unsupported-device handling
- Built-in display brightness through runtime-loaded DisplayServices
- Optional, isolated DDC/CI VCP `0x10` external-display backend
- Activation haptic plus 5% value detents with hysteresis
- Pointer freeze only after the gesture reaches `Active`
- Custom non-activating AppKit/SwiftUI HUD
- `LSUIElement` menu-bar app with no Dock icon
- Synthetic gesture tests; no physical trackpad required for recognizer tests
- No account, network, analytics, telemetry, or backend

## Requirements

- macOS 13 or later
- Xcode 15 or later recommended
- Apple Silicon or Intel Mac
- A built-in Force Touch trackpad for the intended UX

Private interfaces can vary by OS release and hardware. External DDC support is best-effort and is expected to be the least portable part of the app.

## Build

Open `EdgeControl.xcodeproj`, select the `EdgeControl` scheme, and build. From Terminal:

```bash
./Scripts/build_release.sh test
./Scripts/build_release.sh build
```

If no `DEVELOPMENT_TEAM` environment variable is present, the script disables code signing for local compilation. Release signing, Hardened Runtime behavior, notarization, and distribution must be validated locally.

## Package a drag-to-Applications DMG

After producing `EdgeControl.app`:

```bash
./Scripts/package_dmg.sh \
  ./build/DerivedData/Build/Products/Release/EdgeControl.app \
  ./build/EdgeControl.dmg
```

The script uses only macOS-provided tools (`hdiutil`, Finder/AppleScript, `codesign`, and `xcrun`). It stages `EdgeControl.app` on the left and an `Applications` symlink on the right. Set `CODESIGN_IDENTITY` and `NOTARY_PROFILE` only after local signing configuration is ready.

## Gesture model

Default internal engineering values:

| Parameter | Default |
| --- | ---: |
| Entry strip | 1.5% from either physical edge |
| Control corridor | 8% from the active edge |
| Minimum inward travel | 0.8% |
| Minimum vertical movement | 1.5% |
| Entry deadline | 250 ms |

These are intentionally internal constants for V1. They are starting assumptions, not hardware-tuned claims.

The recognizer transitions through `idle → entryCandidate → entryConfirmed → active`. Interior birth, wrong initial direction, timeout, identity changes, corridor exit, and multi-touch produce terminal rejection for the current lifecycle. `multiTouchRejected` remains latched as fingers go from two to one and resets only on an empty frame.

## Architecture

```text
MultitouchSupport (runtime-loaded C bridge)
    → TrackpadManager (normalized TouchFrame)
        → GestureEngine (pure state machine)
            → EdgeControlAppModel (action/session coordinator)
                → CoreAudio / DisplayBrightnessController
                → HapticEngine / CursorController / HUDController
```

The input callback never changes a system value. It copies raw contacts, serializes them, produces normalized value types, and hands those frames to the isolated recognizer. See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md).

## Permissions

The design target is:

- No Accessibility permission
- No Input Monitoring permission
- No Screen Recording permission
- No Full Disk Access

This is a **ZERO_PERMISSION_GOAL**, not a verified claim. Permission prompts and behavior must be tested on clean local user accounts for each supported macOS version. See the validation checklist.

## Privacy and networking

EdgeControl has no networking code, telemetry, analytics, account system, cloud service, or backend. It does not intentionally persist touch traces. Debug builds print raw/normalized contact diagnostics because `EDGE_DEBUG_LOGGING` is enabled in the Debug Xcode configuration; Release builds do not define that flag.

## Private APIs and distribution

EdgeControl uses undocumented/private macOS interfaces and is not intended for Mac App Store distribution. The intended channel is a signed and notarized GitHub Release DMG. Private frameworks are opened with `dlopen`/`dlsym`; missing symbols are treated as feature unavailability rather than fatal errors.

EdgeControl is not affiliated with Apple Inc.

## Clean-room notice

This implementation was written independently for this repository. No Verge, Slidr, EdgeBar, Sleight, MonitorControl, or GPL source code was copied. Product names are mentioned only as ecosystem context. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).

