import Foundation

enum Edge: String, CaseIterable, Sendable, Equatable {
    case left
    case right
}

enum EdgeGestureEvent: Sendable, Equatable {
    case began(edge: Edge)
    case changed(edge: Edge, deltaY: Double)
    case ended(edge: Edge)
    case cancelled(edge: Edge)
}

enum GestureRejectReason: String, Sendable, Equatable {
    case bornInInterior
    case initialMotionNotInward
    case entryTimedOut
    case leftControlCorridorExited
    case rightControlCorridorExited
    case contactIdentityChanged
    case multipleContacts
}

struct GestureConfiguration: Sendable, Equatable {
    var entryStripWidth: Double = 0.015
    var controlCorridor: Double = 0.08
    var minimumInwardTravel: Double = 0.008
    var minimumVerticalMove: Double = 0.015
    var outwardRejectionTravel: Double = 0.004
    var entryTimeout: TimeInterval = 0.250

    static let `default` = GestureConfiguration()
}

