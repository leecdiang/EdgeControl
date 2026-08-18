# OpenClaw validation — EdgeControl 1.6.1

1. Run `./Scripts/validate_repository.sh` (expect 67 XCTest methods).
2. Run `xcodebuild -project EdgeControl.xcodeproj -scheme EdgeControl -configuration Debug test`; require **67/67**.
3. Build Release for `arm64 x86_64`; confirm `lipo -archs` reports both, app version/build are **1.6.1 (4)**, and `codesign --verify --strict` passes with `_CodeSignature/CodeResources` present (full ad-hoc signature on both slices).
4. DDC parsing regression (byte fixtures): standard reply layout, leading destination byte, non-zero result code, corrupt checksum, wrong VCP code, truncated reply — covered by `DDCParsingTests`.
5. Trackpad restart regression: after Rescan Trackpads and sleep/wake, frames queued before the restart must be dropped; no stale frame may enter the new recognizer. Re-run lower-half, speed/protection, typing protection, and wake smoke tests.
6. Re-run the 1.5.1 reliability gates: gradual zero crossing, Strong-pulse cancellation on end/wake, and DDC write routing to the responsive connection.
7. HUD palettes and custom menu (304 pt) visual check in light/dark; Settings four-tab layout (Controls/Feedback/Devices/About) at minimum and resized windows.
8. Package as before, run `hdiutil verify`, calculate the DMG SHA-256, replace the placeholder in `RELEASE_NOTES_1.6.1.md`, then publish only if every required check passes.

## Known limitations to state in the release notes

- External DDC remains experimental and off by default; not a formally supported feature.
- Volume gestures do not pin their output device; a default-audio-device switch mid-gesture can apply values relative to the old device's initial volume.
- External trackpad selection, Intel runtime, other macOS versions, and clean-machine Gatekeeper remain hardware/environment dependent.
