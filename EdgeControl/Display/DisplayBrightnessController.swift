import Foundation

@MainActor
final class BrightnessControlSession {
    let initialValue: Double
    private let backend: BrightnessBackend
    private var lastWrittenValue: Float? = nil

    fileprivate init(backend: BrightnessBackend) throws {
        self.backend = backend
        let value = try backend.getBrightness()
        guard value.isFinite else {
            throw ControlError.readFailed("The display returned an invalid brightness value.")
        }
        initialValue = min(1, max(0, value))
    }

    func setBrightness(_ value: Double) throws {
        guard value.isFinite else {
            throw ControlError.writeFailed("Brightness must be a finite value.")
        }
        // DisplayServices consumes Float. Deduplicate only successful writes,
        // scoped to this gesture; a new gesture must read the system again.
        let target = Float(min(1, max(0, value)))
        guard target != lastWrittenValue else { return }
        try backend.setBrightness(Double(target))
        lastWrittenValue = target
    }
}

@MainActor
final class DisplayBrightnessController {
    private let builtIn: BrightnessBackend
    private let external: ExternalBrightnessBackend

    init(
        builtIn: BrightnessBackend = BuiltInDisplayBackend(),
        external: ExternalBrightnessBackend = ExternalDDCBackend()
    ) {
        self.builtIn = builtIn
        self.external = external
    }

    var isAvailable: Bool {
        builtIn.isAvailable || (external.enabled && external.isAvailable)
    }

    func refresh() {
        builtIn.refresh()
        external.refresh()
    }

    func setExternalDDCEnabled(_ enabled: Bool) {
        external.enabled = enabled
        external.refresh()
    }

    func beginSession() throws -> BrightnessControlSession {
        // Recover from a transiently stale/empty CoreGraphics enumeration at
        // gesture start before considering the optional DDC fallback.
        if !builtIn.isAvailable {
            builtIn.refresh()
        }
        if builtIn.isAvailable {
            #if EDGE_DEBUG_LOGGING
            print("[EdgeControl][Brightness] backend=built-in")
            #endif
            return try BrightnessControlSession(backend: builtIn)
        }

        // Never invoke DDC merely because the built-in backend was briefly
        // unavailable. The user must opt in and a real connection must exist.
        guard external.enabled else {
            throw ControlError.unavailable(
                "Built-in display brightness control is temporarily unavailable."
            )
        }
        if !external.isAvailable {
            external.refresh()
        }
        guard external.isAvailable else {
            throw ControlError.unavailable(
                "Built-in display brightness control is temporarily unavailable."
            )
        }
        #if EDGE_DEBUG_LOGGING
        print("[EdgeControl][Brightness] backend=external-ddc")
        #endif
        return try BrightnessControlSession(backend: external)
    }
}
