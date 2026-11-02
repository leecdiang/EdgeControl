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
    static let notchWingWidth: CGFloat = 88
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
    var cutoutWidth: CGFloat = 0
    var attachedToNotch: Bool { cutoutHeight > 0 }

    static func resolve(mode: HUDMode, screen: HUDScreenGeometry, error: Bool = false) -> HUDPlacement {
        let requestedWidth = error ? HUDLayout.errorWidth : HUDLayout.compactWidth
        let usable = screen.visibleFrame.intersection(screen.frame)
        let safe = usable.isEmpty ? screen.frame : usable
        if mode == .notch, !error, screen.safeTop >= 22, screen.safeTop < 200,
           let left = screen.leftArea, let right = screen.rightArea,
           left.width > 0, right.width > 0, left.maxX < right.minX,
           left.minX >= screen.frame.minX, right.maxX <= screen.frame.maxX,
           right.minX - left.maxX < screen.frame.width / 2,
           left.maxX - screen.frame.minX >= HUDLayout.notchWingWidth + 16,
           screen.frame.maxX - right.minX >= HUDLayout.notchWingWidth + 16 {
            let gap = right.minX - left.maxX
            // Separate wings leave the complete hardware cutout clear. Never
            // clamp the center away from the camera to fit an unusual screen.
            let width = gap + HUDLayout.notchWingWidth * 2
            let size = NSSize(width: width + 32, height: screen.safeTop + 16)
            let center = (left.maxX + right.minX) / 2
            let x = min(max(center - size.width / 2, screen.frame.minX), screen.frame.maxX - size.width)
            return HUDPlacement(frame: NSRect(x: x, y: screen.frame.maxY - size.height,
                                              width: size.width, height: size.height),
                                contentWidth: width, cutoutHeight: screen.safeTop, cutoutWidth: gap)
        }
        let width = min(requestedWidth, max(80, safe.width - 32))
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
    @Published var cutoutWidth: CGFloat = 0
    @Published var surfaceWidth: CGFloat = HUDLayout.compactWidth

    init(isPresented: Bool = false) {
        self.isPresented = isPresented
    }
}

@MainActor
final class HUDController {
    private let panel: NSPanel
    private let viewModel: HUDViewModel
    private var dismissTask: Task<Void, Never>?
    private var presentationTask: Task<Void, Never>?
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
        let hostingView = NSHostingView(rootView: LiveEdgeHUDView(model: viewModel))
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
            viewModel.cutoutWidth = placement.cutoutWidth
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
            presentationTask?.cancel()
            presentationTask = Task { @MainActor [weak viewModel] in
                await Task.yield()
                guard !Task.isCancelled else { return }
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
                // Let the critically damped outline settle before removing its
                // window. A new value cancels this wait and reverses in place.
                try await Task.sleep(nanoseconds: 650_000_000)
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
        presentationTask?.cancel()
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
            viewModel.cutoutWidth = placement.cutoutWidth
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
private struct LiveEdgeHUDView: View {
    @ObservedObject var model: HUDViewModel
    var body: some View {
        EdgeHUDView(presentation: model.presentation, isPresented: model.isPresented,
                    colorStyle: model.colorStyle, cutoutHeight: model.cutoutHeight,
                    surfaceWidth: model.surfaceWidth, cutoutWidth: model.cutoutWidth)
    }
}

@MainActor
struct EdgeHUDView: View {
    let presentation: HUDPresentation
    let isPresented: Bool
    let colorStyle: HUDColorStyle
    let cutoutHeight: CGFloat
    let surfaceWidth: CGFloat
    var cutoutWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        surface
            // Keep the attached silhouette flush with the real notch throughout
            // the transition; scaling it exposes a seam around the cutout.
            .scaleEffect(isPresented || reduceMotion || isNotch ? 1 : 0.96)
            .opacity(isPresented || (isNotch && !reduceMotion) ? 1 : 0)
            .animation(reduceMotion ? .linear(duration: 0.10)
                : (isNotch ? .spring(response: 0.32, dampingFraction: 1) : .easeOut(duration: 0.14)), value: isPresented)
            .frame(width: width + 32, height: contentHeight + (isNotch ? 16 : 32),
                   alignment: cutoutHeight > 0 ? .top : .center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.kind == .volume ? "Volume" : "Brightness")
            .accessibilityValue(presentation.value.map { "\(Int((clamped($0) * 100).rounded())) percent" } ?? presentation.message ?? "Unavailable")
    }

    @ViewBuilder private var surface: some View {
        if cutoutHeight > 0 {
            ZStack(alignment: .top) {
                AttachedHUDShape().fill(.black)
                    .frame(width: isPresented || reduceMotion ? width : cutoutWidth,
                           height: cutoutHeight)
                notchContent
                    .frame(width: width, height: cutoutHeight)
                    .opacity(isPresented ? 1 : 0)
                    .blur(radius: isPresented || reduceMotion ? 0 : 3)
                    .mask {
                        AttachedHUDShape()
                            .frame(width: isPresented || reduceMotion ? width : cutoutWidth,
                                   height: cutoutHeight)
                    }
            }
                .frame(width: width, height: cutoutHeight, alignment: .top)
                .environment(\.colorScheme, .dark)
        } else {
            content.frame(width: width, height: contentHeight)
                .modifier(EdgeHUDGlassModifier(tint: glassTint, reduceTransparency: reduceTransparency))
        }
    }

    private var notchContent: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 15)
                Text(presentation.kind == .volume ? "Sound" : "Display")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(width: HUDLayout.notchWingWidth)
            Color.clear.frame(width: cutoutWidth)
            EdgeHUDProgress(value: presentation.value ?? 0,
                            tint: colorStyle == .system ? .white : accentColor, height: 4)
                .frame(width: 62)
                .frame(width: HUDLayout.notchWingWidth)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let value = presentation.value {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: isNotch ? 11 : 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 15)

                EdgeHUDProgress(value: value, tint: accentColor, height: isNotch ? 3 : HUDLayout.progressHeight)
                    .frame(width: isNotch ? nil : HUDLayout.progressWidth)

                Text("\(Int((clamped(value) * 100).rounded()))%")
                    .monospacedDigit()
                    .font(.system(size: isNotch ? 10 : 11, weight: .semibold))
                    .frame(width: 31, alignment: .trailing)
            }
            .padding(.horizontal, 10)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 15)

                Text(presentation.message ?? "Unavailable")
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
        surfaceWidth
    }

    private var isNotch: Bool { cutoutHeight > 0 }
    private var contentHeight: CGFloat { isNotch ? cutoutHeight : HUDLayout.height }

    private var accentColor: Color {
        HUDPalette.accent(style: colorStyle, kind: presentation.kind)
    }

    private var glassTint: Color {
        // Keep the glass neutral in every palette so color is concentrated in
        // the progress indicator and the system blur remains visually clean.
        HUDPalette.glassTint(for: presentation)
    }

    private var symbolName: String {
        guard let value = presentation.value else {
            return "exclamationmark.triangle.fill"
        }
        switch presentation.kind {
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
    let height: CGFloat

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
        .frame(height: height)
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
        let r: CGFloat = min(10, rect.height / 2)
        let shoulder: CGFloat = min(6, rect.height / 4)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder),
                       control: CGPoint(x: rect.maxX - shoulder, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder - r, y: rect.maxY), control: CGPoint(x: rect.maxX - shoulder, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + shoulder + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - r), control: CGPoint(x: rect.minX + shoulder, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX + shoulder, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// No cached model or onChange synchronization: each selection renders its own
/// geometry in the same SwiftUI update as the picker label.
@MainActor
struct HUDStylePreview: View {
    let mode: HUDMode
    let style: HUDColorStyle

    static func placement(for mode: HUDMode) -> HUDPlacement {
        let geometry = HUDScreenGeometry(
            frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: NSRect(x: 0, y: 40, width: 1512, height: 910), safeTop: 32,
            leftArea: NSRect(x: 0, y: 950, width: 666, height: 32),
            rightArea: NSRect(x: 846, y: 950, width: 666, height: 32))
        return HUDPlacement.resolve(mode: mode, screen: geometry)
    }

    var body: some View {
        let placement = Self.placement(for: mode)
        ZStack(alignment: mode == .notch ? .top : .center) {
            RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(0.035))
            if mode == .off {
                Image(systemName: "eye.slash").foregroundStyle(.secondary)
                    .accessibilityLabel("HUD hidden")
            } else {
                EdgeHUDView(presentation: HUDPresentation(kind: .volume, value: 0.62, message: nil),
                            isPresented: true, colorStyle: style,
                            cutoutHeight: placement.cutoutHeight, surfaceWidth: placement.contentWidth,
                            cutoutWidth: placement.cutoutWidth)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("hud-preview-" + mode.rawValue)
    }
}
