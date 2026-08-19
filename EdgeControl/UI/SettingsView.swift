import AppKit
import Foundation
import SwiftUI

@MainActor
struct SettingsView: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case controls
        case feedback
        case devices
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .controls: return "Controls"
            case .feedback: return "Feedback"
            case .devices: return "Devices"
            case .about: return "About"
            }
        }

        var systemImage: String {
            switch self {
            case .controls: return "slider.vertical.3"
            case .feedback: return "waveform"
            case .devices: return "trackpad"
            case .about: return "info.circle"
            }
        }
    }

    @ObservedObject var model: EdgeControlAppModel
    @ObservedObject var settings: AppSettings
    @State private var selectedTab: SettingsTab = .controls
    @FocusState private var focusedTab: SettingsTab?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 18)
                // Keep the tab row clear of the traffic lights (the window
                // uses .fullSizeContentView) and give it its own top area.
                .padding(.top, 30)
                // A fixed, stable gap between the tab row and the content
                // cards: no divider touches the card edges.
                .padding(.bottom, 14)

            content
        }
        .frame(minWidth: 520, minHeight: 430)
    }

    /// Borderless tab row: four independent buttons with a capsule highlight
    /// on the selected one. Unlike a segmented control it has no enclosing
    /// border or inter-segment divider lines, so the tabs read as separate
    /// controls floating on the glass instead of labels straddling a line.
    /// Keyboard navigation stays native: Tab to focus a tab, arrow keys to
    /// move between tabs, Space to activate, VoiceOver sees per-tab labels.
    private var tabBar: some View {
        HStack(spacing: 5) {
            ForEach(SettingsTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 27)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // Native keyboard interaction: each tab is focusable, Tab moves
        // between tabs, Space activates. Arrow-key tab switching is left to
        // the system's focus engine (Full Keyboard Access) to avoid
        // auto-triggering moves when the window gains focus.
        .focusable()
        .focused($focusedTab, equals: tab)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(Text(tab.title))
    }

    /// All pages stay alive in a ZStack so each page keeps its scroll state,
    /// mirroring TabView behavior; only the selected page is interactive.
    private var content: some View {
        ZStack {
            controlsPage
                .opacity(selectedTab == .controls ? 1 : 0)
                .allowsHitTesting(selectedTab == .controls)
                .accessibilityHidden(selectedTab != .controls)
            feedbackPage
                .opacity(selectedTab == .feedback ? 1 : 0)
                .allowsHitTesting(selectedTab == .feedback)
                .accessibilityHidden(selectedTab != .feedback)
            devicesPage
                .opacity(selectedTab == .devices ? 1 : 0)
                .allowsHitTesting(selectedTab == .devices)
                .accessibilityHidden(selectedTab != .devices)
            aboutPage
                .opacity(selectedTab == .about ? 1 : 0)
                .allowsHitTesting(selectedTab == .about)
                .accessibilityHidden(selectedTab != .about)
        }
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

                    Text("System stays neutral; Classic uses blue and amber; Aurora uses violet and teal; Morandi uses muted slate blues.")
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.7.1"
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                // Slightly more solid than the window glass so cards read as a
                // distinct layer; near-opaque when Reduce Transparency is on.
                .fill(
                    Color(nsColor: .windowBackgroundColor)
                        .opacity(reduceTransparency ? 0.92 : 0.50)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 0.6)
        }
        // A soft shadow lifts the cards off the glass for depth without
        // adding any decorative gradient or glow.
        .shadow(color: .black.opacity(reduceTransparency ? 0.05 : 0.12), radius: 7, y: 2)
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
        case (.morandi, .volume):
            return Color(
                nsColor: NSColor(
                    srgbRed: 0.639, green: 0.757, blue: 0.871, alpha: 1
                )
            )
        case (.morandi, .brightness):
            return Color(
                nsColor: NSColor(
                    srgbRed: 0.624, green: 0.690, blue: 0.769, alpha: 1
                )
            )
        }
    }
}

private extension View {
    func settingsCaption() -> some View {
        font(.system(size: 10.5))
            .foregroundStyle(.secondary)
    }
}
