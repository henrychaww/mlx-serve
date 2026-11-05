import XCTest
@testable import MLXCore

final class ExternalMediaCommandTests: XCTestCase {
    func testSeedVR2UsesExistingModelAndImagePathsAsArguments() throws {
        let args = try ExternalMediaCommand.seedVR2(model: "/models/seed vr2", input: "/pictures/a b.png", output: "/pictures/out.png", scale: 2)
        XCTAssertEqual(args, ["upscale", "--model", "/models/seed vr2", "--image-path", "/pictures/a b.png", "--resolution", "2x", "--output", "/pictures/out.png"])
    }

    func testRejectsInputOverwriteAndInvalidScale() {
        XCTAssertThrowsError(try ExternalMediaCommand.seedVR2(model: "model", input: "/a.png", output: "/a.png", scale: 2))
        XCTAssertThrowsError(try ExternalMediaCommand.seedVR2(model: "model", input: "/a.png", output: "/b.png", scale: 0))
    }

    func testLTXRequiresAllComponentsAndKeepsPromptAsOneArgument() throws {
        let args = try ExternalMediaCommand.ltx25(model: "/m.gguf", vae: "/v.safetensors", audioVae: "/a.safetensors", textEncoder: "/t.gguf", prompt: "a cat; test", output: "/out.avi", width: 768, height: 512, frames: 33)
        XCTAssertEqual(args[0...1], ["-M", "vid_gen"])
        XCTAssertEqual(args[args.firstIndex(of: "-p")! + 1], "a cat; test")
        XCTAssertTrue(args.contains("/m.gguf"))
        XCTAssertTrue(args.contains("/a.safetensors"))
        XCTAssertThrowsError(try ExternalMediaCommand.ltx25(model: "/m.gguf", vae: "", audioVae: "/a", textEncoder: "/t", prompt: "cat", output: "/out.avi", width: 768, height: 512, frames: 33))
        XCTAssertThrowsError(try ExternalMediaCommand.ltx25(model: "/m.gguf", vae: "/v", audioVae: "/a", textEncoder: "/t", prompt: "cat", output: "/out.mp4", width: 768, height: 512, frames: 33))
        XCTAssertThrowsError(try ExternalMediaCommand.ltx25(model: "/m.gguf", vae: "/v", audioVae: "/a", textEncoder: "/t", prompt: "cat", output: "/out.avi", width: 705, height: 512, frames: 33))
        XCTAssertThrowsError(try ExternalMediaCommand.ltx25(model: "/m.gguf", vae: "/v", audioVae: "/a", textEncoder: "/t", prompt: "cat", output: "/out.avi", width: 704, height: 512, frames: 32))
    }

    func testLTXCanUseAnInputImageWithoutShellInterpretation() throws {
        let args = try ExternalMediaCommand.ltx25(model: "/m.gguf", vae: "/v", audioVae: "/a", textEncoder: "/t", prompt: "cat", output: "/out.avi", width: 704, height: 512, frames: 33, initialImage: "/pictures/a b.png")
        XCTAssertEqual(args[args.firstIndex(of: "--init-img")! + 1], "/pictures/a b.png")
    }
}
