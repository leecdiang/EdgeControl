import AppKit
import SwiftUI

/// Shared visual constants for the small, translucent surfaces in EdgeControl.
enum EdgeUITheme {
    static let controlAccent = Color(nsColor: .controlAccentColor)

    // Stabilizes behind-window vibrancy while preserving translucency.
    static let settingsNeutralScrimOpacity: Double = 0.24
    // Keeps the HUD glass from inheriting large background color swings.
    static let hudNeutralVeilOpacity: Double = 0.64
}

enum HUDPalette {
    struct AccentComponents: Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
    }

    static func accentComponents(style: HUDColorStyle, kind: HUDKind) -> AccentComponents? {
        switch (style, kind) {
        case (.system, _):
            return nil
        case (.classic, .volume):
            return AccentComponents(red: 0.0, green: 0.478, blue: 1.0)
        case (.classic, .brightness):
            return AccentComponents(red: 1.0, green: 0.584, blue: 0.0)
        case (.aurora, .volume):
            return AccentComponents(red: 0.686, green: 0.322, blue: 0.871)
        case (.aurora, .brightness):
            return AccentComponents(red: 0.392, green: 0.820, blue: 0.808)
        case (.morandi, .volume):
            return AccentComponents(red: 0.639, green: 0.757, blue: 0.871)
        case (.morandi, .brightness):
            return AccentComponents(red: 0.624, green: 0.690, blue: 0.769)
        }
    }

    static func accent(style: HUDColorStyle, kind: HUDKind) -> Color {
        guard let components = accentComponents(style: style, kind: kind) else {
            return .primary
        }
        return Color(nsColor: NSColor(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: 1
        ))
    }

    static func glassTint(for presentation: HUDPresentation) -> Color {
        presentation.value == nil ? .orange.opacity(0.045) : .primary.opacity(0.035)
    }
}
