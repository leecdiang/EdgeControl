# OpenClaw validation — EdgeControl 1.5.0

1. Run `./Scripts/validate_repository.sh`.
2. Run `xcodebuild -project EdgeControl.xcodeproj -scheme EdgeControl -configuration Debug test`.
3. Build Release for `arm64 x86_64`; confirm `lipo -archs` reports both.
4. Upgrade over 1.4.0: confirm the haptic toggle is preserved and strength defaults to Standard.
5. Compare Light / Standard / Strong on the built-in trackpad, then an external Magic Trackpad if available. Confirm Standard matches 1.4.0 and no profile produces a continuous buzz.
6. Inspect the 144×40 HUD over light, dark, colorful, and full-screen content. Confirm visible blur, adequate opacity, no rectangular backing, and clean capsule shadow.
7. Enable Reduce Transparency and Reduce Motion; confirm opaque fallback and fade-only presentation.
8. Re-run volume, built-in brightness, no-external-DDC, typing-protection, wake, and trackpad-rescan smoke tests.
9. Package/sign as before, calculate the DMG SHA-256, replace the placeholder in `RELEASE_NOTES_1.5.0.md`, then upload only after all checks pass.
