import CoreGraphics
import Foundation

@MainActor
final class CursorController {
    private(set) var isFrozen = false
    private let associate: @Sendable (Bool) -> CGError

    init(associate: @escaping @Sendable (Bool) -> CGError = { CGAssociateMouseAndMouseCursorPosition($0 ? 1 : 0) }) {
        self.associate = associate
    }

    @discardableResult
    func freeze() -> Bool {
        guard !isFrozen else { return true }
        let result = associate(false)
        isFrozen = result == .success
        return isFrozen
    }

    func restore() {
        guard isFrozen else { return }
        _ = associate(true)
        isFrozen = false
    }

    deinit {
        if isFrozen {
            _ = associate(true)
        }
    }
}

