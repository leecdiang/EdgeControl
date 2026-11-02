import AppKit
import Foundation
import SwiftUI

@MainActor
struct SettingsView: View {
    enum Page: String, CaseIterable, Identifiable {
        case gestures, feedback, general
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .gestures: return "hand.draw"
            case .feedback: return "waveform"
            case .general: return "gearshape"
            }
        }
    }
    @ObservedObject var model: EdgeControlAppModel
    @ObservedObject var settings: AppSettings
    @State private var selectedPage: Page
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(model: EdgeControlAppModel, settings: AppSettings, initialPage: Page = .gestures) {
        self.model = model
        self.settings = settings
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EdgeControl").font(.system(size: 22, weight: .semibold))
                Spacer()
                Toggle("Enabled", isOn: $settings.masterEnabled)
                    .toggleStyle(.switch).controlSize(.small)
            }
            .padding(.horizontal, 24).padding(.top, 38).padding(.bottom, 16)

            HStack(spacing: 6) {
                ForEach(Page.allCases) { page in
                    Button { selectedPage = page } label: {
                        Label(page.title, systemImage: page.icon)
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(selectedPage == page ? Color.primary.opacity(0.09) : .clear,
                                        in: Capsule())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedPage == page ? .isSelected : [])
                }
            }
            .padding(4)
            .modifier(EdgeNavigationGlass())
            .padding(.horizontal, 24).padding(.bottom, 14)
            // Only the selected page exists: hidden controls cannot retain focus.
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedPage {
                    case .gestures: gesturesPage
                    case .feedback: feedbackPage
                    case .general: generalPage
                    }
                }.padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 24).frame(maxWidth: .infinity)
            }.id(selectedPage)
        }
        .frame(minWidth: 560, minHeight: 540)
        // The AppKit window already supplies active behind-window vibrancy.
        // An opaque SwiftUI background here would hide it completely.
        .background(Color(nsColor: .windowBackgroundColor).opacity(reduceTransparency ? 1 : 0.08))
    }

    private var gesturesPage: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Edge actions", systemImage: "rectangle.split.2x1") {
                HStack(spacing: 20) {
                    TrackpadGuide(left: settings.leftEdgeAction, right: settings.rightEdgeAction,
                                  lowerHalfOnly: settings.lowerHalfOnly).frame(width: 150)
                    VStack(spacing: 14) {
                        SettingsRow(title: "Left edge") { actionPicker("Left edge", selection: $settings.leftEdgeAction) }
                        Divider()
                        SettingsRow(title: "Right edge") { actionPicker("Right edge", selection: $settings.rightEdgeAction) }
                    }
                }
            }
            .help("Start at an edge, then slide up or down.")
            SettingsCard(title: "Gesture feel", systemImage: "slider.horizontal.3") {
                Text("Speed").font(.system(size: 13, weight: .medium))
                Picker("Adjustment speed", selection: $settings.adjustmentSpeed) {
                    ForEach(AdjustmentSpeed.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().pickerStyle(.segmented)
                .help("How much the value changes as you slide.")
                Divider()
                Text("Touch protection").font(.system(size: 13, weight: .medium))
                Picker("Accidental-touch protection", selection: Binding(
                    get: { settings.falseTouchProtection }, set: { model.setFalseTouchProtection($0) })) {
                    ForEach(FalseTouchProtection.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().pickerStyle(.segmented)
                .help("Stronger protection narrows the starting area and waits longer after typing.")
                Divider()
                SettingsRow(title: "Lower half only") {
                    Toggle("Start in lower half only", isOn: Binding(get: { settings.lowerHalfOnly }, set: { model.setLowerHalfOnly($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
            DisclosureGroup("Trackpad") {
              VStack(spacing: 10) {
                SettingsRow(title: "Input source") {
                    Picker("Input source", selection: Binding(get: { settings.trackpadPreference }, set: { model.setTrackpadPreference($0) })) {
                        ForEach(TrackpadPreference.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 210)
                }
                HStack {
                    touchStatus
                    Spacer()
                    Button("Rescan") { model.rescanTrackpads() }
                }
              }.padding(.top, 10)
            }
            .font(.system(size: 12)).padding(.horizontal, 4)
        }
    }

    private var feedbackPage: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "HUD", systemImage: "rectangle.inset.filled") {
                Picker("HUD style", selection: $settings.hudMode) {
                    ForEach(HUDMode.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().pickerStyle(.segmented)
                HUDStylePreview(mode: settings.hudMode, style: settings.hudColorStyle)
                    .frame(height: 100)
                Text(hudDescription).settingsCaption()
                HStack {
                    Button { model.previewHUD(kind: .volume) } label: { Label("Volume", systemImage: "speaker.wave.2") }
                    Button { model.previewHUD(kind: .brightness) } label: { Label("Brightness", systemImage: "sun.max") }
                    Spacer()
                }.modifier(EdgePreviewButtonStyle()).disabled(!settings.showHUD)
                    .help("Preview only — volume and brightness stay unchanged.")
                DisclosureGroup("Color") {
                        Picker("HUD color style", selection: $settings.hudColorStyle) {
                            ForEach(HUDColorStyle.allCases) { Text($0.title).tag($0) }
                        }.labelsHidden().pickerStyle(.segmented).padding(.top, 8)
                }.disabled(!settings.showHUD)
            }
            SettingsCard(title: "Haptics", systemImage: "waveform") {
                SettingsRow(title: "Enabled") {
                    Toggle("Haptic feedback", isOn: $settings.hapticFeedback).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                Picker("Haptic feel", selection: $settings.hapticStrength) {
                    ForEach(HapticStrength.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).disabled(!settings.hapticFeedback)
                HStack {
                    Spacer()
                    Button("Try haptic") { model.previewHaptics() }.disabled(!settings.hapticFeedback)
                        .modifier(EdgePreviewButtonStyle())
                        .help("Keep a finger on the trackpad to feel the preview.")
                }
            }
        }
    }

    private var generalPage: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Startup & updates", systemImage: "arrow.clockwise") {
                SettingsRow(title: "Launch at login") {
                    Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                if model.launchAtLoginNeedsApproval {
                    Button("Open Login Items to approve") { model.openLoginItemsSettings() }
                }
                Divider()
                SettingsRow(title: "Automatic updates") {
                    Toggle("Check for updates automatically", isOn: Binding(get: { model.automaticallyChecksForUpdates }, set: { model.setAutomaticallyChecksForUpdates($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                HStack {
                    Spacer()
                    Button("Check now") { model.checkForUpdates() }.help("Check GitHub for a new version.")
                }
            }
            SettingsCard(title: "External display", systemImage: "display") {
                SettingsRow(title: "DDC brightness", detail: "Experimental · external displays") {
                    Toggle("Enable DDC brightness", isOn: Binding(get: { settings.externalDDCEnabled }, set: { model.setExternalDDCEnabled($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
            .help("Used when a controllable built-in display is unavailable.")
            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled)
            }
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                Text("EdgeControl · \(appVersion)").font(.system(size: 14, weight: .semibold))
                Link("Source & support ↗", destination: URL(string: "https://github.com/leecdiang/EdgeControl")!)
            }.font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
    }

    private var hudDescription: String {
        switch settings.hudMode {
        case .capsule: return "Bottom of screen"
        case .notch: return "At the notch · top capsule on other displays"
        case .off: return "Hides this HUD. Does not activate Alcove."
        }
    }

    private func actionPicker(_ title: String, selection: Binding<EdgeAction>) -> some View {
        Picker(title, selection: selection) {
            ForEach(EdgeAction.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
        }.labelsHidden().frame(width: 180)
    }
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }
    @ViewBuilder private var touchStatus: some View {
        switch model.touchStatus {
        case .stopped: Label("Stopped", systemImage: "pause.circle").foregroundStyle(.secondary)
        case let .running(kind): Label(kind.statusTitle, systemImage: "checkmark.circle").foregroundStyle(.green)
        case .unavailable: Label("Unavailable", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        }
    }
}

private struct TrackpadGuide: View {
    let left: EdgeAction
    let right: EdgeAction
    let lowerHalfOnly: Bool
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.primary.opacity(0.035))
                RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                HStack {
                    strip(enabled: left != .disabled)
                    Spacer()
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 16, weight: .light)).foregroundStyle(.tertiary)
                    Spacer()
                    strip(enabled: right != .disabled)
                }.padding(7)
            }.frame(width: 150, height: 96)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Left edge: \(left.title). Right edge: \(right.title). \(lowerHalfOnly ? "Start in the lower half." : "Start anywhere along an edge.")")
    }
    private func strip(enabled: Bool) -> some View {
        VStack(spacing: 0) {
            if lowerHalfOnly { Spacer(minLength: 0) }
            Capsule().fill(enabled ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.12))
                .frame(width: 5, height: lowerHalfOnly ? 38 : 76)
        }.frame(height: 82)
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
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
                    .font(.system(size: 13, weight: .medium))
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

struct HUDPalettePreview: View {
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
                    .fill(HUDPalette.accent(style: style, kind: kind).opacity(0.90))
                    .frame(width: 34)
            }
            .frame(width: 52, height: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title) color preview"))
    }

}

private extension View {
    func settingsCaption() -> some View {
        font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
}
