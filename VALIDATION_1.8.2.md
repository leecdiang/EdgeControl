# EdgeControl 1.8.2 validation

## Changes and scope

The user reported reversed Capsule/Notch preview images. Static enum routing was correct; the old preview maintained a second ObservableObject copied in onAppear/onChange. This change removes that synchronization path rather than swapping correct enum labels. A rendered regression test switches Capsule → Notch → Off → Capsule → Notch → Capsule in one hosted view and checks the black notch silhouette appears only for Notch. This verifies the replacement behavior; it does not establish the precise cause of the original report.

Settings had an opaque SwiftUI windowBackgroundColor over their existing AppKit NSVisualEffectView. That occlusion is removed. The same production backdrop factory is now used by screenshots, and the neutral scrim resolves colors in its window's actual appearance. Native Liquid Glass is used for navigation and preview buttons on macOS 26+; content cards retain regular material. Reduce Transparency and older systems have explicit fallbacks. The menu panel adds an 18% neutral scrim over the existing system material.

## Validation

146 XCTest methods include rendered mode-switch coverage and light/dark backdrop resolution. Native snapshots cover all three settings pages at the production 620×640 size, menu panels and Capsule/Notch/Off samples, in both appearances. Repository invariants, shell syntax and whitespace checks run locally; the PR records full CI and screenshot review results once complete. Screenshot bitmaps verify layout, labels and contrast; live glass refraction over changing desktop content still requires local visual inspection.

Physical checks: open the menu over light/dark wallpaper, switch HUD modes repeatedly, inspect the actual settings window and Reduce Transparency behavior. Release and local installation remain separate from PR merge.

## Design references

Apple recommends Liquid Glass for navigation and control layers and standard materials for content:
https://developer.apple.com/design/human-interface-guidelines/materials
https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
