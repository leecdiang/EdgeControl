import Foundation

enum TouchPhase: Int, Sendable, Equatable {
    case began
    case moved
    case ended
    case cancelled
}

struct TouchContact: Sendable, Equatable {
    let id: Int
    let x: Double
    let y: Double
    let timestamp: TimeInterval
    let phase: TouchPhase
}

struct TouchFrame: Sendable, Equatable {
    let contacts: [TouchContact]
    let timestamp: TimeInterval
    /// Monotonic receipt time, independent of the undocumented device clock.
    let receivedAtUptime: TimeInterval

    init(contacts: [TouchContact], timestamp: TimeInterval,
         receivedAtUptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.contacts = contacts
        self.timestamp = timestamp
        self.receivedAtUptime = receivedAtUptime
    }
}

/// A single scheduled consumer drains callback frames in order. Overflow is a
/// discontinuity, never a license to reinterpret a remaining contact as a birth.
final class TouchFrameMailbox: @unchecked Sendable {
    struct Delivery {
        let frame: TouchFrame
        let discontinuity: Bool
    }
    private let lock = NSLock()
    private let capacity: Int
    private var frames: [TouchFrame] = []
    private var discontinuity = false
    private var scheduled = false

    init(capacity: Int = 32) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    /// True only when the caller must schedule a new drain task.
    func submit(_ frame: TouchFrame) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if frames.count == capacity {
            frames.removeAll(keepingCapacity: true)
            discontinuity = true
        }
        frames.append(frame)
        guard !scheduled else { return false }
        scheduled = true
        return true
    }

    func next() -> Delivery? {
        lock.lock()
        defer { lock.unlock() }
        guard !frames.isEmpty else {
            scheduled = false
            return nil
        }
        let result = Delivery(frame: frames.removeFirst(), discontinuity: discontinuity)
        discontinuity = false
        return result
    }
}
