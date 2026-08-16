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
    case verticalReversal
}

struct GestureConfiguration: Sendable, Equatable {
    /// Left strip is 0.8%: a middle value between the original 1.5% and the
    /// 0.3% palm-blocking value. Deliberate left-edge births measure x ≈ 0.0-0.0018
    /// on this machine; resting-palm births during typing measure x ≈ 0.007-0.010.
    /// 0.8% keeps deliberate gestures working while rejecting the most interior
    /// palm births (directionality + zero-cross cancellation cover the rest).
    /// Hardware-tuned on macOS 26.5 (MacBook Air).
    var leftEntryStripWidth: Double = 0.008
    /// Right-edge births measure x ≈ 0.985-1.0 on this machine, so the right
    /// strip stays wider.
    var rightEntryStripWidth: Double = 0.015
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
    /// Fraction of the vertical path that must be one-directional before
    /// activation. Tuned from live traces: a resting palm jiggling at the edge
    /// while typing measured ~0.5-0.6; deliberate swipes measure ~0.9+. Default
    /// 0.75 rejects palms while keeping decisive (including slow) swipes.
    var directionalityRatio: Double = 0.75
    /// 800ms tuned from live traces (macOS 26.5, MacBook Air): slide-ins often
    /// dwell at the edge ~600-700ms before the vertical push (observed 620ms
    /// dwell followed by a decisive 40% push). A dwell significantly exceeding
    /// 800ms (spec H) still rejects. See Docs/GestureTuning.md.
    var entryTimeout: TimeInterval = 0.800

    static let `default` = GestureConfiguration()
}

