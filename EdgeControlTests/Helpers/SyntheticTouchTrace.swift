import Foundation
@testable import EdgeControl

struct SyntheticTouchTrace {
    private(set) var time: TimeInterval = 0
    private(set) var frames: [TouchFrame] = []

    mutating func contact(
        id: Int = 1,
        x: Double,
        y: Double,
        after delay: TimeInterval = 0.01,
        phase: TouchPhase? = nil
    ) {
        time += delay
        let inferredPhase: TouchPhase = phase ?? (frames.last?.contacts.isEmpty == false ? .moved : .began)
        frames.append(
            TouchFrame(
                contacts: [TouchContact(id: id, x: x, y: y, timestamp: time, phase: inferredPhase)],
                timestamp: time
            )
        )
    }

    mutating func contacts(
        _ values: [(id: Int, x: Double, y: Double)],
        after delay: TimeInterval = 0.01
    ) {
        time += delay
        frames.append(
            TouchFrame(
                contacts: values.map {
                    TouchContact(id: $0.id, x: $0.x, y: $0.y, timestamp: time, phase: .moved)
                },
                timestamp: time
            )
        )
    }

    mutating func lift(after delay: TimeInterval = 0.01) {
        time += delay
        frames.append(TouchFrame(contacts: [], timestamp: time))
    }

    func events(using engine: GestureEngine) -> [EdgeGestureEvent] {
        frames.flatMap { engine.process($0) }
    }
}

