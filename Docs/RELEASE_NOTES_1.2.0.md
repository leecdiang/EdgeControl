# EdgeControl 1.2.0

Edge gestures with palm defense, a calmer default HUD, and trackpad control that stays in the lower half if you want it to.

## What's new

- Lower-half-only mode: edge control only responds to the lower half of the trackpad. The midline maps to 100%, the very bottom to 0%. Contacts that start above the midline are rejected, which cuts down palm and stray-touch triggers. Positions are normalized per trackpad, so it works across Mac models.
- Colorful HUD is now opt-in. The HUD defaults to a neutral system style; turn on "Colorful HUD" in Settings to bring back the tinted volume/brightness colors.

## What changed

- Gesture admission is stricter: 450ms entry timeout, a 3% corridor before activation, an 8% corridor after, and a 0.80 directionality requirement. Palm jiggle gets rejected before it becomes a control session.
- Detent haptics fire every 2% instead of every 5%, with a shorter 30ms cooldown.
- HUD is a single-line capsule, 148x42 normally and 220x42 for errors, hosted on one persistent view. macOS 26 uses the native Liquid Glass effect; older systems fall back to a material background. Reduce Motion and Reduce Transparency are respected.
- DDC settings for external displays persist across launches.
- The settings window sizes itself to its content instead of a fixed 520x420 box.
- Raw touch logging in the C bridge is compiled out of Release builds.
- The DMG packaging script now detaches the temporary mount reliably before finishing.

## Fixed

- "Touch input" row in Settings was not aligned with the rows above it.

## Misc

- About page now credits leecdiang.
- CI workflow added.
- Test suite grew from 29 to 31 tests, including regression coverage for the lower-half mode.

## Notes

- Release binary verified free of EDGE_RAW_DUMP and ECProbe paths.
- Gesture tuning details and validation notes live in Docs/GestureTuning.md and Docs/LOCAL_VALIDATION_REQUIRED.md.
