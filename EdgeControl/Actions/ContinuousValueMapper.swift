import Foundation

struct ContinuousValueMapper: Sendable {
    var baseGain: Double = 1.15

    func targetValue(initialValue: Double, deltaY: Double, sensitivity: Double) -> Double {
        min(1.0, max(0.0, initialValue + deltaY * baseGain * sensitivity))
    }
}

