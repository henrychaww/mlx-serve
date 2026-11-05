import XCTest

/// All video panes must use the macOS AVPlayerView workaround. SwiftUI's
/// VideoPlayer has crashed during state transitions on supported macOS versions.
final class VideoSurfaceTests: XCTestCase {
    func testVideoSurfacesUseTheSharedNativePlayer() throws {
        let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let views = app.appendingPathComponent("Sources/MLXServe/Views")
        let files = try FileManager.default.contentsOfDirectory(at: views, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 20)
        var nativeSurfaces = 0
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8).split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            XCTAssertNil(source.range(of: #"\bVideoPlayer\s*\("#, options: .regularExpression), file.lastPathComponent)
            if source.contains("AVPlayerViewRepresentable(player:") { nativeSurfaces += 1 }
        }
        XCTAssertGreaterThanOrEqual(nativeSurfaces, 3, "Native, external, and transcript video must share the player")
    }
}
