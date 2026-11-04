# EdgeControl 1.8.6 validation

Version 1.8.6 / build 20 includes the reviewed changes in 54ad71d and 5fa9d4d plus release metadata. The detailed findings, pre-fix failures and limitations are in [the code review](Docs/REVIEW_2026-11-04.md).

Local validation of the reviewed implementation completed with 174 XCTest cases and zero failures, eight update-feed regressions, native HUD rendering checks, and arm64/x86_64 Release compilation. Simulated DisplayServices loading passed concurrent success/failure and missing-symbol recovery tests, including ThreadSanitizer. No physical volume/brightness changes or haptic feel are inferred from these tests.

Publication requires the exact candidate commit to pass the repository CI, then verifies its retained SOURCE_COMMIT, ZIP/DMG hashes, universal app and nested signatures. The archive is signed using the existing local Keychain Sparkle key and checked against the app's embedded public key and the currently installed app's trusted key. The generated appcast is parsed by the pinned Sparkle version before publishing; downloaded release assets are compared byte for byte before marking the release latest.

The publish script supports `--publish-only` so the current installed version can exercise Sparkle's real online updater first. Manual installation remains a separate verified, backup-preserving fallback. A successful feed/signature check alone is not evidence of an end-to-end online installation. Actual publication and installation results are recorded separately after execution.
