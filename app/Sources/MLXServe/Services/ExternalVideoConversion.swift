import Foundation

/// The engine's MJPEG AVI advertises playback support on macOS but fails actual
/// frame decoding. Convert in an owned process, then publish the completed MP4.
struct ExternalVideoConversion {
    let executable: URL
    let source: URL
    var stagedOutput: URL { source.deletingPathExtension().appendingPathExtension("mp4") }

    static var installedExecutable: URL? {
        #if MAS_BUILD
        return nil
        #else
        let override = ProcessInfo.processInfo.environment["MLX_SERVE_FFMPEG_PATH"]
        return (override.map { [$0] } ?? ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"])
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
        #endif
    }

    var arguments: [String] {
        ["-nostdin", "-hide_banner", "-loglevel", "error", "-n", "-i", source.path,
         "-map", "0:v:0", "-map", "0:a:0?", "-c:v", "libx264", "-preset", "fast",
         "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", stagedOutput.path]
    }
}
