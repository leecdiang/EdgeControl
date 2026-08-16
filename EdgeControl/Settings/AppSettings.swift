import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    enum Key {
        static let masterEnabled = "masterEnabled"
        static let volumeEnabled = "volumeEnabled"
        static let brightnessEnabled = "brightnessEnabled"
        static let leftEdgeAction = "leftEdgeAction"
        static let rightEdgeAction = "rightEdgeAction"
        static let hapticFeedback = "hapticFeedback"
        static let showHUD = "showHUD"
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
    @Published var showHUD: Bool { didSet { defaults.set(showHUD, forKey: Key.showHUD) } }
    @Published var sensitivity: Double { didSet { defaults.set(sensitivity, forKey: Key.sensitivity) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }
    @Published var externalDDCEnabled: Bool { didSet { defaults.set(externalDDCEnabled, forKey: Key.externalDDCEnabled) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.masterEnabled: true,
            Key.volumeEnabled: true,
            Key.brightnessEnabled: true,
            Key.leftEdgeAction: EdgeAction.volume.rawValue,
            Key.rightEdgeAction: EdgeAction.brightness.rawValue,
            Key.hapticFeedback: true,
            Key.showHUD: true,
            Key.sensitivity: 1.0,
            Key.launchAtLogin: false,
            Key.externalDDCEnabled: false
        ])

        masterEnabled = defaults.bool(forKey: Key.masterEnabled)
        volumeEnabled = defaults.bool(forKey: Key.volumeEnabled)
        brightnessEnabled = defaults.bool(forKey: Key.brightnessEnabled)
        leftEdgeAction = EdgeAction(rawValue: defaults.string(forKey: Key.leftEdgeAction) ?? "") ?? .volume
        rightEdgeAction = EdgeAction(rawValue: defaults.string(forKey: Key.rightEdgeAction) ?? "") ?? .brightness
        hapticFeedback = defaults.bool(forKey: Key.hapticFeedback)
        showHUD = defaults.bool(forKey: Key.showHUD)
        sensitivity = min(2.0, max(0.35, defaults.double(forKey: Key.sensitivity)))
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        externalDDCEnabled = defaults.bool(forKey: Key.externalDDCEnabled)
    }
}

