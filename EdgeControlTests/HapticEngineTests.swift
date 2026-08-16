import XCTest
@testable import EdgeControl

@MainActor
final class RecordingHapticBackend: HapticBackend {
    var pulses = 0
    var isAvailable: Bool { true }
    func pulse() { pulses += 1 }
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
            now: now
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
}
