import XCTest
@testable import MLXCore

@MainActor
final class ExternalMediaRuntimeTests: XCTestCase {
    func testUpscaleCommandRunsAndCreatesOutput() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let exe = dir.appendingPathComponent("mock-engine")
        let script = "#!/bin/sh\nwhile [ $# -gt 0 ]; do if [ \"$1\" = --output ]; then shift; printf result > \"$1\"; exit 0; fi; shift; done\nexit 2\n"
        try Data(script.utf8).write(to: exe)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)
        let output = dir.appendingPathComponent("output image.png")
        let args = try ExternalMediaCommand.seedVR2(model: "/model with spaces", input: "/input.png", output: output.path, scale: 2)
        try await ExternalMediaRuntime(executable: exe).run(arguments: args, expectedOutput: output)
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "result")
    }

    func testSuccessfulProcessWithoutOutputIsAnError() async throws {
        let runtime = ExternalMediaRuntime(executable: URL(fileURLWithPath: "/usr/bin/true"))
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try await runtime.run(arguments: [], expectedOutput: missing)
            XCTFail("A successful exit is not proof that media was produced")
        } catch ExternalMediaRuntime.RuntimeError.missingOutput {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testSuccessfulEngineProducesAResult() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("input.png")
        let output = dir.appendingPathComponent("output.png")
        try Data("fixture".utf8).write(to: input)
        let runtime = ExternalMediaRuntime(executable: URL(fileURLWithPath: "/bin/cp"))
        try await runtime.run(arguments: [input.path, output.path], expectedOutput: output)
        XCTAssertEqual(try Data(contentsOf: output), Data("fixture".utf8))
        XCTAssertEqual(try Data(contentsOf: input), Data("fixture".utf8))
    }

    func testDifferentRuntimesDoNotRunTogether() async throws {
        let first = ExternalMediaRuntime(executable: URL(fileURLWithPath: "/bin/sleep"))
        let second = ExternalMediaRuntime(executable: URL(fileURLWithPath: "/usr/bin/true"))
        let root = FileManager.default.temporaryDirectory
        let firstOutput = root.appendingPathComponent(UUID().uuidString)
        let secondOutput = root.appendingPathComponent(UUID().uuidString)
        let task = Task { try await first.run(arguments: ["30"], expectedOutput: firstOutput) }
        for _ in 0..<100 where !first.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(first.isRunning)
        do {
            try await second.run(arguments: [], expectedOutput: secondOutput)
            XCTFail("Only one external engine may use memory at a time")
        } catch ManagedMediaProcess.RunError.busy {} catch { XCTFail("Unexpected error: \(error)") }
        second.stop()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(first.isRunning, "A different runtime cannot stop the active job")
        first.stop()
        do { try await task.value; XCTFail("Stopped process succeeded") } catch {}
    }

    func testMissingEngineIsReported() async {
        let runtime = ExternalMediaRuntime(executable: URL(fileURLWithPath: "/not-an-engine"))
        do {
            try await runtime.run(arguments: [], expectedOutput: URL(fileURLWithPath: "/not-output"))
            XCTFail("Missing runtime must fail")
        } catch ExternalMediaRuntime.RuntimeError.missingEngine {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testExistingOutputIsNotOverwritten() async throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("original".utf8).write(to: output)
        defer { try? FileManager.default.removeItem(at: output) }
        let runtime = ExternalMediaRuntime(executable: URL(fileURLWithPath: "/usr/bin/true"))
        do {
            try await runtime.run(arguments: [], expectedOutput: output)
            XCTFail("Existing output must not count as a new result")
        } catch ExternalMediaRuntime.RuntimeError.outputExists {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "original")
    }
}
