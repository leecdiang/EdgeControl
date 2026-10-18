import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    enum Status: Equatable {
        case notRegistered
        case enabled
        case requiresApproval
        case notFound
    }

    var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        case .notRegistered:
            return .notRegistered
        @unknown default:
            return .notRegistered
        }
    }

    /// A service awaiting user approval is already registered, so the UI must
    /// keep the switch on instead of trying to register it again (which throws
    /// kSMErrorAlreadyRegistered).
    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        let current = status
        if enabled {
            guard current != .enabled, current != .requiresApproval else { return }
            try SMAppService.mainApp.register()
        } else {
            guard current == .enabled || current == .requiresApproval else { return }
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
