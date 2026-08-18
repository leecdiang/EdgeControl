# BUILD_REPORT — EdgeControl 1.6.1 published status

Date: 2026-08-18
Status: **PUBLISHED — 67/67 XCTest pass; Release build, Universal 2, full ad-hoc bundle signature, and DMG verified on macOS**

EdgeControl 1.6.1 is a reliability patch on the published 1.6.0 source. It fixes the experimental DDC/CI brightness reply field offset (with result-code and checksum validation), adds a complete ad-hoc bundle signature to the Release app, drops stale touch frames after trackpad restart via a generation token, and syncs the documentation. The source contains 67 XCTest methods.

## Evidence boundary

| Item | Established baseline | 1.6.1 result |
|---|---|---|
| Source suite | 1.6.0: 61 methods passed | 67/67 passed on macOS (Xcode 26.6) |
| Release build | 1.6.0 passed | PASS (Universal 2: `x86_64 arm64`) |
| Bundle signature | 1.6.0 was linker-signed on arm64 only | Full ad-hoc re-sign: both slices signed, `_CodeSignature/CodeResources` present, `codesign --verify --strict` valid |
| DDC reply parsing | 1.6.0 read fields one byte late | Correct VESA offsets + result code + checksum; 6 byte-fixture regressions |
| Menu/Settings | 1.6.0 visual validation on validation Mac | Unchanged from 1.6.0 |
| HUD | 1.6.0 three palettes validated | Unchanged from 1.6.0 |
| External Magic Trackpad/DDC hardware | Not fully physically validated | Still required when hardware is available |
| Signing/notarization | Ad-hoc only | Developer ID/notarization unavailable |

## 1.6.1 changes

| Change | Implementation | Verification |
|---|---|---|
| DDC/CI VCP 0x10 parsing | maximum at +4/+5, current at +6/+7 relative to the 0x02 command byte; result-code and checksum checks; optional leading byte still accepted | 6 new byte-fixture tests (`DDCParsingTests`) |
| Complete ad-hoc signature | `codesign --force --sign -` after Release build when no `DEVELOPMENT_TEAM` | `codesign --verify --strict` passes; per-slice CDHash present |
| Stale frame guard | `frameGeneration` token invalidated on stop/rescan/wake; frames tagged at enqueue | Source review; runtime regression on macOS |
| Docs sync | Settings > Devices, 304 pt menu, released wording | Repository guard |
| Version metadata | Marketing 1.6.1, build 4 | Repository invariant guard |

## Published 1.6.1 evidence

| Item | Evidence |
|---|---|
| Tests | 67/67 on Apple Silicon MacBook Air, macOS 26.5.2, Xcode 26.6 |
| Release architectures | `x86_64 arm64` |
| Signature | ad-hoc, both slices, `_CodeSignature/CodeResources` present |
| DMG | `EdgeControl-1.6.1-macOS.dmg`; `hdiutil verify` valid |
| SHA-256 | `b087b4768c1cc6f5c3f67fdf66af0dde6d90095bca4bf2cd23756c6a3d55df07` |

## Known limitations (unchanged)

- External DDC remains experimental and off by default; it is not a formally supported feature.
- A volume gesture does not pin its output device: if the default audio device changes mid-gesture, values are applied relative to the old device's initial volume.
- External trackpad selection, Intel runtime, other macOS versions, multi-device ordering, and clean-machine Gatekeeper remain hardware/environment dependent.
- Shell syntax checks for repository scripts
- XCTest method count and targeted invariant guards
- Whitespace/diff review
- Network/telemetry static guard
- Source archive integrity check

This environment cannot run AppKit/Xcode tests. A source-side pass must not be represented as a compiled macOS pass.

## Required macOS release gate

Follow `OPENCLAW_VALIDATE_1.6.1.md`. Publication is blocked until:

1. 67/67 Xcode tests and clean Debug/Release builds pass.
2. The Universal 2 binary reports both architectures and version/build 1.6.1 (4).
3. Legacy HUD migration, all three palettes, custom menu, and every Settings page pass light/dark/accessibility checks.
4. The complete 1.5.1 zero-cross, Strong haptic, and brightness/DDC gates remain green.
5. DMG verify, installation, launch, and SHA-256 insertion into `RELEASE_NOTES_1.6.1.md` succeed.

## Known limitations

- Raw multitouch, DisplayServices, and legacy DDC depend on undocumented/private macOS interfaces and must fail closed when unavailable.
- External DDC is experimental and off by default. Legacy I2C transport may not cover every Apple Silicon monitor/dock path.
- External trackpad selection, Intel runtime, other macOS versions, multi-device ordering, Developer ID signing, notarization, and clean-machine Gatekeeper remain environment dependent.
- AppKit exposes feedback patterns rather than numeric haptic amplitude; real-device feel still requires physical validation.
