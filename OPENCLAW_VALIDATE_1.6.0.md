# OpenClaw validation — EdgeControl 1.6.0

1. Run `./Scripts/validate_repository.sh`.
2. Run `xcodebuild -project EdgeControl.xcodeproj -scheme EdgeControl -configuration Debug test`; require **61/61**.
3. Build Release for `arm64 x86_64`; confirm `lipo -archs` reports both and app version/build are **1.6.0 (3)**.
4. Upgrade from 1.5.1 twice: with Colorful HUD off, require System; with it on, require Classic. Change to Aurora, relaunch, and confirm persistence.
5. Inspect the custom menu in light/dark appearance and at 100%/larger text: status, master switch, both edge cards, Haptic/HUD/Login quick toggles, Settings, Quit, and warning text must fit without clipping. Confirm every control changes the same setting as before.
6. Inspect all four Settings tabs at the 520×430 minimum and after resizing. Confirm cards, captions, segmented controls, palette preview, warning text, touch status, rescan, DDC, launch-at-login, and About remain readable.
7. Compare System/Classic/Aurora HUDs over light, dark, colorful, and full-screen content. Require neutral glass/text, clearly distinct progress colors, visible light-mode brightness bars, Reduce Transparency fallback, and Reduce Motion fade-only presentation.
8. Re-run the 1.5.1 gates: gradual zero-cross cancellation, same-side fine adjustment, no delayed Strong pulse after end/wake, built-in-only/no-DDC behavior, and responsive-monitor DDC routing when hardware is available.
9. Re-run volume, brightness, typing protection, speed/protection, lower-half, trackpad rescan, sleep/wake, clean-account TCC, and installed-app smoke tests.
10. Package/sign as before, run `hdiutil verify`, calculate the DMG SHA-256, replace `9f5c50ae127da75aea10e12a4d6aeaf2b23fab0539047930315d5e950669f62f` in `RELEASE_NOTES_1.6.0.md`, then publish only if every required check passes.
