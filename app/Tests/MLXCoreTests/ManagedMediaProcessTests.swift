import XCTest
import AppKit
@testable import MLXCore

@MainActor
final class ManagedMediaProcessTests: XCTestCase {
    func testInstalledMediaEnginesStartOnDemand() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let mlx = env["TEST_MLXGEN"], let video = env["TEST_SDCLI"] else {
            throw XCTSkip("Engine paths are not set for this integration test")
        }
        let runner = ManagedMediaProcess()
        let upscalerHelp = try await runner.run(executable: URL(fileURLWithPath: mlx), arguments: ["upscale", "--help"])
        XCTAssertTrue(upscalerHelp.contains("--image-path"))
        let videoHelp = try await runner.run(executable: URL(fileURLWithPath: video), arguments: ["--help"])
        XCTAssertTrue(videoHelp.contains("--audio-vae"))
        XCTAssertFalse(runner.isRunning)
    }

    func testRunsExecutableAndReturnsOutput() async throws {
        let runner = ManagedMediaProcess()
        let output = try await runner.run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: ["hello world"])
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
        XCTAssertFalse(runner.isRunning)
    }

    func testAppQuitStopsTheOwnedProcess() async throws {
        let notifications = NotificationCenter()
        let runner = ManagedMediaProcess(notifications: notifications)
        let task = Task { try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"]) }
        for _ in 0..<100 where !runner.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(runner.isRunning)
        notifications.post(name: NSApplication.willTerminateNotification, object: nil)
        do { _ = try await task.value; XCTFail("The child must stop when the app quits") } catch {}
        XCTAssertFalse(runner.isRunning)
    }

    func testNonzeroExitReportsDiagnostic() async {
        let runner = ManagedMediaProcess()
        do {
            _ = try await runner.run(executable: URL(fileURLWithPath: "/usr/bin/false"), arguments: [])
            XCTFail("A failing engine must not appear successful")
        } catch {
            XCTAssertFalse(runner.isRunning)
        }
    }

    func testRejectsConcurrentRunAndStopsOwnedProcess() async throws {
        let runner = ManagedMediaProcess()
        let first = Task { try await runner.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"]) }
        for _ in 0..<100 where !runner.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(runner.isRunning)
        do {
            _ = try await runner.run(executable: URL(fileURLWithPath: "/bin/echo"), arguments: ["second"])
            XCTFail("An engine is already running")
        } catch ManagedMediaProcess.RunError.busy {} catch { XCTFail("Unexpected error: \(error)") }
        runner.stop()
        do { _ = try await first.value; XCTFail("Stopped process succeeded") } catch {}
        XCTAssertFalse(runner.isRunning)
    }
}
