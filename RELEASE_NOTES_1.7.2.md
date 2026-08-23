# EdgeControl 1.7.2

## Highlights

- Restored the 1.4.0 false-touch protection baseline for edge-birth strips:
  - Strong: 0.6% left / 1.2% right
  - Standard: 0.8% left / 1.5% right
  - Light: 1.0% left / 1.9% right
- Added Sparkle-based update checks and a manual Check for Updates menu action.
- Added signed appcast publishing support for GitHub Releases.
- Fixed ad-hoc release signing for Sparkle's nested framework, helper app, and XPC bundles.

## Verification

- 68 XCTest cases pass.
- Repository validation passes.
- Release app bundle passes `codesign --verify --deep --strict`.
