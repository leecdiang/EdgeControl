import AppKit
import Darwin
import Foundation
import OSLog

enum SingleInstanceError: Error, Equatable, LocalizedError {
    case directoryCreationFailed(String)
    case openFailed(Int32)
    case lockFailed(Int32)

    var errorDescription: String? {
        switch self {
        case let .directoryCreationFailed(path):
            return "The EdgeControl application support directory could not be created: \(path)."
        case let .openFailed(code):
            return "The EdgeControl instance lock could not be opened (errno \(code))."
        case let .lockFailed(code):
            return "The EdgeControl instance lock could not be acquired (errno \(code))."
        }
    }
}

enum SingleInstanceAcquireResult: Equatable {
    case primary
    case duplicate
    case failed(SingleInstanceError)
}

/// Owns a user-level advisory lock for the lifetime of the primary process.
/// The lock file may remain after a crash; only flock state determines ownership.
final class SingleInstanceCoordinator {
    let lockURL: URL

    let bundleIdentifier: String
    private let retryBudget: TimeInterval
    private let retryIntervalMicroseconds: useconds_t
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.edgecontrol.EdgeControl", category: "SingleInstance")
    private var lockFileDescriptor: Int32 = -1

    init(
        lockURL: URL? = nil,
        bundleIdentifier: String? = nil,
        retryBudget: TimeInterval = 0.75,
        retryIntervalMicroseconds: useconds_t = 50_000
    ) {
        let defaultDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("EdgeControl", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("EdgeControl", isDirectory: true)
        self.lockURL = lockURL ?? defaultDirectory.appendingPathComponent("instance.lock")
        self.bundleIdentifier = bundleIdentifier ?? Bundle.main.bundleIdentifier ?? "org.edgecontrol.EdgeControl"
        self.retryBudget = max(0, retryBudget)
        self.retryIntervalMicroseconds = retryIntervalMicroseconds
    }

    var isPrimary: Bool { lockFileDescriptor >= 0 }

    func acquire() -> SingleInstanceAcquireResult {
        if isPrimary { return .primary }

        do {
            try FileManager.default.createDirectory(
                at: lockURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create lock directory at \(self.lockURL.deletingLastPathComponent().path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .failed(.directoryCreationFailed(lockURL.deletingLastPathComponent().path))
        }

        let descriptor = Darwin.open(lockURL.path, O_RDWR | O_CREAT, mode_t(S_IRUSR | S_IWUSR))
        guard descriptor >= 0 else {
            let code = errno
            logger.error("Failed to open instance lock errno=\(code, privacy: .public)")
            return .failed(.openFailed(code))
        }

        let deadline = Date().timeIntervalSinceReferenceDate + retryBudget
        while true {
            if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
                lockFileDescriptor = descriptor
                let version = Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "Development"
                logger.notice("Primary instance acquired pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public) bundle=\(self.bundleIdentifier, privacy: .public) version=\(version, privacy: .public) path=\(Bundle.main.bundleURL.path, privacy: .public)")
                return .primary
            }

            let code = errno
            guard code == EWOULDBLOCK || code == EAGAIN else {
                _ = Darwin.close(descriptor)
                logger.error("Failed to flock instance lock errno=\(code, privacy: .public)")
                return .failed(.lockFailed(code))
            }

            if Date().timeIntervalSinceReferenceDate >= deadline {
                _ = Darwin.close(descriptor)
                logDuplicateLaunch()
                return .duplicate
            }
            usleep(retryIntervalMicroseconds)
        }
    }

    func release() {
        guard lockFileDescriptor >= 0 else { return }
        _ = flock(lockFileDescriptor, LOCK_UN)
        _ = Darwin.close(lockFileDescriptor)
        lockFileDescriptor = -1
        logger.notice("Primary instance released lock")
    }

    deinit {
        release()
    }

    private func logDuplicateLaunch() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }
        let existing = running.prefix(4).map { app in
            "pid=\(app.processIdentifier) path=\(app.bundleURL?.path ?? "unknown")"
        }.joined(separator: ", ")
        let argumentCount = max(0, CommandLine.arguments.count - 1)
        logger.notice("Duplicate launch exited pid=\(currentPID, privacy: .public) bundle=\(self.bundleIdentifier, privacy: .public) existingCount=\(running.count, privacy: .public) existingSample=[\(existing, privacy: .public)] argumentCount=\(argumentCount, privacy: .public)")
    }
}
