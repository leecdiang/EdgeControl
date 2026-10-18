# EdgeControl 1.7.4 Validation

## Environment

| Item | Result |
|---|---|
| Mac | MacBook Air, Apple Silicon (arm64) |
| macOS | 27.0.1 (26A434) |
| Xcode | 27.1 (27A9275) |
| Version/build | 1.7.4 (9) |
| Commit | Release commit recorded by tag `v1.7.4` |

## Build and tests

| Check | Status | Evidence |
|---|---|---|
| Debug XCTest | PASS | 76/76 on local arm64 host |
| Repository validation | PASS | `./Scripts/validate_repository.sh` |
| Release build | PASS | `./Scripts/build_release.sh build` |
| Universal 2 slices | PASS | Release binary contains `x86_64` and `arm64` |
| Ad-hoc signature | PASS | `codesign --verify --deep --strict` |

## Release packages

| Check | Status | Evidence |
|---|---|---|
| DMG creation | PASS | `EdgeControl-1.7.4-macOS.dmg`, 4,322,423 bytes |
| DMG filesystem verification | PASS | `hdiutil verify` reports a valid checksum |
| ZIP creation | PASS | `EdgeControl-1.7.4-macOS.zip`, 4,355,678 bytes; archive test reports no errors |
| Sparkle appcast | PASS | Version 9 / short version 1.7.4 / macOS 13.0 / EdDSA enclosure; v1.7.2 and v1.7.3 entries preserved |
| Local asset hashes | PASS | DMG `7236cc9e…2015a`; ZIP `d2182915…0e7c779`; appcast `7a4ad9eb…457342e` |

## Fixed in this release

| Item | Status | Evidence |
|---|---|---|
| Login item in `.requiresApproval` no longer re-registers | PASS by code review | `LaunchAtLoginController.status`; XCTest suite unchanged |
| Login item state refreshed on app activation | PASS by code review | `SystemEventMonitor` activation observer |
| HUD repositions when the current screen's visible frame changes | PASS by code review | `HUDPresentationLifecycle.currentScreenFrame` |
| Updater no longer forces automatic checks | PASS by code review | `UpdateController` no longer sets the preference |

## Not tested

| Check | Status |
|---|---|
| Launch at Login end-to-end approval flow | NOT TESTED (requires logout/login and System Settings interaction) |
| HUD visual check across resolution changes | NOT TESTED (requires hardware display change) |
| Sparkle relaunch | NOT TESTED |
| Sleep/wake | NOT TESTED |
| External trackpad, Intel runtime, other macOS versions, clean-machine Gatekeeper | NOT TESTED |

## Regression boundary

Gesture entry semantics, multi-touch latch, haptic engine, built-in brightness, DDC routing, private API bridge, and Sparkle main architecture were not intentionally changed.
