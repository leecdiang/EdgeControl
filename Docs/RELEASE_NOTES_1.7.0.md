# EdgeControl 1.7.0

Adds a frosted-glass Settings window that matches the menu-bar popover, slightly wider edge entry strips for more forgiving activation, a new Morandi (muted slate blue) HUD palette, and a Homebrew cask so the app can be installed with `brew install`.

## Added

- **Frosted Settings window.** The Settings window now uses the same full-window material as the first-level menu-bar popover: a transparent title bar over a `popover`-material backdrop with translucent cards. The window stays resizable and movable, and it respects the Reduce Transparency accessibility setting automatically.
- **Morandi HUD palette.** A fourth color style under Settings > Feedback > HUD: muted slate blues — a dusty blue for volume, a misty light blue for brightness — keeping the glass neutral like the other palettes.
- **Homebrew install.** The app is published as a cask in the `leecdiang/edgecontrol` tap:

  ```
  brew tap leecdiang/edgecontrol
  brew install --cask edgecontrol
  ```

  Because EdgeControl is ad-hoc signed and not notarized, Gatekeeper will quarantine the first launch; use `brew install --cask --no-quarantine leecdiang/edgecontrol/edgecontrol` or right-click > Open on the first run.

## Changed

- **Slightly wider edge entry strips.** All three false-touch-protection presets widen the physical birth range a little so deliberate edge ingresses trigger more reliably:

  | Preset | Left strip | Right strip |
  |---|---|---|
  | Strong | 0.6% → 0.7% | 1.2% → 1.4% |
  | Standard | 0.8% → 0.9% | 1.5% → 1.7% |
  | Light | 1.0% → 1.2% | 1.9% → 2.1% |

  The asymmetry between left and right (and the palm-rejection rules: directionality, zero-cross cancellation, typing suppression) is unchanged.

## Tests

- 68 XCTest methods (67 carried over plus a new Morandi palette persistence test; the false-touch strip assertions were updated to the new widths).

## Known limitations (unchanged)

- External DDC remains experimental and off by default; it must not be treated as a formally supported feature.
- If the default audio output device changes mid-gesture, volume changes can still be applied relative to the old device's initial value.
- External Magic Trackpad selection, Intel runtime, other macOS versions, and clean-machine Gatekeeper remain hardware/environment dependent.

SHA-256: `2a7dd2b5c9416432f5aeb7aedde0cf85eca0eeb6832dddbe4ce101606bfd6ffb`
