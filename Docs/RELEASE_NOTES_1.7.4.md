# EdgeControl 1.7.4

A reliability release focused on login items, HUD placement, and updater preferences. No gesture, haptic, brightness, or DDC behavior was intentionally changed.

## Fixed

- **Launch at login approval.** A registered login item that is waiting for approval in System Settings is no longer treated as unregistered. The switch stays on, turning it off unregisters it, and Settings shows an "Open Login Items" action when approval is pending.
- **Stale login-item state.** The service status is re-read when the app becomes active, so external changes in System Settings appear without a relaunch.
- **HUD placement after display changes.** The overlay now repositions when the current display's usable area changes, not only when the display ID changes.
- **Forced automatic update checks.** EdgeControl no longer sets `automaticallyChecksForUpdates = true` on every launch. The Info.plist default applies on first run; afterwards the user's Sparkle preference is honored.

## Tests

- 76 XCTest methods pass.
- Repository validation and Universal 2 Release build pass.
- Ad-hoc bundle signature verifies with `codesign --verify --deep --strict`.

## Known limitations (unchanged)

- External DDC is experimental and off by default.
- Intel runtime, external trackpads, other macOS versions, sleep/wake, Sparkle relaunch, and clean-machine Gatekeeper behavior remain unverified.
- Ad-hoc signed; not notarized.
