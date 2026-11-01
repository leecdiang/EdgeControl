import CoreGraphics
import Foundation

@MainActor
final class CursorController {
    private(set) var isFrozen = false
    private let associate: @Sendable (Int32) -> CGError

    init(associate: @escaping @Sendable (Int32) -> CGError = { CGAssociateMouseAndMouseCursorPosition($0) }) {
        self.associate = associate
    }

    @discardableResult
    func freeze() -> Bool {
        guard !isFrozen else { return true }
        let result = associate(0)
        isFrozen = result == .success
        return isFrozen
    }

    func restore() {
        guard isFrozen else { return }
        _ = associate(1)
        isFrozen = false
    }

    deinit {
        if isFrozen {
            _ = associate(1)
        }
    }
}

