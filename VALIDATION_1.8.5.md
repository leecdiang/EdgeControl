# EdgeControl 1.8.5 validation

## Observed installation and scope

The inspected `/Applications/EdgeControl.app` was already 1.8.4. Its compiled AppIcon.icns rendered the pearl-glass artwork, so the new icon was present in the installed package. The menu bar and menu header independently referenced `slider.vertical.3`; those were still three-rail symbols. Process and system-icon cache inspection was unavailable in the sandbox, so this does not establish the cause of stale artwork in any particular external launcher. No global icon caches were deleted and no other desktop processes were restarted.

Both menu locations now share one 18 pt vector NSImage template with two rails and staggered thumbs. Template rendering follows system contrast and backing scale. The app explicitly assigns its bundled AppIcon to NSApplication at startup for its own windows. External launcher caches remain managed by macOS.

The existing pearl-glass design is retained. Blue and orange inward arrows cross the illustrated trackpad boundary and connect to rounded vertical tracks, with staggered touch points. All ten AppIcon sizes, the ICNS and README assets are rebuilt from the 1024 px master. The generated source is retained separately. Small-size artwork is visually inspected, and native light/dark menu/settings screenshots exercise the shared symbol and bundled icon.

## Checks

Required checks: 154 XCTest methods, eight update-feed regressions, actual Sparkle parsing and installer-selector integration, universal Release compilation, asset-catalog compilation, ZIP/DMG integrity and code signatures. Repository invariants, shell syntax and whitespace checks run locally. CI and screenshot evidence are recorded in the PR. No hardware-control, recognition or haptic code changes.

## Notch motion follow-up

The previous outline spring and separately delayed content fade could look like two distinct steps. A single animatable expansion now controls outline width, wing centers and a continuous smoothstep opacity curve. Each wing is clipped independently, preserving the physical camera gap throughout motion. A 0.40 s critically damped spring replaces the 0.32 s outline spring; there is no content delay or blur animation. Reduce Motion still uses a short opacity fade without horizontal expansion.

The controller commits its collapsed layout and gates reveal for one render opportunity. High-frequency value updates cannot bypass that gate. A new value during retraction reverses the existing presentation without ordering another window front. Immediate hide cancels pending reveal and disables implicit animation.

Gesture lifetime now owns the HUD timeout: it stays visible through stationary pauses and starts the 650 ms grace period on lift. Preview calls do not open a held gesture. Error messages retain the longer 1.5 s timeout. Three controller regressions cover first-frame bursts and cancellation, held pauses and interrupted retraction, and preview/error dismissal. Existing native snapshots cover camera clearance, retraction and Reduce Motion; actual hardware timing and perceived smoothness still require user observation.

The local xcodebuild test attempt could not resolve packages because the sandbox denied SwiftPM diagnostics access under the user's Library cache. Native execution therefore uses macOS CI; no local XCTest success is claimed for that attempt.
