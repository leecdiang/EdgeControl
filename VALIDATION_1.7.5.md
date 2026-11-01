# EdgeControl 1.7.5 validation

Version/build: **1.7.5 (10)**. Status: validated candidate; not published or installed.

## Tested source and environment

- Source commit: `2f5de264056f93c0dbb7cd83e9ae345425a792c0`.
- CI: https://github.com/leecdiang/EdgeControl/actions/runs/41280473174
- GitHub macOS runner, Xcode 26.6 / macOS 26.5 SDK; deployment target macOS 13.
- Local host: macOS 27.0.1; local Xcode package resolution was blocked by sandbox access to its SwiftPM manifest diagnostics cache.

## Results

| Check | Result |
|---|---|
| Repository validation | PASS, 86 test methods |
| XCTest | 86/86 PASS, zero failures |
| Release build | PASS |
| Universal 2 | PASS, explicit arm64 and x86_64 build and architecture check |
| Ad-hoc bundle signature | PASS, deep/strict verification |
| DMG | PASS, hdiutil checksum verification |
| ZIP | PASS, archive integrity test |
| CI artifact retention | PASS, artifact 13072972660 |
| Release-script syntax | PASS, bash -n |
| Ed25519 verification helper | Compiled and passed a locally generated signature fixture |

Artifact SHA-256: `97a5427c23f4d5f265927bd42cb4d431a890644b98a80580f7080ba617399d95`. This is the complete Actions artifact ZIP containing the packages and test evidence, not the inner application update ZIP. Inner package hashes are included in `SHA256SUMS`. Artifact retention ends 2026-11-15.

The ten new regressions cover endpoint/Float deduplication, new-session cache isolation, failed-write retry, invalid brightness values, horizontal jitter, invalid touch lifecycle, and empty display enumeration.

## Remaining release steps

The local Sparkle helper cannot access the existing Keychain key (OSStatus -50), and this agent session cannot write `/Applications`. No production release, signing key, or installed app was changed. The installed app remains 1.7.4 (9).

From a normal local terminal, `Scripts/publish_validated_release.sh 41280473174 /path/to/Sparkle/bin/sign_update` downloads this exact successful candidate, validates source/hash/version/signature/architectures, signs the update using the existing Keychain key, verifies against the public key embedded in the application, preserves previous appcast entries, uploads a draft, verifies downloaded assets, publishes v1.7.5, and installs with a recoverable backup. It refuses failed CI, mismatched source, invalid signatures, or an existing tag. No private key is exported or uploaded. This final publishing/install workflow has not been executed end-to-end in the restricted session.

## Evidence boundary

No claim is made that the reported Control Center brightness-repeat root cause has been established or fixed. Physical sleep/wake, real brightness gestures, external DDC/trackpad, Intel runtime, Sparkle update/relaunch, and clean-machine Gatekeeper were not tested. DDC remains experimental.

An intermediate run (41280257876) passed all 86 tests and compiled the app, then failed on a lipo command argument incompatibility in the newly added architecture check. The final successful run above uses checked `lipo -archs` output.
