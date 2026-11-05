import Foundation
import AppKit

/// Owns one short-lived media engine process. Arguments are passed directly,
/// never through a shell; model paths stay in their existing locations.
@MainActor
final class ManagedMediaProcess {
    enum RunError: LocalizedError {
        case busy
        case failed(status: Int32, output: String)

        var errorDescription: String? {
            switch self {
            case .busy: return "A media engine is already running."
            case .failed(let status, let output): return "Media engine exited (\(status)): \(output)"
            }
        }
    }

    private var process: Process?
    private let notifications: NotificationCenter
    private var quitObserver: NSObjectProtocol?
    var isRunning: Bool { process != nil }

    init(notifications: NotificationCenter = .default) {
        self.notifications = notifications
        quitObserver = notifications.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    deinit {
        if let quitObserver { notifications.removeObserver(quitObserver) }
    }

    func run(executable: URL, arguments: [String]) async throws -> String {
        guard process == nil else { throw RunError.busy }
        try Task.checkCancellation()
        let logURL = FileManager.default.temporaryDirectory.appendingPathComponent("mlx-media-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? FileManager.default.removeItem(at: logURL) }
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }
        let child = Process()
        child.executableURL = executable
        child.arguments = arguments
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = log
        child.standardError = log
        process = child
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                child.terminationHandler = { finished in
                    Task { @MainActor in
                        self.process = nil
                        let output = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
                        if finished.terminationReason == .exit && finished.terminationStatus == 0 {
                            continuation.resume(returning: output)
                        } else {
                            continuation.resume(throwing: RunError.failed(status: finished.terminationStatus, output: output))
                        }
                    }
                }
                do { try child.run() } catch {
                    child.terminationHandler = nil
                    process = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            Task { @MainActor in
                if self.process === child { self.stop() }
            }
        }
    }

    func stop() {
        if let process, process.isRunning { process.terminate() }
    }
}
