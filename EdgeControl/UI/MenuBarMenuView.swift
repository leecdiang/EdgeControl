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
        VStack(spacing: 11) {
            header

            HStack(spacing: 8) {
                EdgeActionCard(
                    title: "Left edge",
                    selection: $settings.leftEdgeAction
                )
                EdgeActionCard(
                    title: "Right edge",
                    selection: $settings.rightEdgeAction
                )
            }

            HStack(spacing: 8) {
                QuickToggle(
                    title: "Haptic",
                    systemImage: "waveform",
                    isOn: $settings.hapticFeedback
                )
                QuickToggle(
                    title: "HUD",
                    systemImage: "rectangle.inset.filled",
                    isOn: $settings.showHUD
                )
                QuickToggle(
                    title: "Login",
                    systemImage: "power",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }

            if let warningText {
                Label(warningText, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    model.openSettings()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.primary.opacity(0.045))
                    }
                    .contentShape(Rectangle())
                }
                .keyboardShortcut(",")
                .buttonStyle(.plain)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 34, height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.primary.opacity(0.045))
                        }
                        .contentShape(Rectangle())
                }
                .keyboardShortcut("q")
                .buttonStyle(.plain)
                .help("Quit EdgeControl")
            }
        }
        .padding(14)
        .frame(width: 304)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.primary.opacity(0.075))
                Image(systemName: "slider.vertical.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("EdgeControl")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusTitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Toggle("Enabled", isOn: $settings.masterEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(settings.masterEnabled ? "Disable EdgeControl" : "Enable EdgeControl")
        }
    }

    private var statusTitle: String {
        guard settings.masterEnabled else { return "Paused" }
        switch model.touchStatus {
        case .stopped:
            return "Stopped"
        case let .running(kind):
            return "\(kind.statusTitle) trackpad"
        case .unavailable:
            return "Touch unavailable"
        }
    }

    private var statusColor: Color {
        guard settings.masterEnabled else { return .secondary }
        switch model.touchStatus {
        case .running: return .green
        case .stopped: return .secondary
        case .unavailable: return .orange
        }
    }

    private var warningText: String? {
        if case let .unavailable(message) = model.touchStatus {
            return message
        }
        return model.lastError
    }
}

@MainActor
private struct EdgeActionCard: View {
    let title: String
    @Binding var selection: EdgeAction

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Menu {
                ForEach(EdgeAction.allCases) { action in
                    Button {
                        selection = action
                    } label: {
                        if action == selection {
                            Label(action.title, systemImage: "checkmark")
                        } else {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selection.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(actionColor)
                        .frame(width: 15)
                    Text(selection.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 0.6)
        }
    }

    private var actionColor: Color {
        switch selection {
        case .disabled: return .secondary
        case .volume: return Color(nsColor: NSColor.systemBlue)
        case .brightness: return Color(nsColor: NSColor.systemOrange)
        }
    }
}

@MainActor
private struct QuickToggle: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background {
                Capsule()
                    .fill(isOn ? Color.accentColor.opacity(0.085) : Color.primary.opacity(0.035))
            }
            .overlay {
                Capsule()
                    .strokeBorder(.primary.opacity(0.07), lineWidth: 0.6)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}
