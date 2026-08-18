# OpenClaw validation — EdgeControl 1.5.1

1. Run `./Scripts/validate_repository.sh`.
2. Run `xcodebuild -project EdgeControl.xcodeproj -scheme EdgeControl -configuration Debug test`; require **60/60**.
3. Build Release for `arm64 x86_64`; confirm `lipo -archs` reports both and app version/build are **1.5.1 (2)**.
4. Gesture regression: activate upward, drift just below the activation baseline, then continue downward; it must cancel once the opposite displacement exceeds 0.5%. Confirm ordinary same-side fine adjustment still works.
5. Strong haptics: end a gesture immediately after a tick, then repeat across sleep/wake; no delayed second pulse may occur after end/reset. Compare Light/Standard/Strong on built-in and external trackpads if available.
6. DDC: with two external monitors where the first does not answer VCP `0x10` and the second does, confirm read and write both affect the second. Re-run built-in-only/no-DDC and hot-plug smoke tests.
7. Confirm Haptic feedback and Haptic strength are together in Controls; verify the strength picker disables correctly. Re-run compact HUD, typing protection, speed/protection, lower-half, rescan, and wake smoke tests.
8. Package/sign as before, run `hdiutil verify`, calculate the DMG SHA-256, replace `3551d542e43c2a8f0ce7022224d653841f414039b94a5ec0b8a6a43afdbee3ac` in `RELEASE_NOTES_1.5.1.md`, then publish only if every required check passes.
