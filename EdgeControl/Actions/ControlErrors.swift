import Foundation

enum ControlError: LocalizedError, Equatable {
    case unavailable(String)
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case let .unavailable(message), let .readFailed(message), let .writeFailed(message):
            return message
        }
    }
}

