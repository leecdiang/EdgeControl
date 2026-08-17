import Foundation

enum TrackpadPreference: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case builtIn
    case external

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .builtIn: return "Built-in trackpad"
        case .external: return "External Magic Trackpad"
        }
    }

    fileprivate var bridgeValue: Int32 {
        switch self {
        case .automatic: return 0
        case .builtIn: return 1
        case .external: return 2
        }
    }
}

enum TrackpadKind: Sendable, Equatable {
    case unknown
    case builtIn
    case external

    init(bridgeValue: Int32) {
        switch bridgeValue {
        case 1: self = .builtIn
        case 2: self = .external
        default: self = .unknown
        }
    }

    var statusTitle: String {
        switch self {
        case .unknown: return "Running"
        case .builtIn: return "Built-in"
        case .external: return "External"
        }
    }
}

enum TrackpadManagerError: LocalizedError {
    case privateAPIUnavailable
    case openFailed(TrackpadPreference)

    var errorDescription: String? {
        switch self {
        case .privateAPIUnavailable:
            return "The private multitouch interface is unavailable on this Mac."
        case let .openFailed(preference):
            return "\(preference.title) could not be opened. Connect it, choose another trackpad, or rescan."
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
    private(set) var selectedKind: TrackpadKind = .unknown

    var isPrivateAPIAvailable: Bool {
        ec_mt_is_available()
    }

    static func surfaceDimensionsLookLikeTrackpad(width: Int32, height: Int32) -> Bool {
        ec_mt_surface_dimensions_look_like_trackpad(width, height)
    }

    func start(
        preference: TrackpadPreference,
        frameHandler: @escaping FrameHandler
    ) throws {
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
            var selectedKindValue: Int32 = 0
            guard let opened = ec_mt_open(
                preference.bridgeValue,
                edgeControlTouchFrameCallback,
                context,
                &selectedKindValue
            ) else {
                processingQueue.sync { self.frameHandler = nil }
                selectedKind = .unknown
                throw TrackpadManagerError.openFailed(preference)
            }
            handle = opened
            selectedKind = TrackpadKind(bridgeValue: selectedKindValue)
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
            selectedKind = .unknown
        }
    }

    func restart(
        preference: TrackpadPreference,
        frameHandler: @escaping FrameHandler
    ) throws {
        stop()
        try start(preference: preference, frameHandler: frameHandler)
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
