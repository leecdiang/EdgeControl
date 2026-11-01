import XCTest
@testable import EdgeControl

@MainActor
final class RecordingHapticBackend: HapticBackend {
    var patterns: [HapticPulsePattern] = []
    var pulses: Int { patterns.count }
    var isAvailable = true
    func pulse(_ pattern: HapticPulsePattern) { patterns.append(pattern) }
    func reset() {}
}

@MainActor
final class HapticEngineTests: XCTestCase {
    private func makeEngine(
        _ backend: RecordingHapticBackend,
        now: @escaping () -> TimeInterval
    ) -> HapticEngine {
        HapticEngine(
            publicBackend: backend,
            privateBackend: RecordingHapticBackend(),
            now: now,
            automaticallySchedule: false
        )
    }

    func testDetentPulsesAreRateLimitedByCooldown() {
        let backend = RecordingHapticBackend()
        var time: TimeInterval = 0
        let engine = makeEngine(backend, now: { time })
        engine.pulseCooldown = 0.12 // explicit, independent of the tuned default

        engine.activationTick(initialValue: 0.0) // t=0, always fires
        XCTAssertEqual(backend.pulses, 1)

        // Sweep 0.05 -> 0.95 in 19 steps of 10ms. Buckets cross every other step;
        // the cooldown (120ms) allows exactly one detent pulse, at t=0.12.
        var value = 0.05
        for _ in 1...19 {
            time += 0.01
            engine.valueChanged(to: value)
            value += 0.05
        }
        XCTAssertEqual(backend.pulses, 2, "only one detent pulse within the 120ms cooldown")

        // After the cooldown elapses, a fresh bucket crossing pulses again.
        // (value 1.0 cannot cross a boundary: bucket 19's upper threshold is
        // beyond the clamped range, so the test re-primes from 0.5.)
        engine.endGesture()
        engine.valueChanged(to: 0.5) // primes tracker at bucket 10, no emit
        time += 0.5
        engine.valueChanged(to: 0.6) // crosses bucket 10's upper threshold
        XCTAssertEqual(backend.pulses, 3)
    }

    func testActivationTickAlwaysFiresEvenDuringCooldown() {
        let backend = RecordingHapticBackend()
        var time: TimeInterval = 10
        let engine = makeEngine(backend, now: { time })
        engine.pulseCooldown = 0.12

        engine.valueChanged(to: 0.1) // primes tracker, no emit
        engine.valueChanged(to: 0.2) // bucket crossing -> pulse at t=10
        XCTAssertEqual(backend.pulses, 1)

        time += 0.03 // still inside the 120ms cooldown
        engine.activationTick(initialValue: 0.2) // force: true ignores cooldown
        XCTAssertEqual(backend.pulses, 2)
    }

    func testStandardPreservesOriginalAlignmentPatternAndTwoPercentDetents() {
        let backend = RecordingHapticBackend()
        var time: TimeInterval = 0
        let engine = makeEngine(backend, now: { time })

        engine.activationTick(initialValue: 0.0, strength: .standard)
        time += 0.05
        engine.valueChanged(to: 0.03, strength: .standard)

        XCTAssertEqual(backend.patterns, [.alignment, .alignment])
    }

    func testLightUsesFourPercentDetentsAndStrongUsesFirmPattern() {
        let lightBackend = RecordingHapticBackend()
        var time: TimeInterval = 0
        let lightEngine = makeEngine(lightBackend, now: { time })

        lightEngine.activationTick(initialValue: 0.0, strength: .light)
        time += 0.05
        lightEngine.valueChanged(to: 0.03, strength: .light)
        XCTAssertEqual(lightBackend.patterns, [.alignment], "3% must remain below the Light detent threshold")
        time += 0.05
        lightEngine.valueChanged(to: 0.05, strength: .light)
        XCTAssertEqual(lightBackend.patterns, [.alignment, .alignment])

        let strongBackend = RecordingHapticBackend()
        let strongEngine = makeEngine(strongBackend, now: { time })
        strongEngine.activationTick(initialValue: 0.0, strength: .strong)
        XCTAssertEqual(strongBackend.patterns, [.firm])
    }

    func testStrongProfileEmitsSecondaryFirmPulse() {
        let backend = RecordingHapticBackend()
        let engine = makeEngine(backend, now: { 0 })
        engine.activationTick(initialValue: 0.0, strength: .strong)

        // The first pulse is synchronous; the second firm pulse arrives a few
        // milliseconds later to make Strong clearly heavier than Standard.
        let expectation = expectation(description: "secondary firm pulse")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(backend.patterns, [.firm, .firm])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testEndingGestureCancelsPendingStrongSecondaryPulse() {
        let backend = RecordingHapticBackend()
        let engine = makeEngine(backend, now: { 0 })
        engine.activationTick(initialValue: 0.0, strength: .strong)
        engine.endGesture()

        let expectation = expectation(description: "no pulse after gesture ends")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(backend.patterns, [.firm])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testWakeResetCancelsPendingStrongSecondaryPulse() {
        let backend = RecordingHapticBackend()
        let engine = makeEngine(backend, now: { 0 })
        engine.activationTick(initialValue: 0.0, strength: .strong)
        engine.resetAfterWake()

        let expectation = expectation(description: "no pulse after wake reset")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(backend.patterns, [.firm])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }
    func testCrossingSuppressedByCooldownRemainsEligibleOnNextMovement() {
        let backend = RecordingHapticBackend()
        var time: TimeInterval = 0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.010
        engine.valueChanged(to: 0.55)
        XCTAssertEqual(backend.pulses, 1)
        time = 0.040
        engine.valueChanged(to: 0.551)
        XCTAssertEqual(backend.pulses, 2, "the suppressed crossing must not consume its detent")
        time = 0.080
        engine.valueChanged(to: 0.552)
        XCTAssertEqual(backend.pulses, 2, "the successful request must commit the new bucket")
    }

    func testReturningToOriginalBucketDoesNotReplaySuppressedCrossing() {
        let backend = RecordingHapticBackend()
        var time: TimeInterval = 0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.010
        engine.valueChanged(to: 0.55)
        time = 0.040
        engine.valueChanged(to: 0.501)
        XCTAssertEqual(backend.pulses, 1)
    }

    func testGestureEndDiscardsSuppressedCrossing() {
        let backend = RecordingHapticBackend()
        var time: TimeInterval = 0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.010
        engine.valueChanged(to: 0.55)
        engine.endGesture()
        time = 0.040
        engine.valueChanged(to: 0.551) // A reset tracker only primes itself.
        XCTAssertEqual(backend.pulses, 1)
        engine.activationTick(initialValue: 0.551)
        XCTAssertEqual(backend.pulses, 2)
    }

    func testUnavailableBackendDoesNotConsumeDetentOrCooldown() {
        let backend = RecordingHapticBackend()
        let fallback = RecordingHapticBackend()
        fallback.isAvailable = false
        var time: TimeInterval = 0
        let engine = HapticEngine(publicBackend: backend, privateBackend: fallback, now: { time })
        engine.activationTick(initialValue: 0.5)
        backend.isAvailable = false
        time = 0.040
        engine.valueChanged(to: 0.55)
        backend.isAvailable = true
        time = 0.041
        engine.valueChanged(to: 0.551)
        XCTAssertEqual(backend.pulses, 2, "unavailable hardware must not advance the bucket or cooldown")
    }

    func testSlowContinuousMovementGetsFeedbackInsideOneDetent() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.121
        engine.valueChanged(to: 0.506)
        time = 0.242
        engine.valueChanged(to: 0.512)
        XCTAssertEqual(backend.pulses, 3)
    }

    func testLightContinuityRequiresMoreProgressAndTime() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5, strength: .light)
        time = 0.13
        engine.valueChanged(to: 0.511, strength: .light)
        XCTAssertEqual(backend.pulses, 1)
        time = 0.181
        engine.valueChanged(to: 0.512, strength: .light)
        XCTAssertEqual(backend.pulses, 2)
    }

    func testLongStationaryHoldAndTinyJitterDoNotGenerateContinuityPulses() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.51)
        for index in 1...100 {
            time = Double(index) * 0.05
            engine.valueChanged(to: index.isMultiple(of: 2) ? 0.511 : 0.509)
            engine.flushPendingFeedback()
        }
        XCTAssertEqual(backend.pulses, 1)
    }

    func testCooldownRequestFlushesWithoutAnotherMovement() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.01
        engine.valueChanged(to: 0.55)
        time = 0.031
        engine.flushPendingFeedback()
        XCTAssertEqual(backend.pulses, 2)
        engine.flushPendingFeedback()
        XCTAssertEqual(backend.pulses, 2)
    }

    func testPendingRequestsCoalesceToLatestValue() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        for index in 1...20 {
            time = Double(index) * 0.001
            engine.valueChanged(to: 0.55 + Double(index) * 0.01)
        }
        time = 0.031
        engine.flushPendingFeedback()
        XCTAssertEqual(backend.pulses, 2)
        time = 0.07
        engine.valueChanged(to: 0.751)
        XCTAssertEqual(backend.pulses, 2, "latest position, not the first pending position, must commit")
    }

    func testReturnInsideDetentCancelsPendingTimer() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.01; engine.valueChanged(to: 0.55)
        time = 0.02; engine.valueChanged(to: 0.501)
        time = 0.04; engine.flushPendingFeedback()
        XCTAssertEqual(backend.pulses, 1)
    }

    func testGestureEndAndWakeDiscardPendingTimer() {
        for wake in [false, true] {
            let backend = RecordingHapticBackend()
            var time = 0.0
            let engine = makeEngine(backend, now: { time })
            engine.activationTick(initialValue: 0.5)
            time = 0.01; engine.valueChanged(to: 0.55)
            if wake { engine.resetAfterWake() } else { engine.endGesture() }
            time = 0.04; engine.flushPendingFeedback()
            XCTAssertEqual(backend.pulses, 1)
        }
    }

    func testBlockedMainThreadDoesNotReplayStalePendingFeedback() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.01; engine.valueChanged(to: 0.55)
        time = 0.2; engine.flushPendingFeedback()
        XCTAssertEqual(backend.pulses, 1)
        time = 0.21; engine.valueChanged(to: 0.551)
        XCTAssertEqual(backend.pulses, 2)
    }

    func testBothEndpointsPulseOnceEvenWithoutBucketCrossing() {
        for pair in [(0.98, 1.0), (0.01, 0.0)] {
            let backend = RecordingHapticBackend()
            var time = 0.0
            let engine = makeEngine(backend, now: { time })
            engine.activationTick(initialValue: pair.0)
            time = 0.04; engine.valueChanged(to: pair.1)
            time = 0.2; engine.valueChanged(to: pair.1)
            XCTAssertEqual(backend.pulses, 2)
        }
    }

    func testInvalidValuesCannotCrashOrConsumeFeedback() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        for value in [Double.nan, .infinity, -.infinity] {
            engine.valueChanged(to: value)
            engine.activationTick(initialValue: value)
        }
        XCTAssertEqual(backend.pulses, 1)
        time = 0.04; engine.valueChanged(to: 0.55)
        XCTAssertEqual(backend.pulses, 2)
    }

    func testNewActivationInvalidatesPreviousPendingFeedback() {
        let backend = RecordingHapticBackend()
        var time = 0.0
        let engine = makeEngine(backend, now: { time })
        engine.activationTick(initialValue: 0.5)
        time = 0.01; engine.valueChanged(to: 0.55)
        time = 0.02; engine.activationTick(initialValue: 0.3)
        time = 0.04; engine.flushPendingFeedback()
        XCTAssertEqual(backend.pulses, 2)
    }

    func testActualSchedulerDeliversOnePendingPulse() async throws {
        let backend = RecordingHapticBackend()
        let engine = HapticEngine(publicBackend: backend,
                                  privateBackend: RecordingHapticBackend())
        engine.pulseCooldown = 0.05
        engine.activationTick(initialValue: 0.5)
        engine.valueChanged(to: 0.55)
        XCTAssertEqual(backend.pulses, 1)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(backend.pulses, 2)
        engine.endGesture()
    }

    func testActualSchedulerDoesNotPulseAfterRelease() async throws {
        let backend = RecordingHapticBackend()
        let engine = HapticEngine(publicBackend: backend,
                                  privateBackend: RecordingHapticBackend())
        engine.activationTick(initialValue: 0.5)
        engine.valueChanged(to: 0.55)
        engine.endGesture()
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(backend.pulses, 1)
    }

}
