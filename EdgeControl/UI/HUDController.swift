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
    static let compactWidth: CGFloat = 180
    static let errorWidth: CGFloat = 252
    static let height: CGFloat = 40
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

/// Pure point-based geometry. No model-name tables or pixel assumptions.
struct HUDScreenGeometry: Equatable {
    let frame: NSRect
    let visibleFrame: NSRect
    let safeTop: CGFloat
    let leftArea: NSRect?
    let rightArea: NSRect?
}

struct HUDPlacement: Equatable {
    let frame: NSRect
    let contentWidth: CGFloat
    let cutoutHeight: CGFloat
    var attachedToNotch: Bool { cutoutHeight > 0 }

    static func resolve(mode: HUDMode, screen: HUDScreenGeometry, error: Bool = false) -> HUDPlacement {
        let requestedWidth: CGFloat = error ? 252 : 180
        let usable = screen.visibleFrame.intersection(screen.frame)
        let safe = usable.isEmpty ? screen.frame : usable
        if mode == .notch, screen.safeTop > 0, screen.safeTop < 200,
           let left = screen.leftArea, let right = screen.rightArea,
           left.width > 0, right.width > 0, left.maxX < right.minX,
           left.minX >= screen.frame.minX, right.maxX <= screen.frame.maxX,
           right.minX - left.maxX < screen.frame.width / 2 {
            let gap = right.minX - left.maxX
            let width = min(max(requestedWidth, gap + 32), screen.frame.width - 32)
            let size = NSSize(width: width + 32, height: screen.safeTop + 40 + 16)
            let center = (left.maxX + right.minX) / 2
            let x = min(max(center - size.width / 2, screen.frame.minX), screen.frame.maxX - size.width)
            return HUDPlacement(frame: NSRect(x: x, y: screen.frame.maxY - size.height,
                                              width: size.width, height: size.height),
                                contentWidth: width, cutoutHeight: screen.safeTop)
        }
        let width = min(error ? 252 : 180, max(80, safe.width - 32))
        let size = NSSize(width: width + 32, height: 72)
        let y = mode == .notch ? safe.maxY - size.height - 8 : safe.minY + safe.height * 0.16
        return HUDPlacement(frame: NSRect(x: safe.midX - size.width / 2,
                                          y: min(max(y, safe.minY), max(safe.minY, safe.maxY - size.height)),
                                          width: size.width, height: size.height),
                            contentWidth: width, cutoutHeight: 0)
    }
}

struct HUDScreenSelection {
    static func resolve(available: [UInt64], preferred: UInt64?, pinned: UInt64?, pointer: UInt64?) -> UInt64? {
        [preferred, pinned, pointer].compactMap { $0 }.first(where: available.contains) ?? available.first
    }
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
    private(set) var currentScreenFrame: NSRect?
    private(set) var presentCount = 0
    private(set) var updateCount = 0
    private(set) var dismissCount = 0

    mutating func plan(
        size: NSSize,
        screenID: UInt64?,
        screenFrame: NSRect? = nil
    ) -> HUDPresentationPlan {
        let isNewPresentation = !isVisible
        let shouldResize = currentSize != size
        // Screen IDs survive resolution and arrangement changes, so the usable
        // frame must participate in placement too.
        let shouldPosition = isNewPresentation
            || shouldResize
            || currentScreenID != screenID
            || currentScreenFrame != screenFrame

        if isNewPresentation {
            presentCount += 1
        } else {
            updateCount += 1
        }
        isVisible = true
        currentSize = size
        currentScreenID = screenID
        currentScreenFrame = screenFrame

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

    mutating func updateScreenFrame(_ frame: NSRect?, screenID: UInt64?) {
        currentScreenID = screenID
        currentScreenFrame = frame
    }
}

@MainActor
private final class HUDViewModel: ObservableObject {
    @Published var presentation = HUDPresentation(kind: .volume, value: 0, message: nil)
    @Published var isPresented = false
    @Published var colorStyle: HUDColorStyle = .system
    @Published var cutoutHeight: CGFloat = 0
    @Published var surfaceWidth: CGFloat = 180
}

@MainActor
final class HUDController {
    private let panel: NSPanel
    private let viewModel: HUDViewModel
    private var dismissTask: Task<Void, Never>?
    private var lifecycle = HUDPresentationLifecycle()
    private var pinnedScreenID: UInt64?
    private var lastPresentation: HUDPresentation?
    private var mode: HUDMode = .capsule

    func setMode(_ mode: HUDMode) {
        guard self.mode != mode else { return }
        hideImmediately()
        self.mode = mode
    }

    func beginGesture(displayID: UInt32? = nil) {
        pinnedScreenID = displayID.map(UInt64.init)
        pinnedScreenID = currentScreen().id
    }

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

    func show(_ presentation: HUDPresentation, preferredDisplayID: UInt32? = nil) {
        guard mode != .off else { return }
        if let preferredDisplayID { pinnedScreenID = UInt64(preferredDisplayID) }
        dismissTask?.cancel()
        lastPresentation = presentation
        let activeScreen = currentScreen()
        guard let screen = activeScreen.screen else { return }
        let placement = placement(on: screen, presentation: presentation)
        let requiredSize = placement.frame.size
        pinnedScreenID = activeScreen.id
        let plan = lifecycle.plan(
            size: requiredSize,
            screenID: activeScreen.id,
            screenFrame: placement.frame
        )

        withTransaction(Transaction(animation: nil)) {
            viewModel.presentation = presentation
            viewModel.cutoutHeight = placement.cutoutHeight
            viewModel.surfaceWidth = placement.contentWidth
            if plan.isNewPresentation {
                viewModel.isPresented = false
            }
        }

        panel.appearance = placement.attachedToNotch ? NSAppearance(named: .darkAqua) : NSApp.effectiveAppearance
        panel.level = placement.attachedToNotch ? .statusBar : .floating
        if plan.shouldResize {
            panel.setContentSize(requiredSize)
            debugMetrics.resizeCount += 1
        }
        if plan.shouldPosition {
            panel.setFrame(placement.frame, display: true)
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
        pinnedScreenID = nil
        lastPresentation = nil
        debugMetrics.dismissCount = lifecycle.dismissCount
    }

    func refreshPositionIfNeeded() {
        guard lifecycle.isVisible, let presentation = lastPresentation,
              let screen = currentScreen().screen else { return }
        let placement = placement(on: screen, presentation: presentation)
        // Geometry can change even if the display ID is unchanged.
        guard panel.frame != placement.frame || viewModel.cutoutHeight != placement.cutoutHeight else { return }
        withTransaction(Transaction(animation: nil)) {
            viewModel.cutoutHeight = placement.cutoutHeight
            viewModel.surfaceWidth = placement.contentWidth
        }
        panel.level = placement.attachedToNotch ? .statusBar : .floating
        panel.appearance = placement.attachedToNotch ? NSAppearance(named: .darkAqua) : NSApp.effectiveAppearance
        panel.setFrame(placement.frame, display: true)
        let id = screenID(screen)
        pinnedScreenID = id
        lifecycle.updateScreenFrame(placement.frame, screenID: id)
        debugMetrics.positionCount += 1
    }

    private func screenID(_ screen: NSScreen) -> UInt64? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint64Value
    }

    private func currentScreen() -> (screen: NSScreen?, id: UInt64?) {
        let screens = NSScreen.screens
        let pointer = screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        let id = HUDScreenSelection.resolve(available: screens.compactMap(screenID), preferred: nil,
                                             pinned: pinnedScreenID, pointer: pointer.flatMap(screenID))
        return (screens.first { screenID($0) == id }, id)
    }

    private func placement(on screen: NSScreen, presentation: HUDPresentation) -> HUDPlacement {
        HUDPlacement.resolve(mode: mode,
            screen: HUDScreenGeometry(frame: screen.frame, visibleFrame: screen.visibleFrame,
                safeTop: screen.safeAreaInsets.top, leftArea: screen.auxiliaryTopLeftArea,
                rightArea: screen.auxiliaryTopRightArea), error: presentation.value == nil)
    }

}

@MainActor
private struct EdgeHUDView: View {
    @ObservedObject var model: HUDViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        surface
            .scaleEffect(model.isPresented || reduceMotion ? 1 : 0.97, anchor: model.cutoutHeight > 0 ? .top : .center)
            .opacity(model.isPresented ? 1 : 0)
            .animation(reduceMotion ? .linear(duration: 0.10) : .easeOut(duration: 0.14), value: model.isPresented)
            .frame(width: width + 32, height: 40 + model.cutoutHeight + (model.cutoutHeight > 0 ? 16 : 32),
                   alignment: model.cutoutHeight > 0 ? .top : .center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.presentation.kind == .volume ? "Volume" : "Brightness")
            .accessibilityValue(model.presentation.value.map { "\(Int((clamped($0) * 100).rounded())) percent" } ?? model.presentation.message ?? "Unavailable")
    }

    @ViewBuilder private var surface: some View {
        if model.cutoutHeight > 0 {
            content
                .frame(width: width, height: 40)
                .padding(.top, model.cutoutHeight)
                .background(AttachedHUDShape().fill(.black))
                .environment(\.colorScheme, .dark)
        } else {
            content.frame(width: width, height: 40)
                .modifier(EdgeHUDGlassModifier(tint: glassTint, reduceTransparency: reduceTransparency))
        }
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
                    .frame(maxWidth: .infinity)

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
        model.surfaceWidth
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
        .frame(height: HUDLayout.progressHeight)
        .transaction { $0.animation = nil }
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

private struct AttachedHUDShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = min(18, rect.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Uses the same native HUD view as the live panel; preview values never write hardware.
@MainActor
struct HUDStylePreview: View {
    let mode: HUDMode
    let style: HUDColorStyle
    @StateObject private var model = HUDViewModel()
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(0.035))
            if mode == .off {
                Label("No EdgeControl overlay", systemImage: "eye.slash")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                EdgeHUDView(model: model)
            }
        }
        .onAppear { update() }
        .onChange(of: mode) { _ in update() }
        .onChange(of: style) { _ in update() }
    }
    private func update() {
        model.presentation = HUDPresentation(kind: .volume, value: 0.62, message: nil)
        model.colorStyle = style
        model.cutoutHeight = mode == .notch ? 20 : 0
        model.surfaceWidth = mode == .notch ? 220 : 180
        model.isPresented = true
    }
}
