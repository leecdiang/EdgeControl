import Foundation

/// Hardware-independent recognizer for the Physical Edge Ingress Gesture.
///
/// The engine intentionally treats the first observed position as the contact's
/// birth position. A contact born in the interior can never become eligible
/// later in the same lifecycle. Feed an empty frame after all fingers lift.
final class GestureEngine {
    struct Candidate: Sendable, Equatable {
        let contactID: Int
        let edge: Edge
        let birthX: Double
        let birthY: Double
        let birthTimestamp: TimeInterval
        var lastX: Double
        var lastY: Double
    }

    struct ActiveContact: Sendable, Equatable {
        let contactID: Int
        let edge: Edge
        let activationY: Double
        var lastX: Double
        var lastY: Double
    }

    enum State: Sendable, Equatable {
        case idle
        case entryCandidate(Candidate)
        case entryConfirmed(Candidate)
        case active(ActiveContact)
        case rejected(GestureRejectReason)
        case multiTouchRejected
    }

    let configuration: GestureConfiguration
    private(set) var state: State = .idle
    private var multiTouchLatched = false

    init(configuration: GestureConfiguration = .default) {
        self.configuration = configuration
    }

    @discardableResult
    func process(_ frame: TouchFrame) -> [EdgeGestureEvent] {
        let liveContacts = frame.contacts.filter {
            $0.phase != .ended && $0.phase != .cancelled
        }

        if liveContacts.isEmpty {
            let wasCancelled = frame.contacts.contains { $0.phase == .cancelled }
            let events: [EdgeGestureEvent]
            if case let .active(active) = state {
                events = [wasCancelled ? .cancelled(edge: active.edge) : .ended(edge: active.edge)]
            } else {
                events = []
            }
            resetAfterAllContactsLifted()
            debug(frame, note: wasCancelled ? "all contacts cancelled" : "all contacts lifted")
            return events
        }

        if multiTouchLatched {
            state = .multiTouchRejected
            debug(frame, note: "multi-touch rejection remains latched")
            return []
        }

        if liveContacts.count >= 2 {
            multiTouchLatched = true
            let events: [EdgeGestureEvent]
            if case let .active(active) = state {
                events = [.cancelled(edge: active.edge)]
            } else {
                events = []
            }
            state = .multiTouchRejected
            debug(frame, note: GestureRejectReason.multipleContacts.rawValue)
            return events
        }

        let contact = liveContacts[0]
        let events: [EdgeGestureEvent]

        switch state {
        case .idle:
            events = beginLifecycle(with: contact)

        case var .entryCandidate(candidate):
            events = advanceCandidate(&candidate, contact: contact, timestamp: frame.timestamp, inwardConfirmed: false)

        case var .entryConfirmed(candidate):
            events = advanceCandidate(&candidate, contact: contact, timestamp: frame.timestamp, inwardConfirmed: true)

        case var .active(active):
            events = advanceActive(&active, contact: contact)

        case .rejected, .multiTouchRejected:
            events = []
        }

        debug(frame, note: events.isEmpty ? nil : "events=\(events)")
        return events
    }

    private func beginLifecycle(with contact: TouchContact) -> [EdgeGestureEvent] {
        let edge: Edge?
        if contact.x <= configuration.entryStripWidth {
            edge = .left
        } else if contact.x >= 1.0 - configuration.entryStripWidth {
            edge = .right
        } else {
            edge = nil
        }

        guard let edge else {
            state = .rejected(.bornInInterior)
            return []
        }

        state = .entryCandidate(
            Candidate(
                contactID: contact.id,
                edge: edge,
                birthX: contact.x,
                birthY: contact.y,
                birthTimestamp: contact.timestamp,
                lastX: contact.x,
                lastY: contact.y
            )
        )
        return []
    }

    private func advanceCandidate(
        _ candidate: inout Candidate,
        contact: TouchContact,
        timestamp: TimeInterval,
        inwardConfirmed: Bool
    ) -> [EdgeGestureEvent] {
        guard contact.id == candidate.contactID else {
            state = .rejected(.contactIdentityChanged)
            return []
        }

        guard timestamp - candidate.birthTimestamp <= configuration.entryTimeout else {
            state = .rejected(.entryTimedOut)
            return []
        }

        guard isInsideCorridor(x: contact.x, edge: candidate.edge) else {
            state = .rejected(corridorRejectReason(for: candidate.edge))
            return []
        }

        let rawDX = contact.x - candidate.birthX
        let rawDY = contact.y - candidate.birthY
        let inwardTravel = candidate.edge == .left ? rawDX : -rawDX

        if inwardTravel < -configuration.outwardRejectionTravel {
            state = .rejected(.initialMotionNotInward)
            return []
        }

        candidate.lastX = contact.x
        candidate.lastY = contact.y
        let hasInwardMotion = inwardConfirmed || inwardTravel >= configuration.minimumInwardTravel

        guard hasInwardMotion else {
            state = .entryCandidate(candidate)
            return []
        }

        guard abs(rawDY) >= configuration.minimumVerticalMove else {
            state = .entryConfirmed(candidate)
            return []
        }

        state = .active(
            ActiveContact(
                contactID: contact.id,
                edge: candidate.edge,
                activationY: contact.y,
                lastX: contact.x,
                lastY: contact.y
            )
        )
        return [.began(edge: candidate.edge)]
    }

    private func advanceActive(
        _ active: inout ActiveContact,
        contact: TouchContact
    ) -> [EdgeGestureEvent] {
        guard contact.id == active.contactID else {
            state = .rejected(.contactIdentityChanged)
            return [.cancelled(edge: active.edge)]
        }

        guard isInsideCorridor(x: contact.x, edge: active.edge) else {
            state = .rejected(corridorRejectReason(for: active.edge))
            return [.cancelled(edge: active.edge)]
        }

        let deltaY = contact.y - active.activationY
        let moved = contact.x != active.lastX || contact.y != active.lastY
        active.lastX = contact.x
        active.lastY = contact.y
        state = .active(active)
        return moved ? [.changed(edge: active.edge, deltaY: deltaY)] : []
    }

    private func isInsideCorridor(x: Double, edge: Edge) -> Bool {
        switch edge {
        case .left:
            return x >= 0.0 && x <= configuration.controlCorridor
        case .right:
            return x >= 1.0 - configuration.controlCorridor && x <= 1.0
        }
    }

    private func corridorRejectReason(for edge: Edge) -> GestureRejectReason {
        edge == .left ? .leftControlCorridorExited : .rightControlCorridorExited
    }

    private func resetAfterAllContactsLifted() {
        multiTouchLatched = false
        state = .idle
    }

    private func debug(_ frame: TouchFrame, note: String?) {
        #if EDGE_DEBUG_LOGGING
        let contacts = frame.contacts.map {
            "id=\($0.id) x=\(String(format: "%.4f", $0.x)) y=\(String(format: "%.4f", $0.y)) phase=\($0.phase)"
        }.joined(separator: ", ")
        print("[EdgeControl][Gesture] t=\(String(format: "%.4f", frame.timestamp)) fingers=\(frame.contacts.count) state=\(state) contacts=[\(contacts)] \(note ?? "")")
        #endif
    }
}
