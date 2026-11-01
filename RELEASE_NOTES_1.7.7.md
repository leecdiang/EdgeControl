# EdgeControl 1.7.7 (build 13)

- Add feedback during steady, meaningful adjustment between value detents; tiny jitter and stationary holds remain silent.
- Coalesce a cooldown-suppressed crossing into one cancellable request instead of requiring another movement to retry.
- Acknowledge arrival at 0% and 100% once. Cancel pending feedback on gesture end, disablement, new gesture, or wake; discard stale requests.
- Prevent delayed Strong secondary pulses from replaying after a blocked main thread, and include secondary requests in cooldown accounting.
- Add local Haptics debug logs to distinguish scheduling decisions from requests sent to AppKit.

The public AppKit API does not acknowledge physical delivery. The changes address reproduced scheduling gaps; the reported intermittent physical loss still needs device validation.
