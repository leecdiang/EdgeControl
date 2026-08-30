# EdgeControl 1.7.3 Validation

## Environment

| Item | Result |
|---|---|
| Mac | MacBook Air, Apple Silicon (arm64) |
| macOS | 26.5 |
| Xcode | 26.6 |
| Version/build | 1.7.3 (8) |
| Commit | Release commit recorded by tag `v1.7.3` |
| Duplicate-launch root cause | Original incident not reproduced; `flock` gate now prevents recurrence |

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
| DMG creation | PASS | `EdgeControl-1.7.3-macOS.dmg`, 4,319,100 bytes |
| DMG filesystem verification | PASS | `hdiutil verify` reports a valid checksum |
| ZIP creation | PASS | `EdgeControl-1.7.3-macOS.zip`, 4,422,022 bytes; archive test reports no errors |
| Sparkle appcast | PASS | Version 8 / short version 1.7.3 / macOS 13.0 / EdDSA enclosure and feed signatures; v1.7.2 URL preserved |
| Local asset hashes | PASS | DMG `52f70ba2...d6abcb`; ZIP `45055b6e...507b8`; appcast `6f678dbe...d8ab1` |
| Published asset hash check | POST-PUBLISH | Compare downloaded GitHub Release assets with the local hashes above |

## UI

| Check | Status |
|---|---|
| HUD continuous gesture lifecycle counters | PASS |
| HUD light/dark hardware visual check | NOT TESTED |
| HUD custom palettes and preview | PASS by shared palette unit coverage |
| Settings native popover glass and neutral scrim | NOT TESTED visually |
| Menu tint in light/dark appearance | NOT TESTED visually |
| Reduce Transparency | NOT TESTED |

## Single instance

| Check | Status | Evidence |
|---|---|---|
| First/competing acquire and release | PASS | XCTest |
| Lock file exists without ownership | PASS | XCTest |
| Filesystem error distinguished from duplicate | PASS | XCTest |
| Rapid repeated launch | PASS | Ten rapid launches left one primary main process |
| Two app copies with same bundle ID | PASS | Temporary copy exited; primary remained running |
| Hosted XCTest while primary is running | PASS | 76/76; test host bypassed the production lock without starting hardware services |
| Launch at Login race | NOT TESTED | Requires logout/login workflow |
| Sparkle relaunch | NOT TESTED | Architecture remains unchanged beyond early gate |
| Sleep/wake | NOT TESTED | Requires hardware lifecycle check |

## Audio session

| Check | Status |
|---|---|
| Session writes pinned device | PASS with fake backend |
| Default switch during gesture | PASS with fake backend |
| Pinned device disappears | PASS with fake backend |
| New session uses new default | PASS with fake backend |
| AirPods or other physical device matrix | NOT TESTED |

## Regression boundary

Gesture entry semantics, multi-touch latch, haptic engine, built-in brightness, DDC routing, private API bridge, login item, and Sparkle main architecture were not intentionally changed. External DDC, external trackpad, Intel, and other macOS versions remain NOT TESTED.
