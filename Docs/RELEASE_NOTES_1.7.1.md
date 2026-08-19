# EdgeControl 1.7.1

A follow-up polish release on top of 1.7.0: it fixes the frosted Settings window (the glass now renders as the window's real background instead of showing through as transparent), widens the edge entry strips further, lightens the Morandi volume color to a soft baby blue, and polishes the Settings window UI with a borderless tab row and layered frosted cards.

## Fixed

- **Frosted Settings window renders correctly.** The 1.7.0 window could show a fully transparent background because the visual effect lived inside SwiftUI's `.background`, which does not paint reliably in a transparent titled window. The glass is now the window's actual base content view (an `NSVisualEffectView` with `popover` material behind the SwiftUI content), matching the menu-bar popover.

## Added

- **Borderless settings tab row.** The four tabs (Controls / Feedback / Devices / About) are now independent capsule buttons in their own top area with a stable gap above the content cards — no enclosing segmented border or divider lines, so the tabs no longer appear to straddle a line. Keyboard navigation stays native: each tab is focusable, Tab moves between tabs, Space activates. Content cards keep their scroll state when switching.
- **Layered frosted cards.** Settings cards sit one step above the window glass (more solid fill, fine border, soft shadow) so the background keeps its real behind-window blur while cards read as a distinct layer. Reduce Transparency switches cards to a near-opaque fill.

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

SHA-256: `ec2bd1a4c29ce3dcc3bd964139b461a0b1013724f55eebe0d3a90d5643b68177`
