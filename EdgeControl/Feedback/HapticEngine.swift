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
    private var detents = DetentTracker(interval: 0.02)
    var preference: BackendPreference = .publicAPI

    /// Minimum interval between detent pulses. 30ms lets a full-range swipe at
    /// normal speed render most 2% steps as discrete ticks (~33Hz cap,
    /// enough to read as individual detents), while still clipping the >33Hz
    /// buzz of very fast flicks. The activation tick always fires.
    var pulseCooldown: TimeInterval = 0.03
    private var lastPulseTime: TimeInterval = -.infinity
    private let now: () -> TimeInterval

    init(
        publicBackend: HapticBackend = PublicHapticBackend(),
        privateBackend: HapticBackend = TrackpadActuatorBackend(),
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.publicBackend = publicBackend
        self.privateBackend = privateBackend
        self.now = now
    }

    func activationTick(initialValue: Double) {
        detents.begin(at: initialValue)
        pulse(force: true)
    }

    func valueChanged(to value: Double) {
        if detents.shouldEmit(for: value) {
            pulse(force: false)
        }
    }

    func endGesture() {
        detents.reset()
    }

    func resetAfterWake() {
        publicBackend.reset()
        privateBackend.reset()
        detents.reset()
        lastPulseTime = -.infinity
    }

    private func pulse(force: Bool) {
        let nowValue = now()
        if !force && nowValue - lastPulseTime < pulseCooldown {
            return
        }
        lastPulseTime = nowValue
        selectedBackend()?.pulse()
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

