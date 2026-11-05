import XCTest
import AppKit
@testable import MLXCore

@MainActor
final class ManagedMediaProcessTests: XCTestCase {
    func testProgressReportsKnownVideoStagesWithoutEchoingLogs() {
        XCTAssertEqual(ExternalMediaProgress.stage(in: "[I] loading diffusion model from /private/path"), "Loading model")
        XCTAssertEqual(ExternalMediaProgress.stage(in: "[I] sampling using Euler method"), "Generating video")
        XCTAssertEqual(ExternalMediaProgress.stage(in: "[I] ltx_audio_vae build cached graph"), "Decoding audio")
        XCTAssertEqual(ExternalMediaProgress.stage(in: "[I] ltx_video_vae build cached graph"), "Decoding video")
        XCTAssertEqual(ExternalMediaProgress.stage(in: "[I] decode_first_stage completed"), "Finishing video")
        XCTAssertEqual(ExternalMediaProgress.stage(in: "[I] sampling using Euler\n[I] ltx_video_vae build cached graph"), "Decoding video")
        XCTAssertNil(ExternalMediaProgress.stage(in: "private prompt with no recognized stage"))
    }

    func testRunningProcessPublishesRecognizedProgress() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let script = root.appendingPathComponent("engine")
        try Data("#!/bin/sh\nprintf '[I] ltx_video_vae build cached graph\\n'\nsleep 1\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let runner = ManagedMediaProcess()
        var stages: [String] = []
        _ = try await runner.run(executable: script, arguments: [], onProgress: { stages.append($0) })
        XCTAssertTrue(stages.contains("Decoding video"))
    }
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
