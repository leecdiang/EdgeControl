# BUILD_REPORT — EdgeControl 1.6.0 source status

Date: 2026-08-18
Status: **SOURCE PREPARED — static repository validation passes; macOS Xcode and visual/physical regression remain required**

EdgeControl 1.6.0 builds on the 1.5.1 reliability source. It adds a custom window-style menu, grouped Settings, and three HUD palettes without adding assets, packages, networking, or another runtime service. The source contains 61 XCTest methods.

## Evidence boundary

| Item | Established baseline | 1.6.0 source |
|---|---|---|
| Gesture/action architecture | Covered by prior hardware and source validation | Unchanged except inherited 1.5.1 fixes |
| Source suite | 1.5.1: 60 methods prepared | 61 methods present; macOS run required |
| Menu/Settings | 1.5.1 native menu and flat Form | New UI; visual/interaction validation required |
| HUD | 144×40 frost and accessibility behavior previously validated | Three palettes and neutral-glass tuning require visual validation |
| Release build | Earlier releases passed | Required for 1.6.0 |
| Universal 2 | Earlier binary reported `x86_64 arm64` | Required; Intel runtime still unverified |
| External Magic Trackpad/DDC | Not fully physically validated | Still required when hardware is available |
| Signing/notarization | Ad-hoc workflow | Developer ID/notarization unavailable |

## 1.6.0 changes

| Change | Implementation | Risk/control |
|---|---|---|
| Custom menu | `.menuBarExtraStyle(.window)`, 292-point material surface, live status, two action cards, Haptic/HUD/Login quick toggles | Check light/dark, text size, focus and dismissal on macOS |
| Grouped Settings | Four tabs and system-rendered cards in one reusable 560×470 window | Check minimum size, resizing and every binding |
| HUD palettes | System, Classic blue/orange, Aurora purple/teal; strong color limited to progress fill | Dynamic system colors; inspect contrast on real content |
| Legacy migration | `colorfulHUD=false/true` maps to System/Classic when `hudColorStyle` is absent | Automated persistence/migration regression |
| Version metadata | Marketing 1.6.0, build 3, Info.plist reads project build setting | Repository invariant guard |

## Reliability carried forward from 1.5.1

- Active zero-cross cancellation compares against the committed activation direction.
- Strong secondary haptic tasks are cancelled on gesture end and wake reset.
- External DDC writes reuse the connection that returned the initial session value.
- Four targeted regressions for those paths remain in the 61-test source.

## Source checks completed here

- `Scripts/validate_repository.sh`
- Shell syntax checks for repository scripts
- XCTest method count and targeted invariant guards
- Whitespace/diff review
- Network/telemetry static guard
- Source archive integrity check

This environment cannot run AppKit/Xcode tests. A source-side pass must not be represented as a compiled macOS pass.

## Required macOS release gate

Follow `OPENCLAW_VALIDATE_1.6.0.md`. Publication is blocked until:

1. 61/61 Xcode tests and clean Debug/Release builds pass.
2. The Universal 2 binary reports both architectures and version/build 1.6.0 (3).
3. Legacy HUD migration, all three palettes, custom menu, and every Settings page pass light/dark/accessibility checks.
4. The complete 1.5.1 zero-cross, Strong haptic, and brightness/DDC gates remain green.
5. DMG verify, installation, launch, and SHA-256 insertion into `RELEASE_NOTES_1.6.0.md` succeed.

## Known limitations

- Raw multitouch, DisplayServices, and legacy DDC depend on undocumented/private macOS interfaces and must fail closed when unavailable.
- External DDC is experimental and off by default. Legacy I2C transport may not cover every Apple Silicon monitor/dock path.
- External trackpad selection, Intel runtime, other macOS versions, multi-device ordering, Developer ID signing, notarization, and clean-machine Gatekeeper remain environment dependent.
- AppKit exposes feedback patterns rather than numeric haptic amplitude; real-device feel still requires physical validation.
