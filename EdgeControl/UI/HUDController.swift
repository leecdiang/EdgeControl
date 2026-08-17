import AppKit
import Combine
import SwiftUI

enum HUDKind: Sendable, Equatable {
    case volume
    case brightness
}

struct HUDPresentation: Sendable, Equatable {
    let kind: HUDKind
    let value: Double?
    let message: String?
}

private enum HUDLayout {
    static let compactWidth: CGFloat = 148
    static let errorWidth: CGFloat = 220
    static let height: CGFloat = 42
    static let progressWidth: CGFloat = 60
    static let progressHeight: CGFloat = 4

    static func size(for presentation: HUDPresentation) -> NSSize {
        NSSize(
            width: presentation.value == nil ? errorWidth : compactWidth,
            height: height
        )
    }
}

@MainActor
private final class HUDViewModel: ObservableObject {
    @Published var presentation = HUDPresentation(kind: .volume, value: 0, message: nil)
    @Published var isPresented = false
    @Published var colorfulHUD = false
}

@MainActor
final class HUDController {
    private let panel: NSPanel
    private let viewModel: HUDViewModel
    private var dismissTask: Task<Void, Never>?

    var colorfulHUD: Bool = false {
        didSet { viewModel.colorfulHUD = colorfulHUD }
    }

    init() {
        let viewModel = HUDViewModel()
        self.viewModel = viewModel
        panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: HUDLayout.compactWidth,
                height: HUDLayout.height
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        let hostingView = NSHostingView(rootView: EdgeHUDView(model: viewModel))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.isOpaque = false
    }

    func show(_ presentation: HUDPresentation) {
        dismissTask?.cancel()
        let wasVisible = panel.isVisible
        if !wasVisible {
            viewModel.isPresented = false
        }
        viewModel.presentation = presentation
        panel.setContentSize(HUDLayout.size(for: presentation))
        positionPanel()
        panel.orderFrontRegardless()

        if wasVisible {
            viewModel.isPresented = true
        } else {
            Task { @MainActor [weak viewModel] in
                await Task.yield()
                viewModel?.isPresented = true
            }
        }

        let visibleNanoseconds: UInt64 = presentation.value == nil
            ? 1_500_000_000
            : 650_000_000
        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: visibleNanoseconds)
            } catch {
                return
            }
            guard let self else { return }
            self.viewModel.isPresented = false
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self.panel.orderOut(nil)
        }
    }

    func hideImmediately() {
        dismissTask?.cancel()
        viewModel.isPresented = false
        panel.orderOut(nil)
    }

    private func positionPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.minY + visibleFrame.height * 0.16
        )
        panel.setFrameOrigin(origin)
    }
}

@MainActor
private struct EdgeHUDView: View {
    @ObservedObject var model: HUDViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        content
            .frame(width: width, height: HUDLayout.height)
            .modifier(
                EdgeHUDGlassModifier(
                    tint: glassTint,
                    reduceTransparency: reduceTransparency
                )
            )
            // Force the composited alpha mask to the capsule before shadowing.
            // This prevents a rectangular material backing from leaking into
            // the shadow shape on light backgrounds.
            .compositingGroup()
            .clipShape(Capsule())
            .scaleEffect(model.isPresented || reduceMotion ? 1 : 0.96)
            .opacity(model.isPresented ? 1 : 0)
            .animation(
                reduceMotion ? .linear(duration: 0.10) : .easeOut(duration: 0.12),
                value: model.isPresented
            )
    }

    @ViewBuilder
    private var content: some View {
        if let value = model.presentation.value {
            HStack(spacing: 7) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                EdgeHUDProgress(value: value, tint: accentColor)

                Text("\(Int((clamped(value) * 100).rounded()))%")
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 11)
        } else {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.colorfulHUD ? .orange : .primary)
                    .frame(width: 16)

                Text(model.presentation.message ?? "Unavailable")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
        }
    }

    private var width: CGFloat {
        model.presentation.value == nil ? HUDLayout.errorWidth : HUDLayout.compactWidth
    }

    private var accentColor: Color {
        guard model.colorfulHUD else { return .primary }
        switch model.presentation.kind {
        case .volume: return .cyan
        case .brightness: return .yellow
        }
    }

    private var glassTint: Color {
        guard model.colorfulHUD else { return .primary.opacity(0.06) }
        if model.presentation.value == nil {
            return .orange.opacity(0.10)
        }
        return accentColor.opacity(0.08)
    }

    private var symbolName: String {
        guard let value = model.presentation.value else {
            return "exclamationmark.triangle.fill"
        }
        switch model.presentation.kind {
        case .brightness:
            return "sun.max.fill"
        case .volume:
            if value == 0 { return "speaker.slash.fill" }
            if value < 0.34 { return "speaker.wave.1.fill" }
            if value < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        }
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

private struct EdgeHUDProgress: View {
    let value: Double
    let tint: Color

    private var clampedValue: Double {
        min(1, max(0, value))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.14))
                Capsule()
                    .fill(tint.opacity(0.88))
                    .frame(width: geometry.size.width * CGFloat(clampedValue))
            }
        }
        .frame(width: HUDLayout.progressWidth, height: HUDLayout.progressHeight)
        .animation(.easeOut(duration: 0.08), value: clampedValue)
        .accessibilityHidden(true)
    }
}

private struct EdgeHUDGlassModifier: ViewModifier {
    let tint: Color
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        // Avoid material backdrops in HUD windows: on some light backgrounds
        // they can leak a rectangular ambient plate behind rounded content.
        // Use a deterministic capsule fill in both accessibility modes.
        opaqueBackground(content)
    }

    private func opaqueBackground(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    Capsule()
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(reduceTransparency ? 1.0 : 0.84))
                    Capsule()
                        .fill(tint.opacity(reduceTransparency ? 0 : 0.16))
                }
                .shadow(
                    color: .black.opacity(reduceTransparency ? 0.10 : 0.16),
                    radius: 10,
                    y: 4
                )
                .shadow(
                    color: .black.opacity(reduceTransparency ? 0.04 : 0.08),
                    radius: 2,
                    y: 1
                )
            }
            .overlay(
                Capsule()
                    .strokeBorder(.primary.opacity(0.16), lineWidth: 0.5)
            )
    }
}
