import Foundation

@MainActor
final class DisplayBrightnessController {
    private let builtIn: BuiltInDisplayBackend
    private let external: ExternalDDCBackend

    init(
        builtIn: BuiltInDisplayBackend = BuiltInDisplayBackend(),
        external: ExternalDDCBackend = ExternalDDCBackend()
    ) {
        self.builtIn = builtIn
        self.external = external
    }

    var isAvailable: Bool {
        builtIn.isAvailable || external.isAvailable
    }

    func refresh() {
        builtIn.refresh()
        external.refresh()
    }

    func setExternalDDCEnabled(_ enabled: Bool) {
        external.enabled = enabled
        external.refresh()
    }

    func getBrightness() throws -> Double {
        if builtIn.isAvailable {
            return try builtIn.getBrightness()
        }
        return try external.getBrightness()
    }

    func setBrightness(_ value: Double) throws {
        if builtIn.isAvailable {
            try builtIn.setBrightness(value)
        } else {
            try external.setBrightness(value)
        }
    }
}

