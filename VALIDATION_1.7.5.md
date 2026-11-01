# EdgeControl 1.7.5 validation

Version/build: 1.7.5 (10). Status: candidate; not yet published.

- Repository validation: PASS; 86 test methods.
- Full XCTest: 86/86 PASS in GitHub Actions run 41280008917 on candidate 8d6c0fd. Release build and DMG/ZIP package validation also PASS in that run. Explicit Universal 2 verification is scheduled in the follow-up candidate. Local Xcode package resolution is blocked by sandbox access to its manifest diagnostics cache.
- Synthetic review probe on 1.7.4 reproduced 120 redundant endpoint changes in 120 horizontal-jitter frames.
- New tests cover endpoint/Float deduplication, new-session cache isolation, failure retry, invalid values, horizontal jitter, invalid touch lifecycle, and empty display enumeration.
- Real Control Center incident reproduction, physical sleep/wake, external DDC/trackpad, Intel runtime, and Sparkle update install: not tested.
- CI package generation and DMG/ZIP validation: PASS in the above run. Sparkle Ed25519 signing and public-release download verification remain blocked/pending: the local signing helper cannot access the existing Keychain key (OSStatus -50). No production release or local installation has been changed.

`Scripts/publish_validated_release.sh RUN_ID SIGN_UPDATE_PATH` completes signing, verification against the bundled public key, draft upload/download hash checks, publication, and installation with a recoverable backup from a normal local terminal. It refuses a failed CI run, mismatched source commit, invalid signatures, or an existing release tag. No signing key is exported.
