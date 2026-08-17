# OpenClaw release task — EdgeControl 1.2.1

Work only in this extracted source tree. Do not rewrite working features or weaken gesture guards.

1. Review the diff from GitHub `main` commit `1ac05bd7a40f4e72aba37149f0a342e06ed39645`.
2. Run:

   ```bash
   ./Scripts/validate_repository.sh
   ./Scripts/build_release.sh test
   ./Scripts/build_release.sh build
   ```

   Expect 32 tests. Stop on any failure.

3. Physically verify normal and "Start in lower half only" modes. At initial values near 20% and 80%, enter at low, middle, and high allowed positions. Activation must not change the value; only post-activation vertical movement may change it. Recheck 450ms admission, palm rejection, both edges, HUD, 2% haptics, cursor restore, sleep/wake, and settings persistence.
4. Update `BUILD_REPORT.md` with actual results. Do not convert pending items to PASS without evidence.
5. Build the zero-cost ad-hoc release and package:

   ```bash
   APP="build/DerivedData/Build/Products/Release/EdgeControl.app"
   codesign --force --deep --sign - "$APP"
   ./Scripts/package_dmg.sh "$APP" "dist/EdgeControl-1.2.1-macOS.dmg"
   hdiutil verify "dist/EdgeControl-1.2.1-macOS.dmg"
   shasum -a 256 "dist/EdgeControl-1.2.1-macOS.dmg"
   ```

6. Mount the DMG, drag the app to `/Applications`, launch it, and repeat the no-jump smoke test. Confirm Release output contains no raw-touch diagnostics.
7. Only after all required checks pass: commit the source changes, tag `v1.2.1`, push, and create the GitHub Release using `Docs/RELEASE_NOTES_1.2.1.md`. Upload the DMG and publish its SHA-256. Do not upload credentials, DerivedData, `.xcarchive`, or private signing material.

