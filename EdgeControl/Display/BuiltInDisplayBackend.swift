import CoreGraphics
import Foundation

@MainActor
final class BuiltInDisplayBackend: BrightnessBackend {
    private(set) var displayID: CGDirectDisplayID?

    var isAvailable: Bool {
        displayID != nil && ec_display_services_is_available()
    }

    init() {
        refresh()
    }

    func refresh() {
        displayID = Self.activeDisplayIDs().first(where: { CGDisplayIsBuiltin($0) != 0 })
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

    private static func activeDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            return []
        }
        return Array(displays.prefix(Int(count)))
    }
}

