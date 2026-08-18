import CoreGraphics
import Foundation

@MainActor
final class ExternalDDCBackend: ExternalBrightnessBackend {
    private final class Connection {
        let displayID: CGDirectDisplayID
        let handle: OpaquePointer
        var maximum: UInt16?

        init(displayID: CGDirectDisplayID, handle: OpaquePointer) {
            self.displayID = displayID
            self.handle = handle
        }

        deinit {
            ec_ddc_close(handle)
        }
    }

    private var connections: [Connection] = []
    private var selectedConnectionIndex: Int?

    /// V1 experimental gate: DDC/CI over I2C is unvalidated on other hardware,
    /// so it is disabled unless explicitly enabled (default false).
    var enabled = false

    var isAvailable: Bool { !connections.isEmpty }

    init() {
        refresh()
    }

    func refresh() {
        selectedConnectionIndex = nil
        connections.removeAll()
        guard enabled else { return }

        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return
        }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            return
        }

        for display in displays where CGDisplayIsBuiltin(display) == 0 {
            if let handle = ec_ddc_open(display) {
                connections.append(Connection(displayID: display, handle: handle))
            }
        }
    }

    func getBrightness() throws -> Double {
        selectedConnectionIndex = nil
        for (index, connection) in connections.enumerated() {
            var current: UInt16 = 0
            var maximum: UInt16 = 0
            if ec_ddc_get_vcp10(connection.handle, &current, &maximum), maximum > 0 {
                connection.maximum = maximum
                selectedConnectionIndex = index
                return min(1.0, max(0.0, Double(current) / Double(maximum)))
            }
        }
        throw ControlError.unavailable("No DDC-capable external display responded to VCP 0x10.")
    }

    func setBrightness(_ value: Double) throws {
        guard let index = Self.resolvedConnectionIndex(
            lastResponsiveIndex: selectedConnectionIndex,
            connectionCount: connections.count
        ) else {
            throw ControlError.unavailable("No external DDC display is available.")
        }
        let connection = connections[index]

        if connection.maximum == nil {
            var current: UInt16 = 0
            var maximum: UInt16 = 0
            guard ec_ddc_get_vcp10(connection.handle, &current, &maximum), maximum > 0 else {
                throw ControlError.readFailed("The external display did not return its DDC brightness range.")
            }
            connection.maximum = maximum
        }

        guard let maximum = connection.maximum else {
            throw ControlError.readFailed("The external display brightness range is unknown.")
        }
        let rawValue = UInt16((Double(maximum) * min(1.0, max(0.0, value))).rounded())
        guard ec_ddc_set_vcp10(connection.handle, rawValue) else {
            throw ControlError.writeFailed("The external display rejected DDC/CI VCP 0x10.")
        }
    }

    /// A brightness session first reads a responsive monitor, then writes the
    /// same connection. Falling back to index zero preserves direct-write
    /// behavior for callers that have not performed an initial read.
    static func resolvedConnectionIndex(
        lastResponsiveIndex: Int?,
        connectionCount: Int
    ) -> Int? {
        guard connectionCount > 0 else { return nil }
        if let lastResponsiveIndex,
           lastResponsiveIndex >= 0,
           lastResponsiveIndex < connectionCount {
            return lastResponsiveIndex
        }
        return 0
    }
}
