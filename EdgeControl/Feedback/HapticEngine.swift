import AppKit
import Foundation

@MainActor
protocol HapticBackend: AnyObject {
    var isAvailable: Bool { get }
    func pulse()
    func reset()
}

@MainActor
final class PublicHapticBackend: HapticBackend {
    var isAvailable: Bool { true }

    func pulse() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    func reset() {}
}

@MainActor
final class TrackpadActuatorBackend: HapticBackend {
    var isAvailable: Bool { ec_mt_private_haptic_is_available() }

    func pulse() {
        // Pattern 1 is only a placeholder behind an explicit local opt-in.
        // LOCAL_VALIDATION_REQUIRED before this backend is enabled in release.
        _ = ec_mt_private_haptic_pulse(1)
    }

    func reset() {
        ec_mt_private_haptic_reset()
    }
}

@MainActor
final class HapticEngine {
    enum BackendPreference {
        case publicAPI
        case privateActuator
    }

    private let publicBackend: HapticBackend
    private let privateBackend: HapticBackend
    private var detents = DetentTracker()
    var preference: BackendPreference = .publicAPI

    init(
        publicBackend: HapticBackend = PublicHapticBackend(),
        privateBackend: HapticBackend = TrackpadActuatorBackend()
    ) {
        self.publicBackend = publicBackend
        self.privateBackend = privateBackend
    }

    func activationTick(initialValue: Double) {
        detents.begin(at: initialValue)
        selectedBackend()?.pulse()
    }

    func valueChanged(to value: Double) {
        if detents.shouldEmit(for: value) {
            selectedBackend()?.pulse()
        }
    }

    func endGesture() {
        detents.reset()
    }

    func resetAfterWake() {
        publicBackend.reset()
        privateBackend.reset()
        detents.reset()
    }

    private func selectedBackend() -> HapticBackend? {
        switch preference {
        case .publicAPI:
            return publicBackend.isAvailable ? publicBackend : (privateBackend.isAvailable ? privateBackend : nil)
        case .privateActuator:
            return privateBackend.isAvailable ? privateBackend : (publicBackend.isAvailable ? publicBackend : nil)
        }
    }
}

