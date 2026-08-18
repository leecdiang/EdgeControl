import AppKit
import Foundation
import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var model: EdgeControlAppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            controlsPage
                .tabItem { Label("Controls", systemImage: "slider.vertical.3") }

            feedbackPage
                .tabItem { Label("Feedback", systemImage: "waveform") }

            devicesPage
                .tabItem { Label("Devices", systemImage: "trackpad") }

            aboutPage
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(.top, 8)
        .frame(minWidth: 520, minHeight: 430)
    }

    private var controlsPage: some View {
        settingsScrollView {
            SettingsCard(title: "Edge controls", systemImage: "rectangle.split.2x1") {
                SettingsRow(title: "Enable EdgeControl", detail: "Pause every edge action without changing your setup.") {
                    Toggle("Enable EdgeControl", isOn: $settings.masterEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider()

                SettingsRow(title: "Left edge") {
                    actionPicker(selection: $settings.leftEdgeAction)
                }

                SettingsRow(title: "Right edge") {
                    actionPicker(selection: $settings.rightEdgeAction)
                }

                Divider()

                HStack(spacing: 16) {
                    Toggle("Volume", isOn: $settings.volumeEnabled)
                    Toggle("Brightness", isOn: $settings.brightnessEnabled)
                    Spacer(minLength: 0)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            SettingsCard(title: "Response", systemImage: "speedometer") {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Adjustment speed")
                        .font(.system(size: 12, weight: .medium))
                    Picker("Adjustment speed", selection: $settings.adjustmentSpeed) {
                        ForEach(AdjustmentSpeed.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    Text("Changes value gain only; gesture activation rules stay fixed.")
                        .settingsCaption()
                }

                Divider()

                VStack(alignment: .leading, spacing: 7) {
                    Text("False-touch protection")
                        .font(.system(size: 12, weight: .medium))
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
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    Text(falseTouchProtectionDescription)
                        .settingsCaption()
                }
            }
        }
    }

    private var feedbackPage: some View {
        settingsScrollView {
            SettingsCard(title: "Haptics", systemImage: "waveform") {
                SettingsRow(title: "Haptic feedback", detail: "Acknowledge activation and value detents.") {
                    Toggle("Haptic feedback", isOn: $settings.hapticFeedback)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider()

                VStack(alignment: .leading, spacing: 7) {
                    Text("Strength")
                        .font(.system(size: 12, weight: .medium))
                    Picker("Haptic strength", selection: $settings.hapticStrength) {
                        ForEach(HapticStrength.allCases) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .disabled(!settings.hapticFeedback)
                    Text("Light is sparse, Standard preserves the original feel, and Strong uses a firmer double pulse.")
                        .settingsCaption()
                }
            }

            SettingsCard(title: "HUD", systemImage: "rectangle.inset.filled") {
                SettingsRow(title: "Show HUD", detail: "Display a compact value overlay while adjusting.") {
                    Toggle("Show HUD", isOn: $settings.showHUD)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider()

                VStack(alignment: .leading, spacing: 9) {
                    Text("Color style")
                        .font(.system(size: 12, weight: .medium))
                    Picker("HUD color style", selection: $settings.hudColorStyle) {
                        ForEach(HUDColorStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .disabled(!settings.showHUD)

                    HUDPalettePreview(style: settings.hudColorStyle)
                        .opacity(settings.showHUD ? 1 : 0.45)

                    Text("System stays neutral; Classic uses blue and amber; Aurora uses violet and teal.")
                        .settingsCaption()
                }
            }
        }
    }

    private var devicesPage: some View {
        settingsScrollView {
            SettingsCard(title: "Trackpad", systemImage: "trackpad") {
                SettingsRow(title: "Input source") {
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
                    .labelsHidden()
                    .frame(width: 220)
                }

                Divider()

                SettingsRow(title: "Touch input") {
                    touchStatusView
                }

                HStack {
                    Text("Connect or disconnect a device, then rescan.")
                        .settingsCaption()
                    Spacer(minLength: 8)
                    Button("Rescan Trackpads") {
                        model.rescanTrackpads()
                    }
                }
            }

            SettingsCard(title: "Gesture admission", systemImage: "hand.point.up.left") {
                SettingsRow(
                    title: "Start in lower half only",
                    detail: "Reject contacts born above the trackpad midline. Adjustment remains relative to the current value."
                ) {
                    Toggle(
                        "Start in lower half only",
                        isOn: Binding(
                            get: { settings.lowerHalfOnly },
                            set: { model.setLowerHalfOnly($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            SettingsCard(title: "External display", systemImage: "display") {
                SettingsRow(
                    title: "DDC brightness",
                    detail: "Experimental and used only when no controllable built-in display is available."
                ) {
                    Toggle(
                        "External display DDC",
                        isOn: Binding(
                            get: { settings.externalDDCEnabled },
                            set: { model.setExternalDDCEnabled($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            SettingsCard(title: "Startup", systemImage: "power") {
                SettingsRow(title: "Launch at login") {
                    Toggle(
                        "Launch at login",
                        isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.08))
                    }
            }
        }
    }

    private var aboutPage: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)

            VStack(spacing: 4) {
                Text("EdgeControl")
                    .font(.system(size: 22, weight: .bold))
                Text("Version \(appVersion)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("Two edges. Two controls. Nothing else.")
                .font(.system(size: 13, weight: .medium))

            Divider()
                .frame(maxWidth: 300)

            VStack(spacing: 5) {
                Text("Open source · No analytics · No network · No account")
                Text("By leecdiang")
                Text("Uses undocumented macOS interfaces and is not affiliated with Apple Inc.")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func settingsScrollView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity)
        }
    }

    private func actionPicker(selection: Binding<EdgeAction>) -> some View {
        Picker("Edge action", selection: selection) {
            ForEach(EdgeAction.allCases) { action in
                Label(action.title, systemImage: action.systemImage).tag(action)
            }
        }
        .labelsHidden()
        .frame(width: 180)
    }

    private var falseTouchProtectionDescription: String {
        let protection = settings.falseTouchProtection
        let milliseconds = Int((protection.typingSuppressionInterval * 1_000).rounded())
        let leftPercent = protection.leftEntryStripWidth * 100
        let rightPercent = protection.rightEntryStripWidth * 100
        return String(
            format: "%dms after typing · %.1f%% left / %.1f%% right birth range",
            milliseconds,
            leftPercent,
            rightPercent
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.6.0"
    }

    @ViewBuilder
    private var touchStatusView: some View {
        switch model.touchStatus {
        case .stopped:
            Label("Stopped", systemImage: "pause.circle.fill")
                .foregroundStyle(.secondary)
        case let .running(kind):
            Label(kind.statusTitle, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .unavailable(message):
            Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.78))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 0.6)
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String?
    private let control: Control

    init(
        title: String,
        detail: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(alignment: detail == nil ? .center : .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if let detail {
                    Text(detail)
                        .settingsCaption()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)
            control
        }
    }
}

private struct HUDPalettePreview: View {
    let style: HUDColorStyle

    var body: some View {
        HStack(spacing: 14) {
            previewItem(title: "Volume", symbol: "speaker.wave.2.fill", kind: .volume)
            previewItem(title: "Brightness", symbol: "sun.max.fill", kind: .brightness)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.6)
        }
    }

    private func previewItem(title: String, symbol: String, kind: HUDKind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.12))
                Capsule()
                    .fill(accentColor(for: kind).opacity(0.90))
                    .frame(width: 34)
            }
            .frame(width: 52, height: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title) color preview"))
    }

    private func accentColor(for kind: HUDKind) -> Color {
        switch (style, kind) {
        case (.system, _): return .primary
        case (.classic, .volume): return Color(nsColor: NSColor.systemBlue)
        case (.classic, .brightness): return Color(nsColor: NSColor.systemOrange)
        case (.aurora, .volume): return Color(nsColor: NSColor.systemPurple)
        case (.aurora, .brightness): return Color(nsColor: NSColor.systemTeal)
        }
    }
}

private extension View {
    func settingsCaption() -> some View {
        font(.system(size: 10.5))
            .foregroundStyle(.secondary)
    }
}
