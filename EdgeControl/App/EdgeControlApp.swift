import Foundation
import SwiftUI

@main
@MainActor
struct EdgeControlApp: App {
    @StateObject private var model: EdgeControlAppModel

    init() {
        let model = EdgeControlAppModel()
        _model = StateObject(wrappedValue: model)
        // Hosted unit tests must remain independent of real trackpad hardware.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            model.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(model)
        } label: {
            Label("EdgeControl", systemImage: "slider.vertical.3")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model, settings: model.settings)
        }
    }
}
