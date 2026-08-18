import AppKit
import Foundation

@MainActor
protocol HapticBackend: AnyObject {
    var isAvailable: Bool { get }
    func pulse(_ pattern: HapticPulsePattern)
    func reset()
}

enum HapticPulsePattern: Sendable, Equatable {
    case alignment
    case firm
}

@MainActor
final class PublicHapticBackend: HapticBackend {
    var isAvailable: Bool { true }

    func pulse(_ pattern: HapticPulsePattern) {
        let systemPattern: NSHapticFeedbackManager.FeedbackPattern
        switch pattern {
        case .alignment:
            systemPattern = .alignment
        case .firm:
            systemPattern = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(systemPattern, performanceTime: .now)
    }

    func reset() {}
}

@MainActor
final class TrackpadActuatorBackend: HapticBackend {
    var isAvailable: Bool { ec_mt_private_haptic_is_available() }

    func pulse(_ pattern: HapticPulsePattern) {
        // Pattern 1 is only a placeholder behind an explicit local opt-in.
        // LOCAL_VALIDATION_REQUIRED before this backend is enabled in release.
        // The unvalidated private backend intentionally ignores strength; do
        // not guess undocumented pattern numbers.
        _ = pattern
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
    private var activeStrength: HapticStrength = .standard
    private var secondaryPulseTask: Task<Void, Never>?
    private var pulseGeneration: UInt64 = 0
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

    func activationTick(initialValue: Double, strength: HapticStrength = .standard) {
        configureDetents(for: strength)
        detents.begin(at: initialValue)
        pulse(force: true, strength: strength)
    }

    func valueChanged(to value: Double, strength: HapticStrength = .standard) {
        configureDetents(for: strength)
        if detents.shouldEmit(for: value) {
            pulse(force: false, strength: strength)
        }
    }

    func endGesture() {
        cancelSecondaryPulse()
        detents.reset()
    }

    func resetAfterWake() {
        cancelSecondaryPulse()
        publicBackend.reset()
        privateBackend.reset()
        detents.reset()
        activeStrength = .standard
        lastPulseTime = -.infinity
    }

    private func configureDetents(for strength: HapticStrength) {
        guard strength != activeStrength || detents.interval != strength.detentInterval else {
            return
        }
        activeStrength = strength
        detents = DetentTracker(interval: strength.detentInterval)
    }

    private func pulse(force: Bool, strength: HapticStrength) {
        let nowValue = now()
        if !force && nowValue - lastPulseTime < pulseCooldown {
            return
        }
        lastPulseTime = nowValue
        let pattern: HapticPulsePattern = strength == .strong ? .firm : .alignment
        guard let backend = selectedBackend() else { return }
        backend.pulse(pattern)
        if strength == .strong {
            // The public AppKit API has no amplitude knob and .generic feels
            // close to .alignment, so Strong doubles up: a second firm pulse a
            // few milliseconds later reads as a heavier tick, not a buzz.
            cancelSecondaryPulse()
            let generation = pulseGeneration
            secondaryPulseTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 12_000_000)
                } catch {
                    return
                }
                guard let self,
                      self.pulseGeneration == generation,
                      let currentBackend = self.selectedBackend() else {
                    return
                }
                currentBackend.pulse(pattern)
                self.secondaryPulseTask = nil
            }
        }
    }

    private func cancelSecondaryPulse() {
        pulseGeneration &+= 1
        secondaryPulseTask?.cancel()
        secondaryPulseTask = nil
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
