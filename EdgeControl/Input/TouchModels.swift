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
}

