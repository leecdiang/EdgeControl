# OpenClaw task — validate and release EdgeControl 1.3.1

Work only in this tree. Preserve all 1.3.0 gesture and external-trackpad behavior. Do not refactor unrelated code.

## 1. Automated checks

```bash
./Scripts/validate_repository.sh
./Scripts/build_release.sh test
./Scripts/build_release.sh build
```

Require 40/40 tests and no new warnings. Then build Universal 2 and confirm `arm64` plus `x86_64` with `lipo -info`.

## 2. Built-in-only brightness regression

With External DDC off and no external display:

1. Run at least 20 brightness gestures; no DDC message may appear.
2. Change display scaling once, then repeat.
3. Sleep/wake three times and test immediately and again after five seconds.
4. Toggle External DDC on, confirm the built-in panel still has priority, turn it off, and repeat.
5. Confirm a display-change notification ends an active gesture safely; the next gesture must recover normally.

In Debug logs, every built-in-only activation must report `backend=built-in`; `backend=external-ddc` is a failure in this matrix. Confirm both strings are absent from the Release binary.

Expected: built-in brightness remains continuous. A temporary failure may report built-in brightness unavailable, but a Mac with no usable external connection must never show `No external DDC...`, regardless of the toggle's stored state.

## 3. Optional external-display regression

If a DDC-capable monitor is available, confirm fallback occurs only when DDC is enabled and the built-in panel is unavailable. If no monitor is available, keep DDC hardware status unverified.

## 4. Release

Read `Docs/STATIC_BUG_AUDIT_1.3.1.md` and do not claim validated external DDC support. Update `BUILD_REPORT.md` with exact evidence. Only after all required checks pass, package and verify `dist/EdgeControl-1.3.1-macOS.dmg`, generate SHA-256, install-test it, commit, tag `v1.3.1`, and push. Before publishing, update the validation evidence and replace `OPENCLAW_REPLACE_WITH_FINAL_DMG_SHA256` in the root `RELEASE_NOTES_1.3.1.md`; then publish the DMG using that complete bilingual file. Never upload credentials, DerivedData, archives, or signing material.
