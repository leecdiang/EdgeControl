import Foundation

struct ContinuousValueMapper: Sendable {
    /// 2.0 tuned from live testing (macOS 26.5, MacBook Air): with 1.15 a single
    /// swipe from a mid-trackpad activation could only cover ~55% of the range,
    /// so 0%/100% were unreachable in one gesture. With 2.0 the full trackpad
    /// height (normalized y ∈ [0,1]) maps to the full value range: sliding to the
    /// bottom/top edge clamps to 0/1 from any initial value. Per-device
    /// normalization keeps the behavior consistent across Mac models.
    var baseGain: Double = 2.0

    func targetValue(initialValue: Double, deltaY: Double, speedMultiplier: Double) -> Double {
        min(1.0, max(0.0, initialValue + deltaY * baseGain * speedMultiplier))
    }
}
