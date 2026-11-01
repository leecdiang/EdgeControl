import AppKit
import Foundation
import OSLog

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
    private var pendingPulseTask: Task<Void, Never>?
    private var pendingGeneration: UInt64 = 0
    private var pendingValue: Double?
    private var lastFeedbackValue: Double?
    private var lastObservedValue: Double?
    private var lastMovementTime: TimeInterval = -.infinity
    private let automaticallySchedule: Bool
    private let logger = Logger(subsystem: "org.edgecontrol.EdgeControl", category: "Haptics")
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
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        automaticallySchedule: Bool = true
    ) {
        self.publicBackend = publicBackend
        self.privateBackend = privateBackend
        self.now = now
        self.automaticallySchedule = automaticallySchedule
    }

    func activationTick(initialValue: Double, strength: HapticStrength = .standard) {
        guard initialValue.isFinite else { return }
        endGesture()
        configureDetents(for: strength)
        let value = min(1, max(0, initialValue))
        detents.begin(at: value)
        lastObservedValue = value
        lastFeedbackValue = value
        lastMovementTime = now()
        _ = pulse(force: true, strength: strength)
    }

    func valueChanged(to value: Double, strength: HapticStrength = .standard) {
        guard value.isFinite else { return }
        configureDetents(for: strength)
        let value = min(1, max(0, value))
        if lastObservedValue != value {
            lastMovementTime = now()
            lastObservedValue = value
        }
        guard lastFeedbackValue != nil else {
            detents.begin(at: value)
            lastFeedbackValue = value
            return
        }
        requestFeedback(for: value)
    }

    private func requestFeedback(for value: Double) {
        var candidate = detents
        let crossing = candidate.shouldEmit(for: value)
        let progress = abs(value - (lastFeedbackValue ?? value))
        let endpoint = (value == 0 || value == 1) && progress > 0
        // Slow, meaningful adjustment should still feel alive between detents.
        // Net displacement (not accumulated jitter) must reach a quarter detent.
        let continuity = progress >= activeStrength.detentInterval / 4 &&
            now() - lastPulseTime >= (activeStrength == .light ? 0.180 : 0.120)
        guard crossing || endpoint || continuity else {
            cancelPendingPulse()
            logger.debug("suppressed: below detent/progress threshold")
            return
        }
        if now() - lastPulseTime < pulseCooldown {
            pendingValue = value
            schedulePendingPulse()
            logger.debug("deferred: cooldown")
            return
        }
        cancelPendingPulse()
        guard pulse(force: false, strength: activeStrength) else { return }
        detents = candidate
        if endpoint || continuity { detents.begin(at: value) }
        lastFeedbackValue = value
        let reason = endpoint ? "endpoint" : (crossing ? "detent" : "continuous movement")
        logger.debug("requested: \(reason, privacy: .public)")
    }

    private func schedulePendingPulse() {
        guard automaticallySchedule, pendingPulseTask == nil else { return }
        let generation = pendingGeneration
        let delay = max(0.001, pulseCooldown - (now() - lastPulseTime))
        pendingPulseTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
            guard let self, self.pendingGeneration == generation else { return }
            self.pendingPulseTask = nil
            self.flushPendingFeedback()
        }
    }

    /// One coalesced request, never a replay queue. Internal for virtual-clock tests.
    func flushPendingFeedback() {
        guard let value = pendingValue else { return }
        let age = now() - lastMovementTime
        guard age.isFinite, age >= 0, age <= 0.100 else {
            cancelPendingPulse()
            logger.debug("discarded: stale pending feedback")
            return
        }
        requestFeedback(for: value)
    }

    private func cancelPendingPulse() {
        pendingGeneration &+= 1
        pendingPulseTask?.cancel()
        pendingPulseTask = nil
        pendingValue = nil
    }

    func endGesture() {
        cancelPendingPulse()
        cancelSecondaryPulse()
        detents.reset()
        lastFeedbackValue = nil
        lastObservedValue = nil
        lastMovementTime = -.infinity
    }

    func resetAfterWake() {
        endGesture()
        publicBackend.reset()
        privateBackend.reset()
        activeStrength = .standard
        lastPulseTime = -.infinity
    }

    private func configureDetents(for strength: HapticStrength) {
        guard strength != activeStrength || detents.interval != strength.detentInterval else {
            return
        }
        cancelPendingPulse()
        cancelSecondaryPulse()
        activeStrength = strength
        detents = DetentTracker(interval: strength.detentInterval)
        if let lastFeedbackValue { detents.begin(at: lastFeedbackValue) }
    }

    @discardableResult
    private func pulse(force: Bool, strength: HapticStrength) -> Bool {
        let nowValue = now()
        if !force && nowValue - lastPulseTime < pulseCooldown {
            return false
        }
        let pattern: HapticPulsePattern = strength == .strong ? .firm : .alignment
        guard let backend = selectedBackend() else {
            logger.debug("suppressed: backend unavailable")
            return false
        }
        // AppKit returns no delivery acknowledgement. This records a request,
        // not proof that the actuator physically vibrated.
        backend.pulse(pattern)
        logger.debug("backend request; forced=\(force)")
        lastPulseTime = nowValue
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
                      self.now() - nowValue <= 0.042,
                      let currentBackend = self.selectedBackend() else {
                    return
                }
                currentBackend.pulse(pattern)
                self.lastPulseTime = self.now()
                self.logger.debug("backend request: strong secondary")
                self.secondaryPulseTask = nil
            }
        }
        return true
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
