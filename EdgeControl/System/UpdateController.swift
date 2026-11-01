import Foundation
import Combine
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject {
    @Published private(set) var automaticallyChecksForUpdates = false
    private let controller: SPUStandardUpdaterController

    init(startingUpdater: Bool = true) {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        // Do not force automatic checks on: the user can turn them off, and
        // Sparkle stores that choice. SUEnableAutomaticChecks in Info.plist
        // only supplies the first-launch default.
        if startingUpdater { controller.startUpdater() }
        refreshPreferences()
    }

    func refreshPreferences() {
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        refreshPreferences()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
