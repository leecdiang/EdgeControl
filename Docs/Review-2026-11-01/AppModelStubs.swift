import AppKit
import SwiftUI
import Foundation

enum TrackpadPreference: String, CaseIterable { case automatic, builtIn, external }
enum TrackpadKind: Equatable { case unknown; var statusTitle: String { "Fake" } }
final class TrackpadManager {
    var selectedKind: TrackpadKind = .unknown
    func start(preference: TrackpadPreference, frameHandler: @escaping @Sendable (TouchFrame)->Void) throws {}
    func restart(preference: TrackpadPreference, frameHandler: @escaping @Sendable (TouchFrame)->Void) throws {}
    func stop() {}
}
@MainActor final class VolumeControlSession {
    let initialValue: Double = 0.5
    func setVolume(_ value: Double) throws { VolumeController.writes.append(value) }
}
@MainActor final class VolumeController {
    static var writes: [Double] = []
    func beginSession() throws -> VolumeControlSession { VolumeControlSession() }
}
final class BrightnessControlSession {
    let initialValue: Double = 0.5
    func setBrightness(_ value: Double) throws {}
}
final class DisplayBrightnessController {
    func beginSession() throws -> BrightnessControlSession { BrightnessControlSession() }
    func setExternalDDCEnabled(_ enabled: Bool) {}
    func refresh() {}
}
final class HapticEngine {
    func activationTick(initialValue: Double, strength: HapticStrength) {}
    func valueChanged(to: Double, strength: HapticStrength) {}
    func resetAfterWake() {}
    func endGesture() {}
}
final class CursorController {
    var isFrozen = false
    func freeze() -> Bool { isFrozen = true; return true }
    func restore() { isFrozen = false }
}
enum HUDKind { case volume, brightness }
struct HUDPresentation { let kind: HUDKind; let value: Double?; let message: String? }
final class HUDController {
    func setColorStyle(_ style: HUDColorStyle) {}
    func refreshPositionIfNeeded() {}
    func show(_ presentation: HUDPresentation) {}
}
final class LaunchAtLoginController {
    var isEnabled = false
    var requiresApproval = false
    func setEnabled(_ enabled: Bool) throws { isEnabled = enabled }
    func openSystemSettings() {}
}
final class UpdateController { func checkForUpdates() {} }
final class SystemEventMonitor {
    init(onSleep: @escaping ()->Void, onWake: @escaping ()->Void, onDisplaysChanged: @escaping ()->Void, onTerminate: @escaping ()->Void, onActivate: @escaping ()->Void) {}
}
struct SettingsView: View {
    let model: EdgeControlAppModel
    let settings: AppSettings
    var body: some View { EmptyView() }
}
enum EdgeUITheme { static let settingsNeutralScrimOpacity: Double = 0.24 }
