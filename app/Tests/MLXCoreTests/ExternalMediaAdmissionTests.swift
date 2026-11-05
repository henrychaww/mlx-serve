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
}
