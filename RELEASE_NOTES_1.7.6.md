# EdgeControl 1.7.6 (build 12)

- Reject touch frames older than 150ms using callback receipt time, bound the input mailbox to 32 frames, and require lift after overflow or stale input. Stop invalidates queued callback generations.
- End control immediately when paused, when its action is disabled, or when its edge is reassigned. Restore the cursor and cancel haptics without waiting for movement. Disabling HUD hides it immediately.
- Preserve per-channel audio balance across zero and full scale. Peak channel volume represents the overall level when no master control exists. Validate all reads before writing, reject non-finite values, detect layout changes, roll back partial failures where possible, and deduplicate successful writes per gesture.
- Parse complete DDC/CI brightness replies with the correct source/length/checksum and actual received length; reject malformed ranges and convert reply delay into mach absolute ticks.
- Correct the network disclosure and expose Sparkle's saved automatic-update preference in About.

This is a PR candidate; no new public release is created by the CI installer. The previous Control Center incident remains unattributed, and physical multi-device/DDC behavior still needs hardware validation.
