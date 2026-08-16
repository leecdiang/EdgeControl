import AppKit
import Combine
import Foundation

@MainActor
final class EdgeControlAppModel: ObservableObject {
    enum TouchStatus: Equatable {
        case stopped
        case running
        case unavailable(String)
    }

    private struct ControlSession {
        let edge: Edge
        let action: EdgeAction
        let initialValue: Double
    }

    let settings: AppSettings
    @Published private(set) var touchStatus: TouchStatus = .stopped
    @Published private(set) var lastError: String?

    private var gestureEngine = GestureEngine()
    private let trackpadManager = TrackpadManager()
    private let volumeController = VolumeController()
    private let brightnessController = DisplayBrightnessController()
    private let hapticEngine = HapticEngine()
    private let cursorController = CursorController()
    private let hudController = HUDController()
    private let launchAtLoginController = LaunchAtLoginController()
    private let mapper = ContinuousValueMapper()
    private var session: ControlSession?
    private var hasStarted = false

    private lazy var systemEventMonitor = SystemEventMonitor(
        onSleep: { [weak self] in self?.finishSession() },
        onWake: { [weak self] in self?.handleWake() },
        onDisplaysChanged: { [weak self] in self?.brightnessController.refresh() },
        onTerminate: { [weak self] in self?.stop() }
    )

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        _ = systemEventMonitor
        settings.launchAtLogin = launchAtLoginController.isEnabled
        runVolumeProbeIfRequested()
        startTouchInput()
    }

    func stop() {
        finishSession()
        trackpadManager.stop()
        touchStatus = .stopped
        hasStarted = false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(enabled)
            settings.launchAtLogin = launchAtLoginController.isEnabled
            lastError = nil
        } catch {
            settings.launchAtLogin = launchAtLoginController.isEnabled
            lastError = error.localizedDescription
        }
    }

    func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startTouchInput() {
        do {
            try trackpadManager.start { [weak self] frame in
                Task { @MainActor [weak self] in
                    self?.consume(frame)
                }
            }
            touchStatus = .running
            lastError = nil
        } catch {
            touchStatus = .unavailable(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    /// Debug-only probe: EDGE_VOLUME_PROBE=0.25 exercises the real
    /// VolumeController read/write path on launch and logs the results.
    private func runVolumeProbeIfRequested() {
        #if EDGE_DEBUG_LOGGING
        guard let raw = ProcessInfo.processInfo.environment["EDGE_VOLUME_PROBE"],
              let target = Double(raw) else { return }
        do {
            let before = try volumeController.getVolume()
            try volumeController.setVolume(target)
            let after = try volumeController.getVolume()
            print("[EdgeControl][VolumeProbe] before=\(String(format: "%.3f", before)) "
                + "set=\(String(format: "%.3f", target)) after=\(String(format: "%.3f", after))")
        } catch {
            print("[EdgeControl][VolumeProbe] FAILED: \(error.localizedDescription)")
        }
        #endif
    }

    private func handleWake() {
        finishSession()
        gestureEngine = GestureEngine(configuration: gestureEngine.configuration)
        brightnessController.refresh()
        hapticEngine.resetAfterWake()
        do {
            try trackpadManager.restart { [weak self] frame in
                Task { @MainActor [weak self] in self?.consume(frame) }
            }
            touchStatus = .running
        } catch {
            touchStatus = .unavailable(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    private func consume(_ frame: TouchFrame) {
        let events = gestureEngine.process(frame)
        for event in events {
            switch event {
            case let .began(edge):
                beginSession(edge: edge)
            case let .changed(edge, deltaY):
                changeSession(edge: edge, deltaY: deltaY)
            case .ended, .cancelled:
                finishSession()
            }
        }
    }

    private func beginSession(edge: Edge) {
        guard settings.masterEnabled else { return }
        let action = edge == .left ? settings.leftEdgeAction : settings.rightEdgeAction
        guard isEnabled(action) else { return }

        do {
            let initialValue: Double
            switch action {
            case .volume:
                initialValue = try volumeController.getVolume()
            case .brightness:
                initialValue = try brightnessController.getBrightness()
            case .disabled:
                return
            }

            session = ControlSession(edge: edge, action: action, initialValue: initialValue)
            if settings.hapticFeedback {
                hapticEngine.activationTick(initialValue: initialValue)
            }
            _ = cursorController.freeze()
            showHUD(action: action, value: initialValue, message: nil)
            lastError = nil
        } catch {
            showHUD(action: action, value: nil, message: error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    private func changeSession(edge: Edge, deltaY: Double) {
        guard settings.masterEnabled, let session, session.edge == edge, isEnabled(session.action) else {
            finishSession()
            return
        }

        // Polarity: on this Mac (macOS 26.5) MT normalized y grows with physical
        // upward motion (y=0 bottom, y=1 top), so an upward swipe yields a
        // positive deltaY and increases the value — matching volume/brightness
        // key convention. Verified by live trace 2026-08-16.
        let target = mapper.targetValue(
            initialValue: session.initialValue,
            deltaY: deltaY,
            sensitivity: settings.sensitivity
        )
        do {
            switch session.action {
            case .volume:
                #if EDGE_DEBUG_LOGGING
                print("[EdgeControl][Volume] set target=\(String(format: "%.3f", target)) deltaY=\(String(format: "%.4f", deltaY))")
                #endif
                try volumeController.setVolume(target)
            case .brightness:
                try brightnessController.setBrightness(target)
            case .disabled:
                return
            }
            if settings.hapticFeedback {
                hapticEngine.valueChanged(to: target)
            }
            showHUD(action: session.action, value: target, message: nil)
            lastError = nil
        } catch {
            showHUD(action: session.action, value: nil, message: error.localizedDescription)
            lastError = error.localizedDescription
            finishSession()
        }
    }

    private func finishSession() {
        session = nil
        cursorController.restore()
        hapticEngine.endGesture()
    }

    private func isEnabled(_ action: EdgeAction) -> Bool {
        switch action {
        case .disabled: return false
        case .volume: return settings.volumeEnabled
        case .brightness: return settings.brightnessEnabled
        }
    }

    private func showHUD(action: EdgeAction, value: Double?, message: String?) {
        guard settings.showHUD else { return }
        let kind: HUDKind = action == .volume ? .volume : .brightness
        hudController.show(HUDPresentation(kind: kind, value: value, message: message))
    }
}
