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
    case bornInUpperHalf
    case recentKeyboardActivity
    case initialMotionNotInward
    case entryTimedOut
    case leftControlCorridorExited
    case rightControlCorridorExited
    case contactIdentityChanged
    case multipleContacts
    case verticalReversal
}

struct GestureConfiguration: Sendable, Equatable {
    /// Left strip is 1.2%: a middle value between the original 1.5% and the
    /// 0.3% palm-blocking value. Deliberate left-edge births measure x ≈ 0.0-0.0018
    /// on this machine; resting-palm births during typing measure x ≈ 0.007-0.010.
    /// Hardware-tuned on macOS 26.5 (MacBook Air).
    var leftEntryStripWidth: Double = 0.012
    /// Right-edge births measure x ≈ 0.985-1.0 on this machine, so the right
    /// strip stays wider.
    var rightEntryStripWidth: Double = 0.022
    /// Before activation, keep the contact close to the physical edge. This is
    /// deliberately narrower than controlCorridor so an ordinary horizontal
    /// swipe cannot travel deep into the pad and become eligible later.
    var entryCorridor: Double = 0.03
    /// Once active, allow enough horizontal room for comfortable vertical
    /// control without cancelling the session.
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
    /// 0.80 rejects borderline oscillation while keeping deliberate swipes,
    /// which measured ~0.9+ in the reference traces.
    var directionalityRatio: Double = 0.80
    /// The product gesture is "enter, then immediately move vertically". 450ms
    /// retains measured 256-331ms deliberate slides while rejecting the former
    /// 620ms dwell-then-push case. See Docs/GestureTuning.md.
    var entryTimeout: TimeInterval = 0.450

    /// When true, only contacts born in the lower half of the trackpad
    /// (normalized y <= 0.5, i.e. below the midline) can start a gesture.
    /// Resting palms and stray touches in the upper half are rejected at birth.
    /// Normalized y is device-relative, so the midline adapts across Mac models.
    var lowerHalfOnly: Bool = false

    static let `default` = GestureConfiguration()
}
