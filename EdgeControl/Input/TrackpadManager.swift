import Foundation

enum TrackpadManagerError: LocalizedError {
    case privateAPIUnavailable
    case openFailed

    var errorDescription: String? {
        switch self {
        case .privateAPIUnavailable:
            return "The private multitouch interface is unavailable on this Mac."
        case .openFailed:
            return "The trackpad could not be opened."
        }
    }
}

private struct RawTouchContact: Sendable {
    let id: Int
    let x: Double
    let y: Double
    let rawState: Int32
    let size: Float
}

private struct RawTouchFrame: Sendable {
    let contacts: [RawTouchContact]
    let timestamp: TimeInterval
}

/// Owns the MultitouchSupport handle and confines all Swift-side frame mutation
/// to `processingQueue`. The type is `@unchecked Sendable` because the private C
/// callback can arrive on an undocumented thread; its only cross-thread entry
/// point copies value types and dispatches them onto that serial queue.
final class TrackpadManager: @unchecked Sendable {
    typealias FrameHandler = @Sendable (TouchFrame) -> Void

    private let processingQueue = DispatchQueue(label: "app.edgecontrol.trackpad.frames")
    private let lifecycleQueue = DispatchQueue(label: "app.edgecontrol.trackpad.lifecycle")
    private var activeContactIDs: Set<Int> = []
    private var frameHandler: FrameHandler?
    private var handle: OpaquePointer?

    var isPrivateAPIAvailable: Bool {
        ec_mt_is_available()
    }

    func start(frameHandler: @escaping FrameHandler) throws {
        try lifecycleQueue.sync {
            guard handle == nil else {
                processingQueue.sync { self.frameHandler = frameHandler }
                return
            }
            guard ec_mt_is_available() else {
                throw TrackpadManagerError.privateAPIUnavailable
            }

            processingQueue.sync {
                self.frameHandler = frameHandler
                self.activeContactIDs.removeAll()
            }

            let context = Unmanaged.passUnretained(self).toOpaque()
            guard let opened = ec_mt_open(edgeControlTouchFrameCallback, context) else {
                processingQueue.sync { self.frameHandler = nil }
                throw TrackpadManagerError.openFailed
            }
            handle = opened
        }
    }

    func stop() {
        lifecycleQueue.sync {
            if let handle {
                ec_mt_close(handle)
                self.handle = nil
            }
            processingQueue.sync {
                self.activeContactIDs.removeAll()
                self.frameHandler = nil
            }
        }
    }

    func restart(frameHandler: @escaping FrameHandler) throws {
        stop()
        try start(frameHandler: frameHandler)
    }

    fileprivate func receive(
        contacts: UnsafePointer<ECTouchContactRaw>?,
        count: Int,
        timestamp: TimeInterval
    ) {
        var copied: [RawTouchContact] = []
        if let contacts, count > 0 {
            copied.reserveCapacity(count)
            for index in 0..<count {
                let contact = contacts[index]
                copied.append(
                    RawTouchContact(
                        id: Int(contact.identifier),
                        x: min(1.0, max(0.0, contact.x)),
                        y: min(1.0, max(0.0, contact.y)),
                        rawState: contact.raw_state,
                        size: contact.size
                    )
                )
            }
        }

        let rawFrame = RawTouchFrame(contacts: copied, timestamp: timestamp)
        processingQueue.async { [self] in
            deliver(rawFrame)
        }
    }

    private func deliver(_ rawFrame: RawTouchFrame) {
        let currentIDs = Set(rawFrame.contacts.map(\.id))
        let contacts = rawFrame.contacts.map { raw -> TouchContact in
            let phase: TouchPhase = activeContactIDs.contains(raw.id) ? .moved : .began
            return TouchContact(
                id: raw.id,
                x: raw.x,
                y: raw.y,
                timestamp: rawFrame.timestamp,
                phase: phase
            )
        }
        activeContactIDs = currentIDs

        #if EDGE_DEBUG_LOGGING
        for raw in rawFrame.contacts {
            print("[EdgeControl][RawTouch] id=\(raw.id) x=\(raw.x) y=\(raw.y) size=\(String(format: "%.3f", raw.size)) rawState=\(raw.rawState) fingers=\(rawFrame.contacts.count)")
        }
        #endif
        frameHandler?(TouchFrame(contacts: contacts, timestamp: rawFrame.timestamp))
    }

    deinit {
        stop()
    }
}

private func edgeControlTouchFrameCallback(
    _ context: UnsafeMutableRawPointer?,
    _ contacts: UnsafePointer<ECTouchContactRaw>?,
    _ contactCount: Int,
    _ timestamp: Double
) {
    guard let context else { return }
    let manager = Unmanaged<TrackpadManager>.fromOpaque(context).takeUnretainedValue()
    manager.receive(contacts: contacts, count: contactCount, timestamp: timestamp)
}

