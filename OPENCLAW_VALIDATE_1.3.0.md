# OpenClaw validation task — EdgeControl 1.3.0

Do not publish or tag this source until every required item below passes on macOS with a real external Apple Magic Trackpad. Work only in this extracted tree and preserve the 1.2.1 gesture/mapping behavior.

## 1. Static ABI inspection

Confirm these symbols exist on the validation Mac before exercising explicit selection:

```bash
FRAMEWORK=/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport
nm -gU "$FRAMEWORK" | grep -E 'MTDevice(CreateDefault|CreateList|IsBuiltIn|GetSensorSurfaceDimensions|Start|Stop)|MT(Register|Unregister)ContactFrameCallback'
```

If enumeration/classification symbols are missing, verify Automatic still works, record explicit selection as unsupported, and do not invent replacement prototypes.

## 2. Build and automated tests

```bash
./Scripts/validate_repository.sh
./Scripts/build_release.sh test
./Scripts/build_release.sh build
```

Expect at least 35 passing tests. Stop on any compile warning caused by C/Swift ABI types, any test failure, or any repository-guard failure.

## 3. Debug device probe

Run a Debug build with `EDGE_DEBUG_LOGGING`. For each selection, capture the single line:

```text
[ECProbe] selected trackpad kind=... surface=... selection=...
```

Do not enable `EDGE_RAW_DUMP` unless the existing 96-byte contact ABI itself needs revalidation. Confirm Release builds contain neither probe output nor raw-touch logging.

## 4. Required hardware matrix

Use a MacBook with its built-in trackpad plus an external Magic Trackpad if possible:

1. Automatic, external disconnected: built-in input works exactly like 1.2.1.
2. Automatic, both connected: record which device is selected; existing default behavior must remain stable.
3. Built-in, both connected: only the built-in trackpad controls EdgeControl.
4. External, both connected: only the Magic Trackpad controls EdgeControl; Magic Mouse must not trigger it.
5. External, disconnected: visible Unavailable error, no crash, no silent built-in fallback.
6. Connect external, click Rescan Trackpads: status becomes External and gestures work.
7. Disconnect external once while Candidate and once while Active: recognition resets within about 750ms; Active also restores cursor and haptic state. If old non-empty frames resume, they must be ignored until lift or rescan.
8. Reconnect and rescan; then test sleep/wake and relaunch with External persisted.
9. If more than one external Magic Trackpad is available, document which one is selected; 1.3.0 intentionally chooses the first matching device.

For both built-in and external devices, verify normalized x/y, upward polarity, left/right edge births, 450ms admission, 3%/8% corridors, 0.80 directionality, multi-touch latch, lower-half admission, no-jump mapping at initial values near 20% and 80%, HUD, volume, brightness, and cursor restore.

Record whether public haptic feedback is felt on the expected physical device; do not claim external-device haptics without evidence.

## 5. Release decision

Update `BUILD_REPORT.md` with exact Mac, macOS, Xcode, Magic Trackpad generation/connection mode, surface dimensions, selected-kind logs, and PASS/FAIL results. If required external tests fail, return a report and source patch; do not tag or upload 1.3.0.

Only after all required checks pass, build the zero-cost ad-hoc DMG:

```bash
APP="build/DerivedData/Build/Products/Release/EdgeControl.app"
codesign --force --deep --sign - "$APP"
./Scripts/package_dmg.sh "$APP" "dist/EdgeControl-1.3.0-macOS.dmg"
hdiutil verify "dist/EdgeControl-1.3.0-macOS.dmg"
shasum -a 256 "dist/EdgeControl-1.3.0-macOS.dmg"
```

Mount, install, and repeat the built-in/external smoke tests. Then commit, tag `v1.3.0`, push, and create the GitHub Release with `Docs/RELEASE_NOTES_1.3.0.md`. Upload only the DMG and checksum; never upload credentials, DerivedData, `.xcarchive`, or private signing material.
