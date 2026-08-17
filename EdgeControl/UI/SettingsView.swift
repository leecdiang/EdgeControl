import Foundation
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

                Picker("Adjustment speed", selection: $settings.adjustmentSpeed) {
                    ForEach(AdjustmentSpeed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                Text("Changes adjustment gain only; it never changes gesture activation rules.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(
                    "False-touch protection",
                    selection: Binding(
                        get: { settings.falseTouchProtection },
                        set: { model.setFalseTouchProtection($0) }
                    )
                ) {
                    ForEach(FalseTouchProtection.allCases) { protection in
                        Text(protection.title).tag(protection)
                    }
                }
                .pickerStyle(.segmented)
                Text(falseTouchProtectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Haptic strength", selection: $settings.hapticStrength) {
                    ForEach(HapticStrength.allCases) { strength in
                        Text(strength.title).tag(strength)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!settings.hapticFeedback)
                Text("Light uses fewer subtle ticks; Standard preserves the original feel; Strong uses a firmer double pulse.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Picker(
                    "Trackpad",
                    selection: Binding(
                        get: { settings.trackpadPreference },
                        set: { model.setTrackpadPreference($0) }
                    )
                ) {
                    ForEach(TrackpadPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                Text("Automatic preserves the default-device behavior. Explicit external selection ignores portrait-oriented devices such as Magic Mouse.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Rescan Trackpads") {
                    model.rescanTrackpads()
                }
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

    private var falseTouchProtectionDescription: String {
        let protection = settings.falseTouchProtection
        let milliseconds = Int((protection.typingSuppressionInterval * 1_000).rounded())
        let leftPercent = protection.leftEntryStripWidth * 100
        let rightPercent = protection.rightEntryStripWidth * 100
        return String(
            format: "%dms after typing · %.1f%% left / %.1f%% right edge birth range",
            milliseconds,
            leftPercent,
            rightPercent
        )
    }

    @ViewBuilder
    private var touchStatusView: some View {
        switch model.touchStatus {
        case .stopped:
            Text("Stopped").foregroundStyle(.secondary)
        case let .running(kind):
            Label(kind.statusTitle, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case let .unavailable(message):
            Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        }
    }
}
