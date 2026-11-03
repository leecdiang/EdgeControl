import AppKit
import SwiftUI

/// A shared two-edge template symbol, drawn in points for every backing scale.
/// Keeping the menu bar and popover on the same image avoids mismatched branding.
@MainActor
enum EdgeControlSymbol {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            for (x, thumbY) in [(CGFloat(5), CGFloat(11)), (CGFloat(13), CGFloat(7))] {
                path.move(to: NSPoint(x: x, y: 2.5))
                path.line(to: NSPoint(x: x, y: thumbY - 2.25))
                path.move(to: NSPoint(x: x, y: thumbY + 2.25))
                path.line(to: NSPoint(x: x, y: 15.5))
                path.appendOval(in: NSRect(x: x - 2.25, y: thumbY - 2.25, width: 4.5, height: 4.5))
            }
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "EdgeControl"
        return image
    }()
}

/// Shared visual constants for the small, translucent surfaces in EdgeControl.
enum EdgeUITheme {
    static let controlAccent = Color(nsColor: .controlAccentColor)

    // Stabilizes behind-window vibrancy while preserving translucency.
    static let settingsNeutralScrimOpacity: Double = 0.24
    static let menuNeutralScrimOpacity: Double = 0.18
    // Keeps the HUD glass from inheriting large background color swings.
    static let hudNeutralVeilOpacity: Double = 0.64
}

/// Liquid Glass belongs to navigation and controls; content keeps a quieter
/// material. Keep macOS 13–15 and Reduce Transparency fully supported.
struct EdgeNavigationGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        } else if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

struct EdgePreviewButtonStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
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
