import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var model: EdgeControlAppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            Form {
                Toggle("Enable EdgeControl", isOn: $settings.masterEnabled)

                Picker("Left edge", selection: $settings.leftEdgeAction) {
                    ForEach(EdgeAction.allCases) { action in
                        Label(action.title, systemImage: action.systemImage).tag(action)
                    }
                }

                Picker("Right edge", selection: $settings.rightEdgeAction) {
                    ForEach(EdgeAction.allCases) { action in
                        Label(action.title, systemImage: action.systemImage).tag(action)
                    }
                }

                Toggle("Volume control enabled", isOn: $settings.volumeEnabled)
                Toggle("Brightness control enabled", isOn: $settings.brightnessEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(settings.sensitivity, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.sensitivity, in: 0.35...2.0, step: 0.05)
                }
            }
            .padding(20)
            .tabItem { Label("Controls", systemImage: "slider.vertical.3") }

            Form {
                Toggle("Haptic feedback", isOn: $settings.hapticFeedback)
                Toggle("Show HUD", isOn: $settings.showHUD)
                Toggle("Colorful HUD", isOn: $settings.colorfulHUD)
                Text("Off: system-style neutral HUD. On: tinted volume/brightness colors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(
                    "Start in lower half only",
                    isOn: Binding(
                        get: { settings.lowerHalfOnly },
                        set: { model.setLowerHalfOnly($0) }
                    )
                )
                Text("Only contacts that start at or below the trackpad midline can activate; adjustment remains relative to the current value.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(
                    "External display DDC (experimental)",
                    isOn: Binding(
                        get: { settings.externalDDCEnabled },
                        set: { model.setExternalDDCEnabled($0) }
                    )
                )
                Text("Used only when no controllable built-in display is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )

                HStack(spacing: 0) {
                    Text("Touch input")
                    Spacer()
                    touchStatusView
                }

                if let error = model.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .tabItem { Label("System", systemImage: "gearshape") }

            VStack(alignment: .leading, spacing: 10) {
                Text("EdgeControl")
                    .font(.title2.bold())
                Text("Two edges. Two controls. Nothing else.")
                    .foregroundStyle(.secondary)
                Divider()
                Text("Open source · No analytics · No network · No account")
                Text("By leecdiang")
                    .font(.callout)
                Text("Uses undocumented macOS interfaces and is not affiliated with Apple Inc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var touchStatusView: some View {
        switch model.touchStatus {
        case .stopped:
            Text("Stopped").foregroundStyle(.secondary)
        case .running:
            Label("Running", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case let .unavailable(message):
            Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        }
    }
}
