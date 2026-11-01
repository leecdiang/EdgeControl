# EdgeControl 1.7.6 candidate validation

Review baseline: main da3030a4172a9df3a21f1560bdd074e3b4258968 (1.7.5 build 11).
Candidate: 1.7.6 build 12, PR #2, branch fix/1.7.6-review-followups.

| Finding | Resolution | Behavior coverage |
|---|---|---|
| F1 stale frames | callback receipt uptime; 150ms age bound; locked 32-frame FIFO; overflow cancellation/lift latch; stop generation invalidation | stale/future/non-finite receipt, clock-domain independence, overflow and lift, scheduling and ordering, stop |
| F2 pause cleanup | synchronous settings subscriptions end sessions and restore cursor | master disable/re-enable, action disable, edge reassignment, paused birth |
| F3 DDC parsing | full 11-byte reply with source/length/virtual-host checksum; actual reply length; mach tick conversion | independent valid wire fixture, old bad checksum, truncation, wrong headers/VCP/result/type, invalid range, 16-bit values |
| F4 audio balance | gesture pins channel layout and ratios; peak-based level; zero preserves balance | asymmetry, zero/full scale, neutral all-zero state, master scalar, layout change, partial-write rollback/retry |
| F5 finite-only audio | validate initial/all-channel/prewrite reads and write input before hardware writes | NaN and infinities, partial read, mid-session read failure, no writes on invalid values |
| F6 disclosure | correct About/privacy text and expose Sparkle-owned automatic checks | core integration typecheck; CI compiles actual Settings UI |

Local checks completed: repository invariants (114 XCTest methods), C clang static analysis, core Swift integration typecheck with only SettingsView replaced by EmptyView because the local SwiftUI macro service cannot launch within the session sandbox. This stub check does not claim to validate the actual UI.

The archived review probes intentionally describe the old defective behavior and refuse to run against a changed tree. Current regressions live in EdgeControlTests/SettingsTests.swift.

CI status is recorded in PR #2 after the exact candidate run completes. Installation uses Scripts/install_ci_candidate.sh with a successful push run and its expected full commit SHA. It validates repository/workflow/event, source marker, hashes, ZIP/DMG integrity, version/build, bundle identifier, unchanged Sparkle key, Universal2 slices and deep code signatures before replacing the installed app. The old app is retained for rollback. This does not publish a release or claim notarization.

Physical DDC transport/monitor compatibility, private touch ABI, Bluetooth reconnect and perceived haptic behavior still require hardware validation. Synchronous device API calls are not interruptible; stale rejection prevents queued replay after delays, but cannot guarantee main-thread responsiveness while the OS call itself is blocked.
