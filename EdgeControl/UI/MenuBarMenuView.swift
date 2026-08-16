import AppKit
import SwiftUI

@MainActor
struct MenuBarMenuView: View {
    @EnvironmentObject private var model: EdgeControlAppModel

    var body: some View {
        MenuBarSettingsContent(model: model, settings: model.settings)
    }
}

@MainActor
private struct MenuBarSettingsContent: View {
    @ObservedObject var model: EdgeControlAppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        Toggle("Enabled", isOn: $settings.masterEnabled)

        Divider()

        Picker("Left Edge", selection: $settings.leftEdgeAction) {
            ForEach(EdgeAction.allCases) { action in
                Label(action.title, systemImage: action.systemImage).tag(action)
            }
        }
        Picker("Right Edge", selection: $settings.rightEdgeAction) {
            ForEach(EdgeAction.allCases) { action in
                Label(action.title, systemImage: action.systemImage).tag(action)
            }
        }

        Divider()

        Toggle("Haptic Feedback", isOn: $settings.hapticFeedback)
        Button {
            model.setLaunchAtLogin(!settings.launchAtLogin)
        } label: {
            if settings.launchAtLogin {
                Label("Launch at Login", systemImage: "checkmark")
            } else {
                Text("Launch at Login")
            }
        }

        Divider()

        Button("Settings…") { model.openSettings() }
            .keyboardShortcut(",")
        Button("Quit EdgeControl") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
