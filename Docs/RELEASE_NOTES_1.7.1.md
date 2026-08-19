# EdgeControl 1.7.1

A follow-up polish release on top of 1.7.0: it fixes the frosted Settings window (the glass now renders as the window's real background instead of showing through as transparent), widens the edge entry strips further, and lightens the Morandi volume color to a soft baby blue.

## Fixed

- **Frosted Settings window renders correctly.** The 1.7.0 window could show a fully transparent background because the visual effect lived inside SwiftUI's `.background`, which does not paint reliably in a transparent titled window. The glass is now the window's actual base content view (an `NSVisualEffectView` with `popover` material behind the SwiftUI content), matching the menu-bar popover.

## Changed

- **Edge entry strips widened further.** All three false-touch-protection presets get a larger birth range so deliberate edge ingresses trigger reliably:

  | Preset | Left strip | Right strip |
  |---|---|---|
  | Strong | 0.7% → 1.0% | 1.4% → 1.8% |
  | Standard | 0.9% → 1.2% | 1.7% → 2.2% |
  | Light | 1.2% → 1.5% | 2.1% → 2.6% |

- **Morandi volume color lightened.** The volume accent in the Morandi palette is now a soft baby blue (`#A3C1DE`) instead of the darker dusty slate blue.

## Tests

- 68 XCTest methods; false-touch strip assertions updated to the new widths and boundary cases.

## Known limitations (unchanged)

- External DDC remains experimental and off by default; it must not be treated as a formally supported feature.
- If the default audio output device changes mid-gesture, volume changes can still be applied relative to the old device's initial value.
- External Magic Trackpad selection, Intel runtime, other macOS versions, and clean-machine Gatekeeper remain hardware/environment dependent.

SHA-256: `e584594553e20770994246368599e5b25102d305ddfeebef173337d8224959b8`
