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
    /// Hardware-tuned on macOS 26.5 (arm64, MacBook Air): edge-pinned contacts
    /// report normalized x pinned at 0.0/1.0 with no measurable positive inward
    /// growth (observed max 0.0011 during slide-in). A positive threshold made
    /// every physical edge ingress time out. Inward character is instead enforced
    /// by birth-in-strip plus the outwardRejectionTravel guard (a contact that
    /// moves away from its edge is rejected). See Docs/GestureTuning.md.
    var minimumInwardTravel: Double = 0.0
    var minimumVerticalMove: Double = 0.015
    var outwardRejectionTravel: Double = 0.004
    var entryTimeout: TimeInterval = 0.250

    static let `default` = GestureConfiguration()
}

