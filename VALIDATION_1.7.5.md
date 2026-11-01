# EdgeControl 1.7.5 validation

Version/build: **1.7.5 (11)**. Status: haptic follow-up candidate; publishing paused.

- Local repository check: PASS, 90 test methods.
- Local deterministic haptic trace: original code requests 1 pulse across 0/10/40/80ms; fixed code requests 2, with the recovered request at 40ms. No physical hardware was actuated.
- Four additional regressions cover cooldown suppression recovery, reversal without stale replay, gesture-end reset, and unavailable-backend recovery.
- Full XCTest: **90/90 PASS**, zero failures. Universal 2 Release, deep/strict ad-hoc signature verification, DMG checksum and ZIP integrity checks: **PASS** in [CI run 41281336655](https://github.com/leecdiang/EdgeControl/actions/runs/41281336655). Tested source: `1358eed1fc854b434b1bf54e89e0dc9807079a57`.
- Superseded build 10 was validated in run 41280473174. It does not contain this haptic fix; the release helper rejects it by build number.
- Physical haptic/gesture verification on macOS 27.0.1, external trackpad/DDC, Intel runtime, Sparkle installation/relaunch, and the Control Center incident reproduction are not tested.
- Publication and local installation remain blocked by this session's Keychain (OSStatus -50) and filesystem access. Published/installed version remains 1.7.4 (9).

The public haptic API only acknowledges the request at the language-call level, not physical vibration; no unit-test result should be interpreted as hardware delivery confirmation.

The validated build 11 artifact is `EdgeControl-candidate-1358eed1fc854b434b1bf54e89e0dc9807079a57`. The release helper requires build 11; run 41281336655 supersedes the old command targeting run 41280473174. Publication remains paused while the haptic report is reviewed.
