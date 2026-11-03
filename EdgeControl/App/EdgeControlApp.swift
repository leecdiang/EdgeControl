import AppKit
import Foundation
import SwiftUI

@MainActor
private final class AppModelStore: ObservableObject {
    let model: EdgeControlAppModel?

    init(createModel: Bool) {
        model = createModel ? EdgeControlAppModel() : nil
    }
}

@main
@MainActor
struct EdgeControlApp: App {
    @StateObject private var store: AppModelStore
    private let instanceCoordinator: SingleInstanceCoordinator?

    init() {
        let isHostedUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let createModel: Bool
        if isHostedUnitTest {
            instanceCoordinator = nil
            createModel = true
        } else {
            let coordinator = SingleInstanceCoordinator()
            let result = coordinator.acquire()
            instanceCoordinator = coordinator

            switch result {
            case .primary:
                createModel = true
            case .duplicate:
                createModel = false
            case .failed:
                // If lock infrastructure is unavailable, avoid creating a second
                // service owner when LaunchServices can still see the primary.
                let existing = NSRunningApplication.runningApplications(
                    withBundleIdentifier: coordinator.bundleIdentifier
                ).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
                createModel = existing.isEmpty
            }
        }

        let store = AppModelStore(createModel: createModel)
        _store = StateObject(wrappedValue: store)
        // App-owned windows use this bundle's artwork even if an external
        // launcher still has an older icon cached for the installation path.
        if createModel, let icon = NSImage(named: NSImage.Name("AppIcon")) {
            NSApplication.shared.applicationIconImage = icon
        }
        // Hosted unit tests must remain independent of real trackpad hardware.
        if createModel, !isHostedUnitTest {
            store.model?.start()
        }
        if !createModel {
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            if let model = store.model {
                MenuBarMenuView()
                    .environmentObject(model)
            }
        } label: {
            if store.model != nil {
                Label {
                    Text("EdgeControl")
                } icon: {
                    Image(nsImage: EdgeControlSymbol.image)
                        .renderingMode(.template)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
