import XCTest
@testable import MLXCore

final class ExternalGGUFTests: XCTestCase {
    func testPublishedLTXHeader() throws {
        guard let path = ProcessInfo.processInfo.environment["TEST_LTX_HEADER"] else { throw XCTSkip("No published header supplied") }
        XCTAssertTrue(ExternalGGUF.isLTX25(at: URL(fileURLWithPath: path)))
        if let path = ProcessInfo.processInfo.environment["TEST_LTX_UNCENSORED_HEADER"] {
            XCTAssertTrue(ExternalGGUF.isLTX25(at: URL(fileURLWithPath: path)))
        }
    }

    private func u32(_ n: UInt32) -> Data { withUnsafeBytes(of: n.littleEndian) { Data($0) } }
    private func u64(_ n: UInt64) -> Data { withUnsafeBytes(of: n.littleEndian) { Data($0) } }
    private func string(_ s: String) -> Data { let bytes = Data(s.utf8); return u64(UInt64(bytes.count)) + bytes }
    private func field(_ key: String, _ value: String) -> Data { string(key) + u32(8) + string(value) }
    private func header(_ architecture: String, _ version: String) -> Data {
        Data("GGUF".utf8) + u32(3) + u64(0) + u64(2) + field("general.architecture", architecture) + field("model_version", version)
    }

    func testIdentifiesLTX25FromMetadataRatherThanFilename() {
        XCTAssertTrue(ExternalGGUF.isLTX25(header("ltxv", "2.5.0")))
        XCTAssertFalse(ExternalGGUF.isLTX25(header("ltxv", "2.3.0")))
        XCTAssertFalse(ExternalGGUF.isLTX25(header("llama", "2.5.0")))
    }

    func testDiscoveryDoesNotOfferLTXVideoAsChat() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("arbitrary-Q4.gguf")
        try header("ltxv", "2.5.0").write(to: url)
        let file = try FileHandle(forWritingTo: url)
        try file.truncate(atOffset: 1_000_000)
        try file.close()
        let models = DownloadManager.makeLocalModels(atDir: dir.path, displayName: "Video", idKey: "video", source: .mlxServe)
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models.first?.modelType, "external_ltx25")
        XCTAssertEqual(models.first?.isChatPickable, false)
    }

    func testDiscoveryFindsVideoInDistilledFolder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let nested = dir.appendingPathComponent("distilled")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let url = nested.appendingPathComponent("video-Q4.gguf")
        try header("ltxv", "2.5.0").write(to: url)
        let file = try FileHandle(forWritingTo: url)
        try file.truncate(atOffset: 1_000_000)
        try file.close()
        let models = DownloadManager.makeLocalModels(atDir: dir.path, displayName: "Video", idKey: "video", source: .mlxServe)
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models.first?.path, url.path)
        XCTAssertEqual(models.first?.modelType, "external_ltx25")
    }

    func testDiscoveryFindsSplitDiffusionModels() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let nested = dir.appendingPathComponent("split/diffusion_models")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let url = nested.appendingPathComponent("video-Q4.gguf")
        try header("ltxv", "2.5.0").write(to: url)
        let file = try FileHandle(forWritingTo: url)
        try file.truncate(atOffset: 1_000_000)
        try file.close()
        let models = DownloadManager.makeLocalModels(atDir: dir.path, displayName: "Video", idKey: "video", source: .mlxServe)
        XCTAssertEqual(models.first?.path, url.path)
        XCTAssertEqual(models.first?.modelType, "external_ltx25")
    }

    func testTruncatedAndMalformedHeadersAreRejected() {
        XCTAssertFalse(ExternalGGUF.isLTX25(Data("GGUF".utf8)))
        XCTAssertFalse(ExternalGGUF.isLTX25(Data(repeating: 255, count: 100)))
        XCTAssertFalse(ExternalGGUF.isLTX25(header("ltxv", "2.5.0").dropLast()))
    }
}
