# OpenClaw validation — EdgeControl 1.7.1

1. Run `./Scripts/validate_repository.sh` (expect 68 XCTest methods).
2. Run `xcodebuild -project EdgeControl.xcodeproj -scheme EdgeControl -configuration Debug test`; require **68/68**.
3. Build Release for `arm64 x86_64`; confirm `lipo -archs` reports both, app version/build are **1.7.1 (6)**, and `codesign --verify --strict` passes with `_CodeSignature/CodeResources` present (full ad-hoc signature on both slices).
4. Frosted Settings visual check: the window must show the frosted `popover` material as its real background (not transparent), identical in character to the menu-bar popover, in light and dark appearance; traffic lights do not collide with the tab bar; cards render translucent over the glass. Verify with Reduce Transparency on (opaque fallback) and off.
5. Morandi palette: pick Morandi under Settings > Feedback > HUD and confirm the volume accent is the soft baby blue (`#A3C1DE`), brightness stays the mist blue; preview matches the HUD; style persists across relaunch.
6. Entry-strip smoke test: a deliberate edge ingress born within the outer ~1.2% (left) / ~2.2% (right) of the trackpad activates on the Standard preset; interior births remain rejected; re-run the directionality / zero-cross / typing-protection regression gates.
7. Re-run the 1.6.1/1.7.0 reliability gates: DDC VCP10 byte fixtures, stale-frame generation guard, committed-direction zero-cross cancel, Strong-pulse cancellation on end/wake, DDC write routing to the responsive connection, and the lower-half admission smoke test.
8. Homebrew: `brew tap leecdiang/edgecontrol` then `brew install --cask --no-quarantine leecdiang/edgecontrol/edgecontrol` installs the app; the bundle version inside /Applications is 1.7.1 (6) and the app launches.
9. Package as before, run `hdiutil verify`, calculate the DMG SHA-256, replace the placeholder in `RELEASE_NOTES_1.7.1.md`, then publish only if every required check passes.

## Known limitations to state in the release notes

- External DDC remains experimental and off by default; not a formally supported feature.
- Volume gestures do not pin their output device; a default-audio-device switch mid-gesture can apply values relative to the old device's initial volume.
- External trackpad selection, Intel runtime, other macOS versions, and clean-machine Gatekeeper remain hardware/environment dependent.
