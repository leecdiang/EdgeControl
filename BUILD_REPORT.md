# BUILD_REPORT - EdgeControl 1.7.3

Date: 2026-08-30
Status: **RELEASE-READY - 76/76 XCTest pass; repository validation, Universal 2 Release build, and deep ad-hoc signature verification pass**

EdgeControl 1.7.3 is a focused stability and reliability update based on 1.7.2. It does not change gesture entry parameters, private API bridge contracts, haptic semantics, built-in brightness routing, or the experimental DDC policy.

## Evidence summary

| Item | 1.7.3 result |
|---|---|
| Version/build | `1.7.3 (8)` |
| Tests | 76/76 XCTest methods pass on the local Apple Silicon validation Mac |
| Repository guard | PASS |
| Release build | PASS; Universal 2 (`arm64`, `x86_64`) |
| Bundle signature | PASS; full ad-hoc bundle signature, `codesign --verify --deep --strict` |
| Single instance | Ten rapid launches and a second app copy with the same Bundle ID leave one primary process |
| Volume session | Device pinning, default-device switch, disappearance, and next-session behavior pass with a fake backend |
| Packages | DMG, ZIP, and signed Sparkle appcast checks recorded in `VALIDATION_1.7.3.md` |

## Release assets

| Asset | Size | SHA-256 |
|---|---:|---|
| `EdgeControl-1.7.3-macOS.dmg` | 4,319,100 bytes | `52f70ba2f019313f3116270a1b5d8ef96d3b6344ad7d88a381a670fdf0d6abcb` |
| `EdgeControl-1.7.3-macOS.zip` | 4,422,022 bytes | `45055b6eb3e7a69381c563642da5cde570e8a202179a6946a0ea5674bbd507b8` |
| `appcast.xml` | 2,168 bytes | `6f678dbe2b88dbd363e3faeab0961ae20f3e2c0a56dfc2b4094b1bd0576d8ab1` |

## Changes

| Area | Change | Evidence |
|---|---|---|
| HUD lifecycle | Continuous updates reuse one presentation and avoid repeated resize, position, and order-front work | Lifecycle regression test and local runtime counters |
| UI theme | Shared palette definitions; HUD neutral veil `0.64`; Settings neutral scrim `0.24` | Unit coverage for palette mapping; visual constants guarded by repository validation |
| Single instance | User-level advisory `flock`; duplicate instances exit without taking ownership of services | Coordinator tests, rapid-launch test, and two-copy runtime test |
| Volume gesture | Output device is pinned for the lifetime of the gesture; disappearance fails the session closed | Fake-backend session tests |
| Version metadata | Marketing version `1.7.3`, build `8` | Repository version guard |

## Validation environment

| Item | Value |
|---|---|
| Hardware | MacBook Air, Apple Silicon (arm64) |
| macOS | 26.5 |
| Xcode | 26.6 |
| Deployment target | macOS 13+ |
| Signing | ad-hoc; no Developer ID certificate or notarization |

## Evidence boundary

- HUD and Settings light/dark appearance, Reduce Transparency, Launch at Login races, Sparkle relaunch, and sleep/wake still require workflow validation.
- Physical audio-device switching was not tested; the session contract is covered with a fake backend.
- External DDC remains experimental and off by default; external-display hardware behavior is not claimed.
- External trackpad, Intel runtime, other macOS versions, and clean-machine Gatekeeper behavior remain unverified.
- Private MultitouchSupport, DisplayServices, and DDC interfaces remain undocumented dependencies and must fail closed when unavailable.
