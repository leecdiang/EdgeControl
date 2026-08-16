import CoreGraphics
import Foundation

@MainActor
final class CursorController {
    private(set) var isFrozen = false

    @discardableResult
    func freeze() -> Bool {
        guard !isFrozen else { return true }
        let result = CGAssociateMouseAndMouseCursorPosition(0)
        isFrozen = result == .success
        return isFrozen
    }

    func restore() {
        guard isFrozen else { return }
        _ = CGAssociateMouseAndMouseCursorPosition(1)
        isFrozen = false
    }

    deinit {
        if isFrozen {
            _ = CGAssociateMouseAndMouseCursorPosition(1)
        }
    }
}

