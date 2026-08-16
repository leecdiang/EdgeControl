import AppKit
import Foundation

@MainActor
final class SystemEventMonitor: NSObject {
    private let onSleep: () -> Void
    private let onWake: () -> Void
    private let onDisplaysChanged: () -> Void
    private let onTerminate: () -> Void

    init(
        onSleep: @escaping () -> Void,
        onWake: @escaping () -> Void,
        onDisplaysChanged: @escaping () -> Void,
        onTerminate: @escaping () -> Void
    ) {
        self.onSleep = onSleep
        self.onWake = onWake
        self.onDisplaysChanged = onDisplaysChanged
        self.onTerminate = onTerminate
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func handleSleep() {
        onSleep()
    }

    @objc private func handleWake() {
        onWake()
    }

    @objc private func handleDisplaysChanged() {
        onDisplaysChanged()
    }

    @objc private func handleTerminate() {
        onTerminate()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
