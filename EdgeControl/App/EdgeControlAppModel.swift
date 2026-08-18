import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class EdgeControlAppModel: ObservableObject {
    enum TouchStatus: Equatable {
        case stopped
        case running(TrackpadKind)
        case unavailable(String)
    }

    private struct ControlSession {
        let edge: Edge
        let action: EdgeAction
        let initialValue: Double
        let speedMultiplier: Double
        let hapticStrength: HapticStrength
        let brightnessSession: BrightnessControlSession?
    }

    let settings: AppSettings
    @Published private(set) var touchStatus: TouchStatus = .stopped
    @Published private(set) var lastError: String?

    private var gestureEngine: GestureEngine
    private let trackpadManager = TrackpadManager()
    private let volumeController = VolumeController()
    private let brightnessController = DisplayBrightnessController()
    private let hapticEngine = HapticEngine()
    private var settingsWindow: NSWindow?
    private let cursorController = CursorController()
    private let hudController = HUDController()
    private let launchAtLoginController = LaunchAtLoginController()
    private let keyboardActivityGuard: RecentKeyboardActivityGuard
    private let mapper = ContinuousValueMapper()
    private var session: ControlSession?
    private var hasStarted = false
    private var lastTouchFrameUptime = ProcessInfo.processInfo.systemUptime
    private var hasLiveTouchContacts = false
    private var discardTouchFramesUntilLift = false
    private var touchWatchdogTask: Task<Void, Never>?
    private var frameGeneration: UInt64 = 0

    private lazy var systemEventMonitor = SystemEventMonitor(
        onSleep: { [weak self] in self?.finishSession() },
        onWake: { [weak self] in self?.handleWake() },
        onDisplaysChanged: { [weak self] in self?.handleDisplaysChanged() },
        onTerminate: { [weak self] in self?.stop() }
    )

    init(
        settings: AppSettings = AppSettings(),
        keyboardActivityGuard: RecentKeyboardActivityGuard = RecentKeyboardActivityGuard()
    ) {
        self.settings = settings
        self.keyboardActivityGuard = keyboardActivityGuard
        self.gestureEngine = Self.makeGestureEngine(settings: settings)
        brightnessController.setExternalDDCEnabled(settings.externalDDCEnabled)
    }

    private static func makeGestureEngine(settings: AppSettings) -> GestureEngine {
        var config = settings.falseTouchProtection.gestureConfiguration
        config.lowerHalfOnly = settings.lowerHalfOnly
        return GestureEngine(configuration: config)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        _ = systemEventMonitor
        settings.launchAtLogin = launchAtLoginController.isEnabled
        runVolumeProbeIfRequested()
        runBrightnessProbeIfRequested()
        startTouchWatchdog()
        startTouchInput()
    }

    func stop() {
        finishSession()
        trackpadManager.stop()
        hasLiveTouchContacts = false
        discardTouchFramesUntilLift = false
        touchWatchdogTask?.cancel()
        touchWatchdogTask = nil
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

    func setExternalDDCEnabled(_ enabled: Bool) {
        finishBrightnessSessionIfNeeded()
        settings.externalDDCEnabled = enabled
        brightnessController.setExternalDDCEnabled(enabled)
    }

    func setLowerHalfOnly(_ enabled: Bool) {
        settings.lowerHalfOnly = enabled
        rebuildGestureEngineAfterAdmissionChange()
    }

    func setFalseTouchProtection(_ protection: FalseTouchProtection) {
        settings.falseTouchProtection = protection
        rebuildGestureEngineAfterAdmissionChange()
    }

    private func rebuildGestureEngineAfterAdmissionChange() {
        finishSession()
        // Rebuilding while a finger is down must never reinterpret that
        // existing contact as a fresh edge birth. Preserve a watchdog latch
        // even though that recovery path has already cleared the live flag.
        discardTouchFramesUntilLift = discardTouchFramesUntilLift || hasLiveTouchContacts
        gestureEngine = Self.makeGestureEngine(settings: settings)
        lastError = nil
    }

    func setTrackpadPreference(_ preference: TrackpadPreference) {
        settings.trackpadPreference = preference
        if hasStarted {
            rescanTrackpads()
        } else {
            lastError = nil
        }
    }

    func rescanTrackpads() {
        guard hasStarted else { return }
        finishSession()
        hapticEngine.resetAfterWake()
        trackpadManager.stop()
        frameGeneration &+= 1
        hasLiveTouchContacts = false
        discardTouchFramesUntilLift = false
        gestureEngine = Self.makeGestureEngine(settings: settings)
        touchStatus = .stopped
        startTouchInput()
    }

    func openSettings() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(rootView: SettingsView(model: self, settings: settings))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 470),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "EdgeControl Settings"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.setContentSize(NSSize(width: 560, height: 470))
            window.minSize = NSSize(width: 520, height: 430)
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Debug-only probe: EDGE_BRIGHTNESS_PROBE=0.25 exercises the real
    /// DisplayBrightnessController read/write path on launch and logs results.
    private func runBrightnessProbeIfRequested() {
        #if EDGE_DEBUG_LOGGING
        guard let raw = ProcessInfo.processInfo.environment["EDGE_BRIGHTNESS_PROBE"],
              let target = Double(raw) else { return }
        setvbuf(stdout, nil, _IONBF, 0)
        do {
            let session = try brightnessController.beginSession()
            let before = session.initialValue
            try session.setBrightness(target)
            let after = try brightnessController.beginSession().initialValue
            print("[EdgeControl][BrightnessProbe] before=\(String(format: "%.3f", before)) "
                + "set=\(String(format: "%.3f", target)) after=\(String(format: "%.3f", after))")
        } catch {
            print("[EdgeControl][BrightnessProbe] FAILED: \(error.localizedDescription)")
        }
        #endif
    }

    private func startTouchInput() {
        let generation = frameGeneration
        do {
            try trackpadManager.start(preference: settings.trackpadPreference) { [weak self] frame in
                Task { @MainActor [weak self] in
                    self?.consume(frame, generation: generation)
                }
            }
            touchStatus = .running(trackpadManager.selectedKind)
            lastError = nil
            runActuatorProbeIfRequested()
        } catch {
            touchStatus = .unavailable(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    /// A Bluetooth disconnect may stop callbacks without delivering a final
    /// empty frame. Reset any live-contact lifecycle after sustained frame
    /// silence; if it was Active, this also restores cursor and haptic state.
    /// The intended gesture is continuous, so 750ms is deliberately much longer
    /// than normal frame gaps.
    private func startTouchWatchdog() {
        touchWatchdogTask?.cancel()
        touchWatchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, let self else { return }
                guard self.hasLiveTouchContacts || self.session != nil else { continue }

                let silence = ProcessInfo.processInfo.systemUptime - self.lastTouchFrameUptime
                if silence >= 0.750 {
                    self.finishSession()
                    self.hasLiveTouchContacts = false
                    self.discardTouchFramesUntilLift = true
                    self.gestureEngine = Self.makeGestureEngine(settings: self.settings)
                    #if EDGE_DEBUG_LOGGING
                    print("[EdgeControl][Trackpad] live touch reset after callback silence")
                    #endif
                }
            }
        }
    }

    /// Debug-only: EDGE_HAPTIC_PATTERN_TEST=1 pulses the given actuator pattern
    /// a few times once the MT device is open, to audition patterns locally.
    /// Requires EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1.
    private func runActuatorProbeIfRequested() {
        #if EDGE_DEBUG_LOGGING
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["EDGE_HAPTIC_PATTERN_TEST"], let pattern = Int32(raw) else { return }
        Task { @MainActor in
            for _ in 0..<3 {
                let ok = ec_mt_private_haptic_pulse(pattern)
                print("[EdgeControl][ActuatorProbe] pattern=\(pattern) ok=\(ok)")
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
        #endif
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
        hasLiveTouchContacts = false
        discardTouchFramesUntilLift = false
        gestureEngine = Self.makeGestureEngine(settings: settings)
        brightnessController.refresh()
        hapticEngine.resetAfterWake()
        frameGeneration &+= 1
        let generation = frameGeneration
        do {
            try trackpadManager.restart(preference: settings.trackpadPreference) { [weak self] frame in
                Task { @MainActor [weak self] in self?.consume(frame, generation: generation) }
            }
            touchStatus = .running(trackpadManager.selectedKind)
        } catch {
            touchStatus = .unavailable(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    private func handleDisplaysChanged() {
        // Never let a display reconfiguration switch an in-flight brightness
        // gesture from the built-in panel to DDC (or the reverse).
        finishBrightnessSessionIfNeeded()
        brightnessController.refresh()
    }

    private func consume(_ frame: TouchFrame, generation: UInt64) {
        guard generation == frameGeneration else { return }
        lastTouchFrameUptime = ProcessInfo.processInfo.systemUptime

        // After callback silence, a resumed frame may still carry the old
        // physical contact. Do not let that frame become a fresh edge birth.
        // An empty frame or an explicit bridge restart clears this latch.
        if discardTouchFramesUntilLift {
            if frame.contacts.isEmpty {
                discardTouchFramesUntilLift = false
                gestureEngine = Self.makeGestureEngine(settings: settings)
            }
            hasLiveTouchContacts = false
            return
        }

        hasLiveTouchContacts = !frame.contacts.isEmpty
        // Do not query keyboard timing while the product master switch is off.
        let blockNewGestureForRecentTyping = settings.masterEnabled
            && !frame.contacts.isEmpty
            && gestureEngine.isAwaitingActivation
            && keyboardActivityGuard.shouldBlock(
                for: settings.falseTouchProtection.typingSuppressionInterval
            )
        let events = gestureEngine.process(
            frame,
            blockNewGestureForRecentTyping: blockNewGestureForRecentTyping
        )
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
            let brightnessSession: BrightnessControlSession?
            switch action {
            case .volume:
                initialValue = try volumeController.getVolume()
                brightnessSession = nil
            case .brightness:
                let started = try brightnessController.beginSession()
                initialValue = started.initialValue
                brightnessSession = started
            case .disabled:
                return
            }

            session = ControlSession(
                edge: edge,
                action: action,
                initialValue: initialValue,
                // Pin speed for the whole gesture so a settings change cannot
                // alter gain halfway through an adjustment and cause a jump.
                speedMultiplier: settings.adjustmentSpeed.gainMultiplier,
                // Keep the tactile character stable for the whole gesture.
                hapticStrength: settings.hapticStrength,
                brightnessSession: brightnessSession
            )
            if settings.hapticFeedback {
                hapticEngine.activationTick(
                    initialValue: initialValue,
                    strength: settings.hapticStrength
                )
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

        // Always anchor control to the value captured when the session begins.
        // Lower-half-only is an admission filter, not an absolute position
        // mapping: entering near the midline must not force the value toward
        // 100%. On the reference Mac, normalized y grows with upward motion, so
        // a positive cumulative delta increases the value.
        let target = mapper.targetValue(
            initialValue: session.initialValue,
            deltaY: deltaY,
            speedMultiplier: session.speedMultiplier
        )
        do {
            switch session.action {
            case .volume:
                #if EDGE_DEBUG_LOGGING
                print("[EdgeControl][Volume] set target=\(String(format: "%.3f", target)) deltaY=\(String(format: "%.4f", deltaY))")
                #endif
                try volumeController.setVolume(target)
            case .brightness:
                #if EDGE_DEBUG_LOGGING
                print("[EdgeControl][Brightness] set target=\(String(format: "%.3f", target)) deltaY=\(String(format: "%.4f", deltaY))")
                #endif
                guard let brightnessSession = session.brightnessSession else {
                    throw ControlError.unavailable("Brightness session is unavailable.")
                }
                try brightnessSession.setBrightness(target)
            case .disabled:
                return
            }
            if settings.hapticFeedback {
                hapticEngine.valueChanged(
                    to: target,
                    strength: session.hapticStrength
                )
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

    private func finishBrightnessSessionIfNeeded() {
        if session?.action == .brightness {
            finishSession()
        }
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
        hudController.colorStyle = settings.hudColorStyle
        let kind: HUDKind = action == .volume ? .volume : .brightness
        hudController.show(HUDPresentation(kind: kind, value: value, message: message))
    }
}
