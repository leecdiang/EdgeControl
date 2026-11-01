# BUILD_REPORT — EdgeControl 1.7.5

Date: 2026-11-01
Status: **VALIDATED HAPTIC FOLLOW-UP CANDIDATE — build 11, 90/90 tests, Universal 2 Release, signature and DMG/ZIP checks PASS. Publishing remains paused.**

The prior build 10 candidate passed 86 tests, Universal 2 build and package checks, but is superseded by the haptic cooldown fix. Do not publish it using run 41280473174. The release helper now requires build 11.

The local before/after haptic trace confirms a previously consumed cooldown-suppressed detent now requests feedback on the next eligible movement. Physical actuator delivery has not been verified. See [release notes](RELEASE_NOTES_1.7.5.md), [haptic audit](Docs/HapticValidation.md), and [validation](VALIDATION_1.7.5.md). Installed and published version remain 1.7.4.

Final tested source: `1358eed1fc854b434b1bf54e89e0dc9807079a57`. [CI run 41281336655](https://github.com/leecdiang/EdgeControl/actions/runs/41281336655).
