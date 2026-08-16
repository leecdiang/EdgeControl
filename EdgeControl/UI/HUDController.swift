import AppKit
import SwiftUI

enum HUDKind: Sendable, Equatable {
    case volume
    case brightness
}

struct HUDPresentation: Sendable {
    let kind: HUDKind
    let value: Double?
    let message: String?
}

@MainActor
final class HUDController {
    private let panel: NSPanel
    private var dismissTask: Task<Void, Never>?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 230, height: 116),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
    }

    func show(_ presentation: HUDPresentation) {
        dismissTask?.cancel()
        panel.contentView = NSHostingView(rootView: EdgeHUDView(presentation: presentation))
        positionPanel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled, let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                self.panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor in self?.panel.orderOut(nil) }
            }
        }
    }

    func hideImmediately() {
        dismissTask?.cancel()
        panel.orderOut(nil)
    }

    private func positionPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.minY + visibleFrame.height * 0.18
        )
        panel.setFrameOrigin(origin)
    }
}

@MainActor
private struct EdgeHUDView: View {
    let presentation: HUDPresentation

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let value = presentation.value {
                    Text("\(Int((value * 100).rounded()))%")
                        .monospacedDigit()
                        .font(.system(size: 14, weight: .medium))
                }
            }

            if let value = presentation.value {
                ProgressView(value: value)
                    .progressViewStyle(.linear)
            } else {
                Text(presentation.message ?? "Unavailable")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }
        }
        .padding(18)
        .foregroundStyle(.primary)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        )
        .frame(width: 230, height: 116)
    }

    private var title: String {
        presentation.kind == .volume ? "Volume" : "Brightness"
    }

    private var symbolName: String {
        guard let value = presentation.value else { return "exclamationmark.triangle.fill" }
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
}
