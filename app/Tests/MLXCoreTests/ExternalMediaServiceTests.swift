import XCTest
@testable import MLXCore

@MainActor
final class ExternalMediaServiceTests: XCTestCase {
    func testEnoughMemoryAllowsTheManagedProcessToRun() async throws {
        guard SystemMetrics.availableForModelBytes() > 0 else { throw XCTSkip("Memory statistics unavailable on this host") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input")
        let output = root.appendingPathComponent("output")
        try Data("result".utf8).write(to: input)
        let service = ExternalMediaService()
        let server = ServerManager()
        service.start(kind: .image, executable: URL(fileURLWithPath: "/bin/cp"), arguments: [input.path, output.path], output: output, server: server, minimumFreeBytes: 1)
        for _ in 0..<100 where service.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(service.resultURL, output)
        XCTAssertEqual(try Data(contentsOf: output), Data("result".utf8))
    }
    func testInsufficientMemoryStopsBeforeLaunchingAndReleasesReservation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input")
        let output = root.appendingPathComponent("output")
        try Data("result".utf8).write(to: input)
        let service = ExternalMediaService()
        let server = ServerManager()
        service.start(kind: .image, executable: URL(fileURLWithPath: "/bin/cp"), arguments: [input.path, output.path], output: output, server: server, minimumFreeBytes: UInt64.max)
        for _ in 0..<100 where service.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(service.isRunning)
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertTrue(service.message.contains("memory"))
        XCTAssertTrue(server.reserveExternalMedia())
        server.releaseExternalMedia()
    }
    func testNativeModelLoadingIsBlockedWhileExternalJobOwnsMemory() async throws {
        let server = ServerManager()
        XCTAssertTrue(server.reserveExternalMedia())
        XCTAssertFalse(server.reserveExternalMedia())
        do {
            _ = try await server.loadModel(id: "unused")
            XCTFail("Native model loading must be blocked during external media work")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("media"))
        }
        server.releaseExternalMedia()
        XCTAssertTrue(server.reserveExternalMedia())
        server.releaseExternalMedia()
    }
    func testServiceKeepsResultIndependentOfTheView() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input")
        let output = root.appendingPathComponent("output")
        try Data("result".utf8).write(to: input)
        let service = ExternalMediaService()
        let server = ServerManager()
        service.start(kind: .image, executable: URL(fileURLWithPath: "/bin/cp"), arguments: [input.path, output.path], output: output, server: server)
        XCTAssertTrue(service.isRunning)
        XCTAssertFalse(server.reserveExternalMedia())
        for _ in 0..<100 where service.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.resultURL, output)
        XCTAssertEqual(service.kind, .image)
        XCTAssertEqual(try Data(contentsOf: output), Data("result".utf8))
        XCTAssertTrue(server.reserveExternalMedia())
        server.releaseExternalMedia()
    }
}
