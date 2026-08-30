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
    static let compactWidth: CGFloat = 144
    static let errorWidth: CGFloat = 212
    static let height: CGFloat = 40
    static let progressWidth: CGFloat = 58
    static let progressHeight: CGFloat = 5
    static let shadowPadding: CGFloat = 16

    static func size(for presentation: HUDPresentation) -> NSSize {
        NSSize(
            width: (presentation.value == nil ? errorWidth : compactWidth) + shadowPadding * 2,
            height: height + shadowPadding * 2
        )
    }

    static let initialPanelSize = NSSize(
        width: compactWidth + shadowPadding * 2,
        height: height + shadowPadding * 2
    )
}

struct HUDPresentationPlan: Equatable, Sendable {
    let isNewPresentation: Bool
    let shouldResize: Bool
    let shouldPosition: Bool
    let shouldOrderFront: Bool
}

struct HUDPresentationLifecycle: Equatable, Sendable {
    private(set) var isVisible = false
    private(set) var currentSize: NSSize?
    private(set) var currentScreenID: UInt64?
    private(set) var presentCount = 0
    private(set) var updateCount = 0
    private(set) var dismissCount = 0

    mutating func plan(size: NSSize, screenID: UInt64?) -> HUDPresentationPlan {
        let isNewPresentation = !isVisible
        let shouldResize = currentSize != size
        let shouldPosition = isNewPresentation || shouldResize || currentScreenID != screenID

        if isNewPresentation {
            presentCount += 1
        } else {
            updateCount += 1
        }
        isVisible = true
        currentSize = size
        currentScreenID = screenID

        return HUDPresentationPlan(
            isNewPresentation: isNewPresentation,
            shouldResize: shouldResize,
            shouldPosition: shouldPosition,
            shouldOrderFront: isNewPresentation
        )
    }

    mutating func markHidden() {
        guard isVisible else { return }
        isVisible = false
        dismissCount += 1
    }

    mutating func updateScreenID(_ screenID: UInt64?) {
        currentScreenID = screenID
    }
}

@MainActor
private final class HUDViewModel: ObservableObject {
    @Published var presentation = HUDPresentation(kind: .volume, value: 0, message: nil)
    @Published var isPresented = false
    @Published var colorStyle: HUDColorStyle = .system
}

@MainActor
final class HUDController {
    private let panel: NSPanel
    private let viewModel: HUDViewModel
    private var dismissTask: Task<Void, Never>?
    private var lifecycle = HUDPresentationLifecycle()

    private(set) var colorStyle: HUDColorStyle = .system
    private(set) var debugMetrics = HUDDebugMetrics()

    struct HUDDebugMetrics: Equatable, Sendable {
        var presentCount = 0
        var updateCount = 0
        var dismissCount = 0
        var orderFrontCount = 0
        var positionCount = 0
        var resizeCount = 0
    }

    func setColorStyle(_ style: HUDColorStyle) {
        guard colorStyle != style else { return }
        colorStyle = style
        withTransaction(Transaction(animation: nil)) {
            viewModel.colorStyle = style
        }
    }

    init() {
        let viewModel = HUDViewModel()
        self.viewModel = viewModel
        panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: HUDLayout.initialPanelSize.width,
                height: HUDLayout.initialPanelSize.height
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
        let requiredSize = HUDLayout.size(for: presentation)
        let activeScreen = currentScreen()
        let plan = lifecycle.plan(size: requiredSize, screenID: activeScreen.id)

        withTransaction(Transaction(animation: nil)) {
            viewModel.presentation = presentation
            if plan.isNewPresentation {
                viewModel.isPresented = false
            }
        }

        if plan.isNewPresentation {
            panel.appearance = NSApp.effectiveAppearance
        }
        if plan.shouldResize {
            panel.setContentSize(requiredSize)
            debugMetrics.resizeCount += 1
        }
        if plan.shouldPosition {
            positionPanel(on: activeScreen.screen)
            debugMetrics.positionCount += 1
        }
        if plan.shouldOrderFront {
            panel.orderFrontRegardless()
            debugMetrics.orderFrontCount += 1
        }

        debugMetrics.presentCount = lifecycle.presentCount
        debugMetrics.updateCount = lifecycle.updateCount
        if plan.isNewPresentation {
            Task { @MainActor [weak viewModel] in
                await Task.yield()
                viewModel?.isPresented = true
            }
        } else {
            withTransaction(Transaction(animation: nil)) {
                viewModel.isPresented = true
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
            withTransaction(Transaction(animation: nil)) {
                self.viewModel.isPresented = false
            }
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self.panel.orderOut(nil)
            self.lifecycle.markHidden()
            self.debugMetrics.dismissCount = self.lifecycle.dismissCount
        }
    }

    func hideImmediately() {
        dismissTask?.cancel()
        withTransaction(Transaction(animation: nil)) {
            viewModel.isPresented = false
        }
        panel.orderOut(nil)
        lifecycle.markHidden()
        debugMetrics.dismissCount = lifecycle.dismissCount
    }

    func refreshPositionIfNeeded() {
        guard lifecycle.isVisible else { return }
        let activeScreen = currentScreen()
        guard activeScreen.id != lifecycle.currentScreenID else { return }
        lifecycle.updateScreenID(activeScreen.id)
        positionPanel(on: activeScreen.screen)
        debugMetrics.positionCount += 1
    }

    private func currentScreen() -> (screen: NSScreen?, id: UInt64?) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let numberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let id = (screen?.deviceDescription[numberKey] as? NSNumber)?.uint64Value
        return (screen, id)
    }

    private func positionPanel(on screen: NSScreen?) {
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
            .scaleEffect(model.isPresented || reduceMotion ? 1 : 0.96)
            .opacity(model.isPresented ? 1 : 0)
            .animation(
                reduceMotion ? .linear(duration: 0.10) : .easeOut(duration: 0.12),
                value: model.isPresented
            )
            // Keep the visible capsule compact while reserving transparent
            // window space for its soft shadow; NSPanel clips outside bounds.
            .frame(
                width: width + HUDLayout.shadowPadding * 2,
                height: HUDLayout.height + HUDLayout.shadowPadding * 2
            )
    }

    @ViewBuilder
    private var content: some View {
        if let value = model.presentation.value {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 15)

                EdgeHUDProgress(value: value, tint: accentColor)

                Text("\(Int((clamped(value) * 100).rounded()))%")
                    .monospacedDigit()
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 31, alignment: .trailing)
            }
            .padding(.horizontal, 10)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 15)

                Text(model.presentation.message ?? "Unavailable")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
        }
    }

    private var width: CGFloat {
        model.presentation.value == nil ? HUDLayout.errorWidth : HUDLayout.compactWidth
    }

    private var accentColor: Color {
        HUDPalette.accent(style: model.colorStyle, kind: model.presentation.kind)
    }

    private var glassTint: Color {
        // Keep the glass neutral in every palette so color is concentrated in
        // the progress indicator and the system blur remains visually clean.
        HUDPalette.glassTint(for: model.presentation)
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
        content
            .background {
                Group {
                    if reduceTransparency {
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor))
                    } else {
                        ZStack {
                            CapsuleVisualEffect()
                            Capsule()
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(EdgeUITheme.hudNeutralVeilOpacity))
                            Capsule()
                                .fill(tint)
                        }
                        // Clip the AppKit backdrop itself. A plain SwiftUI
                        // Material in a transparent panel can leak a faint
                        // rectangular plate outside the capsule.
                        .clipShape(Capsule())
                    }
                }
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(reduceTransparency ? 0.10 : 0.24),
                                .primary.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.65
                    )
            }
            .shadow(
                color: .black.opacity(reduceTransparency ? 0.10 : 0.18),
                radius: 11,
                y: 4
            )
            .shadow(
                color: .black.opacity(reduceTransparency ? 0.04 : 0.08),
                radius: 2,
                y: 1
            )
    }
}

/// NSVisualEffectView produces a real behind-window blur on macOS 13+.
/// Layer clipping is repeated here and in SwiftUI so the window server never
/// composites the rectangular backdrop that the previous Material attempt
/// exposed on light wallpapers.
private final class CapsuleVisualEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = bounds.height / 2
        layer?.masksToBounds = true
    }
}

private struct CapsuleVisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = CapsuleVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = .active
        nsView.needsLayout = true
    }
}
