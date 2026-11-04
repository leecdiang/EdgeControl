# EdgeControl 1.8.6

- Keeps active gestures alive when switching between Capsule, Notch and Off, and cancels obsolete reveal/dismiss tasks.
- Runs the touch-silence watchdog only during live, enabled contacts; lift, disablement and reset stop it.
- Detects a callback gap before a resumed frame can hide it, restoring cursor movement and requiring a fresh lift.
- Prevents queued touches and old lift frames from becoming new gestures after a quick disable/re-enable or admission-setting change.
- Offers the main actor a scheduling point every eight queued frames while preserving order, overflow protection and cancellation.
- Reuses successfully resolved DisplayServices entry points, removes duplicate audio property queries, and avoids unchanged error notifications and unnecessary capsule backdrop layout.
- Removes a faded capsule window sooner while retaining the notch spring's reversible settling period.
- Rejects regressing device timestamps within a touch lifecycle.

Haptic patterns, detent spacing and gesture sensitivity remain unchanged. Validation covers 174 XCTest cases, eight update-feed tests, concurrent DisplayServices loader tests and universal Release compilation. Real trackpad feel, multi-display behavior and energy use still require hardware observation; no percentage performance improvement is claimed.

The app remains ad-hoc signed and not notarized. Sparkle update archives use the existing Ed25519 signing identity.
