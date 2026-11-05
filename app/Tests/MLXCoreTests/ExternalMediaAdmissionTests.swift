import XCTest
@testable import MLXCore

final class ExternalMediaAdmissionTests: XCTestCase {
    func testRejectsUnknownLoadingAndResidentNativeModels() {
        let resident = ModelInfo(name: "local", quantBits: 4, layers: 0, hiddenSize: 0, vocabSize: 0, contextLength: 0, modelMaxTokens: 0, loaded: true)
        XCTAssertTrue(ServerManager.externalMediaMayStart(status: .stopped, models: nil, loading: false))
        XCTAssertFalse(ServerManager.externalMediaMayStart(status: .starting, models: nil, loading: false))
        XCTAssertFalse(ServerManager.externalMediaMayStart(status: .running, models: nil, loading: false))
        XCTAssertFalse(ServerManager.externalMediaMayStart(status: .running, models: [], loading: true))
        XCTAssertFalse(ServerManager.externalMediaMayStart(status: .running, models: [resident], loading: false))
        XCTAssertTrue(ServerManager.externalMediaMayStart(status: .running, models: [], loading: false))
    }

    func testLocalChatWaitsForExternalMediaButRemoteChatCanContinue() {
        XCTAssertFalse(ServerManager.externalMediaAllowsChat(reserved: true, local: true))
        XCTAssertTrue(ServerManager.externalMediaAllowsChat(reserved: true, local: false))
        XCTAssertTrue(ServerManager.externalMediaAllowsChat(reserved: false, local: true))
    }

    func testMediaMemoryEstimateFailsClosedAndIncludesHeadroom() {
        let gib: UInt64 = 1 << 30
        XCTAssertNil(ExternalMediaMemory.requiredBytes(weightBytes: 0))
        XCTAssertNil(ExternalMediaMemory.requiredBytes(weightBytes: UInt64.max))
        XCTAssertEqual(ExternalMediaMemory.requiredBytes(weightBytes: 4 * gib), 6 * gib)
        XCTAssertEqual(ExternalMediaMemory.requiredBytes(weightBytes: 24 * gib), 30 * gib)
        XCTAssertFalse(ExternalMediaMemory.hasEnough(available: 0, required: 6 * gib))
        XCTAssertFalse(ExternalMediaMemory.hasEnough(available: 5 * gib, required: 6 * gib))
        XCTAssertTrue(ExternalMediaMemory.hasEnough(available: 6 * gib, required: 6 * gib))
    }

    func testWeightSizeFollowsSymlinksWithoutCountingSamePathTwice() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("weights")
        let link = root.appendingPathComponent("alias")
        try Data(repeating: 1, count: 12).write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertEqual(ExternalMediaMemory.weightBytes(for: [file, link]), 12)
        XCTAssertNil(ExternalMediaMemory.weightBytes(for: [file, root.appendingPathComponent("missing")]))
        XCTAssertNil(ExternalMediaMemory.weightBytes(for: []))
    }
}
