import Foundation

@MainActor
final class ExternalMediaRuntime {
    enum RuntimeError: LocalizedError {
        case missingEngine, outputExists, missingOutput
        var errorDescription: String? {
            switch self {
            case .missingEngine: return "The media engine is not installed."
            case .outputExists: return "The output file already exists. Choose another name."
            case .missingOutput: return "The media engine did not produce an output file."
            }
        }
    }

    private let executable: URL
    private static let process = ManagedMediaProcess()
    private var process: ManagedMediaProcess { Self.process }
    private var ownsProcess = false
    var isRunning: Bool { ownsProcess && process.isRunning }

    init(executable: URL) { self.executable = executable }

    func run(arguments: [String], expectedOutput: URL, onProgress: (@MainActor (String) -> Void)? = nil) async throws {
        let files = FileManager.default
        guard files.isExecutableFile(atPath: executable.path) else { throw RuntimeError.missingEngine }
        guard !files.fileExists(atPath: expectedOutput.path) else { throw RuntimeError.outputExists }
        guard !process.isRunning else { throw ManagedMediaProcess.RunError.busy }
        ownsProcess = true
        defer { ownsProcess = false }
        _ = try await process.run(executable: executable, arguments: arguments, onProgress: onProgress)
        try Task.checkCancellation()
        let attributes = try? files.attributesOfItem(atPath: expectedOutput.path)
        guard attributes?[.type] as? FileAttributeType == .typeRegular,
              let size = attributes?[.size] as? NSNumber, size.int64Value > 0 else { throw RuntimeError.missingOutput }
    }

    func stop() { if ownsProcess { process.stop() } }
}
