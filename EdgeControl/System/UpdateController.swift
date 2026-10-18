import Foundation
import Sparkle

@MainActor
final class UpdateController: NSObject {
    private let controller: SPUStandardUpdaterController

    override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        // Do not force automatic checks on: the user can turn them off, and
        // Sparkle stores that choice. SUEnableAutomaticChecks in Info.plist
        // only supplies the first-launch default.
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
