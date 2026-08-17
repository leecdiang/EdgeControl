# OpenClaw task — validate and release EdgeControl 1.4.0

Work only in this tree. Preserve all 1.3.0/1.3.1 gesture, brightness, HUD, and trackpad behavior. Do not refactor unrelated code or implement the inherited findings in `Docs/STATIC_BUG_AUDIT_1.3.1.md` during this release pass.

## 1. Automated checks

```bash
./Scripts/validate_repository.sh
./Scripts/build_release.sh test
./Scripts/build_release.sh build
```

Require 52/52 tests and no new warnings. Build Universal 2 and confirm `arm64` plus `x86_64` with `lipo -info`. Confirm Release contains no Debug touch logging and no key-event tap/global-monitor symbols.

## 2. Adjustment-speed and false-touch matrix

On the built-in trackpad, test both edges and both actions:

1. Verify Precise / Standard / Fast change only post-activation gain (`0.75×` / `1.00×` / `1.35×`). Activation geometry and typing protection must not change.
2. Verify Strong / Standard / Light reject before 600ms / 350ms / 200ms respectively and admit a new deliberate lifecycle at or after the boundary.
3. Capture raw births near both thresholds and verify left strips 0.6% / 0.8% / 1.0% and right strips 1.2% / 1.5% / 1.9%. Confirm the right-side asymmetry is usable on real hardware.
4. For every protection profile, recheck the unchanged 450ms deadline, 3% pre-activation corridor, 8% Active corridor, 0.80 directionality and multi-touch latch.
5. Keep a typing-rejected finger down beyond the boundary and move it: it must remain rejected until lift.
6. Begin an edge candidate, press a key before activation, then move vertically: it must reject until lift.
7. Activate a real gesture, then press a key while adjusting: control must continue without cancellation or value jump.
8. Change speed during an Active gesture: the current gesture must retain its pinned gain, and the next gesture must use the new speed.
9. Change false-touch protection or lower-half admission while a finger is down: the contact must remain discarded until lift and must never become a fresh birth.
10. Confirm an existing 1.3.x preference at `0.35`, `1.00`, and `1.65` migrates to Precise, Standard, and Fast.
11. Repeat with key repeat, an external keyboard, after sleep/wake, and across all profile combinations.

Use a clean macOS account with no previous TCC grants. No Accessibility or Input Monitoring prompt may appear. Confirm the app never receives/logs a key code or text value. If a prompt appears, stop the release and report exact macOS/build evidence.

## 3. Regression

- Re-run the full physical gesture matrix: 450ms admission, 3%/8% corridors, 0.80 directionality, multi-touch latch, lower-half mode, no-jump mapping, cursor restoration, HUD, and haptics.
- Re-run the 1.3.1 built-in-only brightness matrix: 20 gestures, display scaling, three sleep/wake cycles, and DDC toggle on/off without any false DDC error.
- If no external Magic Trackpad or DDC monitor is available, keep those paths explicitly unverified.

## 4. Release

Update `BUILD_REPORT.md` with exact evidence. Only after all required checks pass, package and verify `dist/EdgeControl-1.4.0-macOS.dmg`, generate SHA-256, install-test it, commit, tag `v1.4.0`, and push. Update the validation evidence and replace `OPENCLAW_REPLACE_WITH_FINAL_DMG_SHA256` in root `RELEASE_NOTES_1.4.0.md`; publish the DMG using that complete bilingual file. Never upload credentials, DerivedData, archives, or signing material.
