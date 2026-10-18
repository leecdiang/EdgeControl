# BUILD_REPORT - EdgeControl 1.7.4

Date: 2026-10-18
Status: **PUBLISHED - 76/76 XCTest pass; repository validation, Universal 2 Release build, deep ad-hoc signature verification, and published asset hash verification pass**

EdgeControl 1.7.4 is a reliability update based on 1.7.3. It fixes login-item approval handling, stale login-item state, HUD placement after display changes, and forced automatic update checks. It does not change gesture entry parameters, private API bridge contracts, haptic semantics, built-in brightness routing, or the experimental DDC policy.

## Evidence summary

| Item | 1.7.4 result |
|---|---|
| Version/build | `1.7.4 (9)` |
| Tests | 76/76 XCTest methods pass on the local Apple Silicon validation Mac |
| Repository guard | PASS |
| Release build | PASS; Universal 2 (`arm64`, `x86_64`) |
| Bundle signature | PASS; full ad-hoc bundle signature, `codesign --verify --deep --strict` |

## Release assets

| Asset | Size | SHA-256 |
|---|---:|---|
| `EdgeControl-1.7.4-macOS.dmg` | 4,322,423 bytes | `7236cc9efdf0ad4c23e291c19d3ae0bd95014db8e8403ac11ead2720cc32015a` |
| `EdgeControl-1.7.4-macOS.zip` | 4,355,678 bytes | `d21829151dc8aa413984f9d0134c91b7ef60ea4f61444106d738ce0ed0e7c779` |
| `appcast.xml` | 2,963 bytes | `7a4ad9eb447331de313e6ad7cf89929fa23fd8eba67564b75742cf1b4457342e` |

## Changes

| Area | Change | Evidence |
|---|---|---|
| Login item | `.requiresApproval` is treated as registered; the switch no longer snaps back and `unregister()` works from that state | SDK status semantics and code review |
| Login item state | Status is re-read on `didBecomeActiveNotification`; Settings offers a direct Login Items action | Code review |
| HUD placement | The lifecycle tracks `visibleFrame` and repositions when it changes on the same display | Lifecycle unit coverage plus code review |
| Updates | The updater no longer forces `automaticallyChecksForUpdates` on each launch | Code review |
| Version metadata | Marketing version `1.7.4`, build `9` | Repository version guard |

## Validation environment

| Item | Value |
|---|---|
| Hardware | MacBook Air, Apple Silicon (arm64) |
| macOS | 27.0.1 (26A434) |
| Xcode | 27.1 (27A9275) |
| Deployment target | macOS 13+ |
| Signing | ad-hoc; no Developer ID certificate or notarization |

## Evidence boundary

- Launch at Login approval flow, HUD behavior across real resolution changes, Sparkle relaunch, and sleep/wake still require workflow or hardware validation.
- External DDC remains experimental and off by default; external-display hardware behavior is not claimed.
- External trackpad, Intel runtime, other macOS versions, and clean-machine Gatekeeper behavior remain unverified.
- Private MultitouchSupport, DisplayServices, and DDC interfaces remain undocumented dependencies and must fail closed when unavailable.
