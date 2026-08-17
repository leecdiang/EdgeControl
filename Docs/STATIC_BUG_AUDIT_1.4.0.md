# EdgeControl 1.4.0 static audit

Scope: the 1.4.0 recent-typing guard layered on the complete 1.3.1 brightness-routing source. This review ran on a non-macOS staging machine and does not replace Xcode, Thread Sanitizer, clean-account permission checks, or physical hardware testing.

## New-feature review

- The shipping path uses only `CGEventSource.secondsSinceLastEventType`; no event tap, global key monitor, HID keyboard capture, key code, or text storage was added.
- Adjustment speed is independent and changes only the pinned post-activation gain (`0.75×` / `1.00×` / `1.35×`). False-touch protection independently selects 600/350/200ms and asymmetric narrow/standard/wide birth strips.
- The 450ms deadline, 3% candidate corridor, 8% Active corridor, 0.80 directionality, vertical-intent threshold, interior-birth latch and multi-touch latch remain invariant across profiles.
- Invalid, negative, NaN, or infinite elapsed values and invalid protection intervals fail open while the existing gesture protections remain active. Invalid stored preset values fall back to Standard; legacy continuous values migrate to the nearest speed preset.
- Typing suppression applies only to idle/candidate states. Rejection is terminal until an empty frame, so a held palm cannot become a delayed edge birth. Active control is deliberately uninterrupted.
- Speed is pinned at activation, and changing admission settings while a contact is down discards that lifecycle until lift rather than reinterpreting it as a fresh birth. This rebuild path preserves any already-latched callback-watchdog discard state.
- Twelve new unit regressions cover the above invariants. No confirmed defect remains in the new 1.4.0 logic after static review.

## Required physical checks

- Confirm the public Quartz elapsed-time query produces no Accessibility or Input Monitoring prompt on a clean account for every target macOS version.
- Confirm Secure Input, key repeat, external keyboards, sleep/wake, fast typing, and long key holds produce sensible elapsed times.
- Tune the three timing windows and asymmetric birth ranges only from measured false-positive and deliberate-gesture traces; do not add a key-content monitor to improve classification.

## Inherited findings

The five unrelated findings in `Docs/STATIC_BUG_AUDIT_1.3.1.md` remain open: experimental DDC reply parsing, multi-monitor DDC target pinning, stale queued trackpad frames across restart, volume-output pinning, and successful zero-display handling. DDC remains experimental and disabled by default; the release must not claim validated external DDC support.
