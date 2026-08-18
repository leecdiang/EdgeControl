# BUILD_REPORT — EdgeControl 1.5.1 source status

Date: 2026-08-18
Status: **SOURCE PREPARED — static repository validation passes; macOS Xcode and physical regression remain required**

EdgeControl 1.5.1 is based on the published `v1.5.0` source (`3c34430214980c7d08fc4b4ec9c24df8cdb0d950`). It is a focused reliability update: committed-direction zero-cross cancellation, cancellable Strong secondary pulses, responsive-connection DDC writes, colocated haptic settings, and build-number wiring. The source contains 60 XCTest methods.

## Evidence boundary

| Item | 1.5.0 published baseline | 1.5.1 source |
|---|---|---|
| Source suite | PASS, 56/56 on macOS | 60 methods present; macOS run required |
| Release build | PASS | Required |
| Universal 2 | PASS (`x86_64 arm64`) | Required; Intel runtime still unverified |
| Built-in haptics/HUD | PASS on validation Mac | Strong end/reset regression required |
| Built-in volume/brightness | PASS | Smoke regression required |
| External Magic Trackpad | Not physically validated | Still required if hardware is available |
| External DDC | Not physically validated | Multi-display routing specifically required |
| Signing/notarization | Ad-hoc build published | Developer ID/notarization not available |

## Published 1.5.0 reference

| Item | Evidence |
|---|---|
| Validation machine | Apple Silicon MacBook Air, macOS 26.5.2, Xcode 26.6 |
| Tests | 56/56 |
| Release architectures | `x86_64 arm64` |
| Haptics | Light/Standard/Strong physically compared; no continuous buzz |
| HUD | 144×40 blur/frost, accessibility fallbacks, no rectangular backing |
| DMG | `EdgeControl-1.5.0-macOS.dmg`; `hdiutil verify` valid |
| SHA-256 | `839368c254462d9826329d8bf8304b014eff255eb83f65b3b0d4d6766873392b` |

## 1.5.1 changes and regression coverage

| Change | Failure prevented | Automated evidence |
|---|---|---|
| Activation direction stored in `ActiveContact` | Gradual reversal slipping through the 0.5% deadband | `testGradualZeroCrossingCannotEscapeThroughDeadband` |
| Strong secondary pulse kept in a cancellable task with a generation token | Delayed haptic after gesture end or wake reset | Two lifecycle cancellation tests |
| Successful DDC read stores its connection index and set reuses it | Read from monitor B, write to enumerated monitor A | `testExternalDDCWritesBackToTheResponsiveConnection` |
| Haptic switch moved next to strength picker | Disabled picker with its cause hidden on another tab | Settings source review; physical UI check required |
| `CFBundleVersion` uses `CURRENT_PROJECT_VERSION` | Bundle build number drifting from project settings | Repository guard; expected 1.5.1 (2) |

## Source checks completed here

- `Scripts/validate_repository.sh`
- Shell syntax checks for repository scripts
- XCTest method count and targeted invariant guards
- Whitespace/diff review
- Network/telemetry static guard

This environment cannot run AppKit/Xcode tests. A source-side pass must not be represented as a compiled macOS pass.

## Required macOS release gate

Follow `OPENCLAW_VALIDATE_1.5.1.md`. Publication is blocked until all of the following succeed:

1. 60/60 Xcode tests and a clean Release build.
2. Universal 2 binary inspection and version/build check for 1.5.1 (2).
3. Physical gradual-zero-cross and same-side fine-adjustment regression.
4. No Strong secondary pulse after gesture end or wake reset.
5. Built-in-only brightness/no-DDC smoke plus real multi-display DDC routing when hardware is available.
6. DMG verify, install/launch smoke, SHA-256 insertion into `RELEASE_NOTES_1.5.1.md`.

## Known limitations

- Raw multitouch, DisplayServices, and legacy DDC depend on undocumented/private macOS interfaces and must fail closed when unavailable.
- External DDC is experimental and off by default. Legacy I2C transport may not cover every Apple Silicon monitor/dock path.
- External trackpad selection, Intel runtime, other macOS versions, multi-device ordering, Developer ID signing, notarization, and clean-machine Gatekeeper remain hardware/environment dependent.
- AppKit offers feedback patterns rather than numeric haptic amplitude; perceived Light/Standard/Strong ordering requires real-device validation.
