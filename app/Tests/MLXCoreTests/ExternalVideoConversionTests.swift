import XCTest
import AVFoundation
@testable import MLXCore

@MainActor
final class ExternalVideoConversionTests: XCTestCase {
    func testGeneratedAVIBecomesAMacOSDecodableMP4() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let source = env["TEST_VIDEO_AVI"], let ffmpeg = env["TEST_FFMPEG"] else { throw XCTSkip("Real generated AVI and FFmpeg paths required") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let intermediate = root.appendingPathComponent("engine.avi")
        let output = root.appendingPathComponent("playable.mp4")
        let service = ExternalMediaService()
        let server = ServerManager()
        let conversion = ExternalVideoConversion(executable: URL(fileURLWithPath: ffmpeg), source: intermediate)
        service.start(kind: .video, executable: URL(fileURLWithPath: "/bin/cp"), arguments: [source, intermediate.path], output: output, server: server, conversion: conversion)
        for _ in 0..<1000 where service.isRunning { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertEqual(service.resultURL, output, service.message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: intermediate.path))
        let asset = AVURLAsset(url: output)
        let frame = try await AVAssetImageGenerator(asset: asset).image(at: .zero)
        XCTAssertEqual(frame.image.width, 256)
        XCTAssertEqual(frame.image.height, 256)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(audio.count, 1)
        XCTAssertTrue(server.reserveExternalMedia())
        server.releaseExternalMedia()
    }
    func testFailedConversionCleansTemporaryVideoAndReleasesMemory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input")
        try Data("fixture".utf8).write(to: input)
        let conversion = ExternalVideoConversion(executable: URL(fileURLWithPath: "/usr/bin/false"), source: root.appendingPathComponent("engine.avi"))
        let output = root.appendingPathComponent("out.mp4")
        let service = ExternalMediaService(), server = ServerManager()
        service.start(kind: .video, executable: URL(fileURLWithPath: "/bin/cp"), arguments: [input.path, conversion.source.path], output: output, server: server, conversion: conversion)
        for _ in 0..<200 where service.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertNil(service.resultURL)
        for file in [output, conversion.source, conversion.stagedOutput] { XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)) }
        XCTAssertTrue(server.reserveExternalMedia())
        server.releaseExternalMedia()
    }

    func testExistingFinalOutputIsNeverOverwritten() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("existing.mp4")
        try Data("original".utf8).write(to: output)
        let conversion = ExternalVideoConversion(executable: URL(fileURLWithPath: "/usr/bin/true"), source: root.appendingPathComponent("engine.avi"))
        let service = ExternalMediaService(), server = ServerManager()
        service.start(kind: .video, executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [], output: output, server: server, conversion: conversion)
        XCTAssertFalse(service.isRunning)
        XCTAssertNil(service.resultURL)
        XCTAssertEqual(try Data(contentsOf: output), Data("original".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: conversion.source.path))
    }

    func testCancelStopsConversionAndCleansOwnedFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input"), marker = root.appendingPathComponent("running")
        try Data("fixture".utf8).write(to: input)
        let helper = root.appendingPathComponent("helper")
        try Data(("#!/bin/sh\nprintf running > '" + marker.path + "'\nexec /bin/sleep 30\n").utf8).write(to: helper)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        let conversion = ExternalVideoConversion(executable: helper, source: root.appendingPathComponent("engine.avi"))
        let output = root.appendingPathComponent("out.mp4")
        let service = ExternalMediaService(), server = ServerManager()
        service.start(kind: .video, executable: URL(fileURLWithPath: "/bin/cp"), arguments: [input.path, conversion.source.path], output: output, server: server, conversion: conversion)
        for _ in 0..<200 where !FileManager.default.fileExists(atPath: marker.path) { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        service.cancel()
        for _ in 0..<200 where service.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(service.isRunning)
        XCTAssertNil(service.resultURL)
        for file in [output, conversion.source, conversion.stagedOutput] { XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)) }
        XCTAssertTrue(server.reserveExternalMedia())
        server.releaseExternalMedia()
    }

}
