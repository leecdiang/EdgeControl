import CoreGraphics
import Foundation

@MainActor
final class BuiltInDisplayBackend: BrightnessBackend {
    typealias ActiveDisplayProvider = () -> [CGDirectDisplayID]?
    typealias BuiltInDetector = (CGDirectDisplayID) -> Bool

    private(set) var displayID: CGDirectDisplayID?
    private let activeDisplayProvider: ActiveDisplayProvider
    private let builtInDetector: BuiltInDetector

    var isAvailable: Bool {
        displayID != nil && ec_display_services_is_available()
    }

    init() {
        activeDisplayProvider = Self.activeDisplayIDs
        builtInDetector = { CGDisplayIsBuiltin($0) != 0 }
        refresh()
    }

    init(
        activeDisplayProvider: @escaping ActiveDisplayProvider,
        builtInDetector: @escaping BuiltInDetector
    ) {
        self.activeDisplayProvider = activeDisplayProvider
        self.builtInDetector = builtInDetector
        refresh()
    }

    func refresh() {
        // A display-change or wake notification can arrive before CoreGraphics
        // has a stable active-display list. Preserve the last known ID when the
        // query itself fails; a successful list with no built-in display still
        // clears it correctly (for example, clamshell mode).
        guard let activeDisplays = activeDisplayProvider() else { return }
        displayID = activeDisplays.first(where: builtInDetector)
    }

    func getBrightness() throws -> Double {
        guard let displayID, ec_display_services_is_available() else {
            throw ControlError.unavailable("Built-in display brightness control is unavailable.")
        }
        var value: Float = 0
        guard ec_display_services_get_brightness(displayID, &value) else {
            throw ControlError.readFailed("Built-in display brightness could not be read.")
        }
        return min(1.0, max(0.0, Double(value)))
    }

    func setBrightness(_ value: Double) throws {
        guard let displayID, ec_display_services_is_available() else {
            throw ControlError.unavailable("Built-in display brightness control is unavailable.")
        }
        let clamped = Float(min(1.0, max(0.0, value)))
        guard ec_display_services_set_brightness(displayID, clamped) else {
            throw ControlError.writeFailed("Built-in display brightness could not be changed.")
        }
    }

    private static func activeDisplayIDs() -> [CGDirectDisplayID]? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return nil
        }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success, count > 0 else {
            return nil
        }
        return Array(displays.prefix(Int(count)))
    }
}
