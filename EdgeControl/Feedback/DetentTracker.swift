import Foundation

struct DetentTracker: Sendable {
    let interval: Double
    let hysteresis: Double
    private(set) var bucket: Int?

    init(interval: Double = 0.02, hysteresis: Double = 0.008) {
        precondition(interval > 0)
        precondition(hysteresis >= 0 && hysteresis < interval)
        self.interval = interval
        self.hysteresis = hysteresis
    }

    mutating func begin(at value: Double) {
        bucket = bucketIndex(for: value)
    }

    mutating func shouldEmit(for value: Double) -> Bool {
        let clamped = min(1.0, max(0.0, value))
        guard let currentBucket = bucket else {
            begin(at: clamped)
            return false
        }

        let upperThreshold = Double(currentBucket + 1) * interval + hysteresis
        let lowerThreshold = Double(currentBucket) * interval - hysteresis

        if clamped >= upperThreshold {
            bucket = bucketIndex(for: clamped)
            return true
        }

        if clamped <= lowerThreshold {
            bucket = bucketIndex(for: clamped)
            return true
        }

        return false
    }

    mutating func reset() {
        bucket = nil
    }

    private func bucketIndex(for value: Double) -> Int {
        Int(floor(min(1.0, max(0.0, value)) / interval))
    }
}

