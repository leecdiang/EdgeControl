# EdgeControl 1.5.0

Adds three haptic-strength profiles and a denser, genuinely frosted compact HUD.

## New

- Haptic feedback now has Light, Standard, and Strong profiles. Existing installs default to Standard and retain the original enable/disable preference.
- Light uses subtle alignment feedback at 4% detents, Standard preserves the original alignment feedback at 2%, and Strong uses the firmer public AppKit generic pattern at 2%.
- The selected haptic profile is pinned when a gesture activates, so changing Settings cannot alter the tactile character midway through a swipe.
- The unsupported private actuator remains disabled; the profiles use only `NSHapticFeedbackManager` and require no permission.

## HUD

- The normal HUD is reduced from 148×42 to 144×40; error presentation is reduced from 220×42 to 212×40.
- A capsule-clipped active `NSVisualEffectView` now supplies real `.hudWindow` backdrop blur on macOS 13+.
- A 52% semantic veil, slightly stronger tint, fine highlight border, and tuned shadow improve contrast without losing the frosted background.
- AppKit layer clipping plus SwiftUI capsule clipping prevents the rectangular material plate seen in the earlier Liquid Glass attempt.
- Reduce Transparency still uses a fully opaque system background; Reduce Motion still removes the scale transition.

## Tests and validation

- Three regressions cover haptic preference persistence/fallback, Standard compatibility, Light detent density, and Strong pattern selection. The source suite now contains 55 XCTest methods.
- Source-side repository guards and shell checks pass. Xcode build/tests and physical haptic/HUD inspection remain required on macOS before publishing.
- AppKit exposes system feedback patterns, not a numeric amplitude. Perceived ordering can vary by hardware; validate built-in and external Force Touch trackpads.
