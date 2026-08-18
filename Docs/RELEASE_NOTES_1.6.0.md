# EdgeControl 1.6.0

Adds a custom frosted menu-bar popover, grouped Settings, and System/Classic/Aurora HUD color styles while retaining every 1.5.1 reliability fix.

## Interface

- A 304-point window-style menu presents live status, edge cards, Haptic/HUD/Login quick toggles, Settings, and Quit.
- Settings now separates Controls, Feedback, Devices, and About into compact system-rendered cards.
- The Settings window uses a stable initial/minimum size instead of fitting itself to the current tab.

## HUD color

- System is neutral, Classic uses system blue/orange, and Aurora uses system purple/teal.
- Only the progress fill is strongly colored; the glass, text, symbol, and track remain neutral.
- Legacy `colorfulHUD` values migrate to System/Classic and are stored under `hudColorStyle`.

## Validation

- The source contains 61 XCTest methods.
- Source-side repository validation passes.
- Run `OPENCLAW_VALIDATE_1.6.0.md` on macOS before publishing.
