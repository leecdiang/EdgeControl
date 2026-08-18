import Combine
import Foundation

enum AdjustmentSpeed: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case precise
    case standard
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .precise: return "Precise"
        case .standard: return "Standard"
        case .fast: return "Fast"
        }
    }

    var gainMultiplier: Double {
        switch self {
        case .precise: return 0.50
        case .standard: return 0.70
        case .fast: return 0.95
        }
    }

    static func migrated(fromLegacySensitivity sensitivity: Double) -> Self {
        guard sensitivity.isFinite else { return .standard }
        // Nearest preset by gain multiplier.
        if sensitivity < 0.600 { return .precise }
        if sensitivity < 0.825 { return .standard }
        return .fast
    }
}

enum FalseTouchProtection: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case strong
    case standard
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strong: return "Strong"
        case .standard: return "Standard"
        case .light: return "Light"
        }
    }

    var typingSuppressionInterval: TimeInterval {
        switch self {
        case .strong: return 0.600
        case .standard: return 0.350
        case .light: return 0.200
        }
    }

    var leftEntryStripWidth: Double {
        switch self {
        case .strong: return 0.006
        case .standard: return 0.008
        case .light: return 0.010
        }
    }

    var rightEntryStripWidth: Double {
        switch self {
        case .strong: return 0.012
        case .standard: return 0.015
        case .light: return 0.019
        }
    }

    var gestureConfiguration: GestureConfiguration {
        var configuration = GestureConfiguration.default
        configuration.leftEntryStripWidth = leftEntryStripWidth
        configuration.rightEntryStripWidth = rightEntryStripWidth
        return configuration
    }
}

enum HapticStrength: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case light
    case standard
    case strong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .standard: return "Standard"
        case .strong: return "Strong"
        }
    }

    /// AppKit does not expose trackpad amplitude. Keep Standard identical to
    /// the existing 2% alignment ticks, make Light less dense, and use the
    /// firmer public system pattern for Strong.
    var detentInterval: Double {
        switch self {
        case .light: return 0.04
        case .standard, .strong: return 0.02
        }
    }
}

enum HUDColorStyle: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case system
    case classic
    case aurora

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .classic: return "Classic"
        case .aurora: return "Aurora"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    enum Key {
        static let masterEnabled = "masterEnabled"
        static let volumeEnabled = "volumeEnabled"
        static let brightnessEnabled = "brightnessEnabled"
        static let leftEdgeAction = "leftEdgeAction"
        static let rightEdgeAction = "rightEdgeAction"
        static let hapticFeedback = "hapticFeedback"
        static let hapticStrength = "hapticStrength"
        static let showHUD = "showHUD"
        static let hudColorStyle = "hudColorStyle"
        // Read-only migration key from 1.5.0.
        static let colorfulHUD = "colorfulHUD"
        static let lowerHalfOnly = "lowerHalfOnly"
        static let trackpadPreference = "trackpadPreference"
        static let adjustmentSpeed = "adjustmentSpeed"
        static let falseTouchProtection = "falseTouchProtection"
        // Read-only migration key from 1.3.x and the first 1.4.0 draft.
        static let sensitivity = "sensitivity"
        static let launchAtLogin = "launchAtLogin"
        static let externalDDCEnabled = "externalDDCEnabled"
    }

    private let defaults: UserDefaults

    @Published var masterEnabled: Bool { didSet { defaults.set(masterEnabled, forKey: Key.masterEnabled) } }
    @Published var volumeEnabled: Bool { didSet { defaults.set(volumeEnabled, forKey: Key.volumeEnabled) } }
    @Published var brightnessEnabled: Bool { didSet { defaults.set(brightnessEnabled, forKey: Key.brightnessEnabled) } }
    @Published var leftEdgeAction: EdgeAction { didSet { defaults.set(leftEdgeAction.rawValue, forKey: Key.leftEdgeAction) } }
    @Published var rightEdgeAction: EdgeAction { didSet { defaults.set(rightEdgeAction.rawValue, forKey: Key.rightEdgeAction) } }
    @Published var hapticFeedback: Bool { didSet { defaults.set(hapticFeedback, forKey: Key.hapticFeedback) } }
    @Published var hapticStrength: HapticStrength { didSet { defaults.set(hapticStrength.rawValue, forKey: Key.hapticStrength) } }
    @Published var showHUD: Bool { didSet { defaults.set(showHUD, forKey: Key.showHUD) } }
    @Published var hudColorStyle: HUDColorStyle { didSet { defaults.set(hudColorStyle.rawValue, forKey: Key.hudColorStyle) } }
    @Published var lowerHalfOnly: Bool { didSet { defaults.set(lowerHalfOnly, forKey: Key.lowerHalfOnly) } }
    @Published var trackpadPreference: TrackpadPreference { didSet { defaults.set(trackpadPreference.rawValue, forKey: Key.trackpadPreference) } }
    @Published var adjustmentSpeed: AdjustmentSpeed { didSet { defaults.set(adjustmentSpeed.rawValue, forKey: Key.adjustmentSpeed) } }
    @Published var falseTouchProtection: FalseTouchProtection { didSet { defaults.set(falseTouchProtection.rawValue, forKey: Key.falseTouchProtection) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }
    @Published var externalDDCEnabled: Bool { didSet { defaults.set(externalDDCEnabled, forKey: Key.externalDDCEnabled) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Registration defaults are process-global and shared by every
        // AppSettings instance, so a key can look "stored" when it only exists
        // in the registration domain. Treat a value as persisted only when it
        // differs from the injected registration default.
        let registration = defaults.volatileDomain(forName: UserDefaults.registrationDomain)

        func persistedValue(_ key: String) -> Any? {
            guard let value = defaults.object(forKey: key) else { return nil }
            if let registered = registration[key],
               (registered as AnyObject).isEqual(value as AnyObject) {
                return nil
            }
            return value
        }

        let storedAdjustmentSpeed = persistedValue(Key.adjustmentSpeed) as? String
        let storedFalseTouchProtection = persistedValue(Key.falseTouchProtection) as? String
        let storedHUDColorStyle = persistedValue(Key.hudColorStyle) as? String
        let legacyColorfulHUD: Bool? = persistedValue(Key.colorfulHUD) == nil
            ? nil
            : defaults.bool(forKey: Key.colorfulHUD)
        let legacySensitivity: Double? = persistedValue(Key.sensitivity) == nil
            ? nil
            : defaults.double(forKey: Key.sensitivity)

        defaults.register(defaults: [
            Key.masterEnabled: true,
            Key.volumeEnabled: true,
            Key.brightnessEnabled: true,
            Key.leftEdgeAction: EdgeAction.volume.rawValue,
            Key.rightEdgeAction: EdgeAction.brightness.rawValue,
            Key.hapticFeedback: true,
            Key.hapticStrength: HapticStrength.standard.rawValue,
            Key.showHUD: true,
            Key.hudColorStyle: HUDColorStyle.system.rawValue,
            Key.lowerHalfOnly: false,
            Key.trackpadPreference: TrackpadPreference.automatic.rawValue,
            Key.adjustmentSpeed: AdjustmentSpeed.standard.rawValue,
            Key.falseTouchProtection: FalseTouchProtection.standard.rawValue,
            Key.launchAtLogin: false,
            Key.externalDDCEnabled: false
        ])

        masterEnabled = defaults.bool(forKey: Key.masterEnabled)
        volumeEnabled = defaults.bool(forKey: Key.volumeEnabled)
        brightnessEnabled = defaults.bool(forKey: Key.brightnessEnabled)
        leftEdgeAction = EdgeAction(rawValue: defaults.string(forKey: Key.leftEdgeAction) ?? "") ?? .volume
        rightEdgeAction = EdgeAction(rawValue: defaults.string(forKey: Key.rightEdgeAction) ?? "") ?? .brightness
        hapticFeedback = defaults.bool(forKey: Key.hapticFeedback)
        hapticStrength = HapticStrength(
            rawValue: defaults.string(forKey: Key.hapticStrength) ?? ""
        ) ?? .standard
        showHUD = defaults.bool(forKey: Key.showHUD)
        if let storedHUDColorStyle {
            hudColorStyle = HUDColorStyle(rawValue: storedHUDColorStyle) ?? .system
            defaults.removeObject(forKey: Key.colorfulHUD)
        } else if let legacyColorfulHUD {
            let migratedStyle: HUDColorStyle = legacyColorfulHUD ? .classic : .system
            hudColorStyle = migratedStyle
            defaults.set(migratedStyle.rawValue, forKey: Key.hudColorStyle)
            defaults.removeObject(forKey: Key.colorfulHUD)
        } else {
            hudColorStyle = .system
        }
        lowerHalfOnly = defaults.bool(forKey: Key.lowerHalfOnly)
        trackpadPreference = TrackpadPreference(
            rawValue: defaults.string(forKey: Key.trackpadPreference) ?? ""
        ) ?? .automatic
        if let storedAdjustmentSpeed {
            adjustmentSpeed = AdjustmentSpeed(rawValue: storedAdjustmentSpeed) ?? .standard
        } else if let legacySensitivity {
            adjustmentSpeed = AdjustmentSpeed.migrated(
                fromLegacySensitivity: legacySensitivity
            )
        } else {
            adjustmentSpeed = .standard
        }
        falseTouchProtection = FalseTouchProtection(
            rawValue: storedFalseTouchProtection ?? ""
        ) ?? .standard
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        externalDDCEnabled = defaults.bool(forKey: Key.externalDDCEnabled)
    }
}
