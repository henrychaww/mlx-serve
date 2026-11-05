import Foundation
import Combine

@MainActor
final class ExternalMediaService: ObservableObject {
    enum Kind { case image, video }

    @Published private(set) var isRunning = false
    @Published private(set) var message = ""
    @Published private(set) var progressText = ""
    @Published private(set) var resultURL: URL?
    @Published private(set) var kind: Kind?
    private var task: Task<Void, Never>?
    private var runtime: ExternalMediaRuntime?

    func start(kind: Kind, executable: URL, arguments: [String], output: URL, server: ServerManager, minimumFreeBytes: UInt64 = 0) {
        guard !isRunning else { return }
        self.kind = kind
        resultURL = nil
        guard server.reserveExternalMedia() else {
            message = "Another model is loading or a media job is already running."
            return
        }
        isRunning = true
        message = ""
        progressText = "Working…"
        task = Task {
            defer { server.releaseExternalMedia(); runtime = nil; isRunning = false; progressText = ""; task = nil }
            do {
                try Task.checkCancellation()
                guard await server.canStartExternalMedia() else {
                    message = "The server is busy or its memory state is unavailable. Unload local models and try again."
                    return
                }
                if minimumFreeBytes > 0,
                   !ExternalMediaMemory.hasEnough(available: SystemMetrics.availableForModelBytes(), required: minimumFreeBytes) {
                    message = "Not enough available memory for this model. Unload other models or close apps and try again."
                    return
                }
                try Task.checkCancellation()
                let engine = ExternalMediaRuntime(executable: executable)
                runtime = engine
                try await engine.run(arguments: arguments, expectedOutput: output) { self.progressText = $0 }
                resultURL = output
                message = kind == .image ? "Upscaling complete." : "Video complete."
            } catch {
                message = Task.isCancelled ? "Cancelled." : error.localizedDescription
            }
        }
    }

    func cancel() {
        task?.cancel()
        runtime?.stop()
    }
}
