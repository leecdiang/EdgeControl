# EdgeControl 1.7.5 validation

Version/build: 1.7.5 (10). Status: candidate; not yet published.

- Repository validation: pending final run.
- Full XCTest and Universal 2 build: pending CI. Local Xcode package resolution is blocked by sandbox access to its manifest diagnostics cache.
- Synthetic review probe on 1.7.4 reproduced 120 redundant endpoint changes in 120 horizontal-jitter frames.
- New tests cover endpoint/Float deduplication, new-session cache isolation, failure retry, invalid values, horizontal jitter, invalid touch lifecycle, and empty display enumeration.
- Real Control Center incident reproduction, physical sleep/wake, external DDC/trackpad, Intel runtime, and Sparkle update install: not tested.
- Packaging/signature/appcast/download verification: pending.
