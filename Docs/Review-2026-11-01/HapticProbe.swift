import Foundation
import AppKit
// Private backend is never selected in this audit. No hardware API is called.
func ec_mt_private_haptic_is_available() -> Bool { false }
func ec_mt_private_haptic_pulse(_ pattern: Int32) -> Bool { false }
func ec_mt_private_haptic_reset() {}
@MainActor final class ProbeBackend: HapticBackend {
    var count = 0
    var isAvailable: Bool { true }
    func pulse(_ pattern: HapticPulsePattern) { count += 1 }
    func reset() {}
}
@MainActor func audit() {
    let b = ProbeBackend()
    var time = 0.0
    let e = HapticEngine(publicBackend: b, privateBackend: b, now: { time })
    e.activationTick(initialValue: 0.5)
    print("activation pulse requests: \(b.count)")
    time = 0.010; e.valueChanged(to: 0.55)
    print("t=10ms value=.550, total requests: \(b.count)")
    time = 0.040; e.valueChanged(to: 0.551)
    print("t=40ms value=.551, total requests: \(b.count)")
    time = 0.080; e.valueChanged(to: 0.552)
    print("t=80ms value=.552, total requests: \(b.count)")
    assert(b.count == 2, "Suppressed crossing should fire on the next eligible movement")
    e.endGesture()
    time = 0.081; e.activationTick(initialValue: 0.552)
    assert(b.count == 3)
    print("next activation bypasses cooldown: requests=\(b.count)")
}
MainActor.assumeIsolated { audit() }
