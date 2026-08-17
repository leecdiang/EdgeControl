import CoreGraphics
import Foundation

/// Privacy-preserving typing guard. It asks Quartz only for elapsed time since
/// the last key-down event; it never installs an event tap or reads key values.
struct RecentKeyboardActivityGuard {
    typealias ElapsedTimeProvider = () -> TimeInterval

    private let elapsedSinceLastKeyDown: ElapsedTimeProvider

    init(
        elapsedSinceLastKeyDown: @escaping ElapsedTimeProvider = {
            CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: .keyDown
            )
        }
    ) {
        self.elapsedSinceLastKeyDown = elapsedSinceLastKeyDown
    }

    func shouldBlock(for suppressionInterval: TimeInterval) -> Bool {
        // Invalid configuration fails open. Gesture-level birth, corridor,
        // directionality, lower-half and multi-touch guards remain active.
        guard suppressionInterval.isFinite, suppressionInterval > 0 else { return false }
        let elapsed = elapsedSinceLastKeyDown()
        // Fail open if Quartz ever returns an invalid sentinel. Gesture-level
        // palm, corridor, directionality and multi-touch guards still apply.
        guard elapsed.isFinite, elapsed >= 0 else { return false }
        return elapsed < suppressionInterval
    }
}
