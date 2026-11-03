# EdgeControl 1.8.5 validation

## Observed installation and scope

The inspected `/Applications/EdgeControl.app` was already 1.8.4. Its compiled AppIcon.icns rendered the pearl-glass artwork, so the new icon was present in the installed package. The menu bar and menu header independently referenced `slider.vertical.3`; those were still three-rail symbols. Process and system-icon cache inspection was unavailable in the sandbox, so this does not establish the cause of stale artwork in any particular external launcher. No global icon caches were deleted and no other desktop processes were restarted.

Both menu locations now share one 18 pt vector NSImage template with two rails and staggered thumbs. Template rendering follows system contrast and backing scale. The app explicitly assigns its bundled AppIcon to NSApplication at startup for its own windows. External launcher caches remain managed by macOS.

The existing pearl-glass design is retained. Blue and orange inward arrows cross the illustrated trackpad boundary and connect to rounded vertical tracks, with staggered touch points. All ten AppIcon sizes, the ICNS and README assets are rebuilt from the 1024 px master. The generated source is retained separately. Small-size artwork is visually inspected, and native light/dark menu/settings screenshots exercise the shared symbol and bundled icon.

## Checks

Required checks: existing 151 XCTest methods, eight update-feed regressions, actual Sparkle parsing and installer-selector integration, universal Release compilation, asset-catalog compilation, ZIP/DMG integrity and code signatures. Repository invariants, shell syntax and whitespace checks run locally. CI and screenshot evidence are recorded in the PR. No hardware-control, gesture or haptic code changes.
