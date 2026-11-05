import XCTest
@testable import MLXCore

final class ExternalVideoComponentsTests: XCTestCase {
    func testUncensoredPackUsesCompatibleVAEFromTheStandardRepo() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let standard = root.appendingPathComponent("unsloth/LTX-2.5-GGUF")
        let uncensored = root.appendingPathComponent("frtertaer/LTX-2.5-uncensored-v1.1-FP8")
        for dir in [standard.appendingPathComponent("vae"), uncensored.appendingPathComponent("split/vae"), uncensored.appendingPathComponent("split/text_encoders/gguf"), uncensored.appendingPathComponent("split/diffusion_models")] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let vae = standard.appendingPathComponent("vae/ltx-2.5-video-vae-conv-bf16.safetensors")
        let audio = uncensored.appendingPathComponent("split/vae/ltx25_uncensored_audio_vae.safetensors")
        let encoder = uncensored.appendingPathComponent("split/text_encoders/gguf/gemma4_12b_ltx25_uncensored-Q4_K_M.gguf")
        for file in [vae, audio, encoder] { try Data([1]).write(to: file) }
        let model = uncensored.appendingPathComponent("split/diffusion_models/ltx25_uncensored_v1.1-Q4_K_M.gguf")
        let found = ExternalVideoComponents.find(near: model, modelRoots: [root])
        XCTAssertEqual(found?.vae.path, vae.path)
        XCTAssertEqual(found?.audioVae.path, audio.path)
        XCTAssertEqual(found?.encoder.path, encoder.path)
    }

    func testComponentsCanBeReusedFromAnotherModelRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = root.appendingPathComponent("unsloth/LTX-2.5-GGUF")
        for dir in ["vae", "text_encoders"] { try FileManager.default.createDirectory(at: repo.appendingPathComponent(dir), withIntermediateDirectories: true) }
        for path in ["vae/ltx-2.5-video-vae-conv-bf16.safetensors", "vae/ltx-2.5-audio-vae-bf16.safetensors", "text_encoders/gemma4-12b-with-proj-ltx-2.5-bf16.safetensors"] {
            try Data([1]).write(to: repo.appendingPathComponent(path))
        }
        let result = ExternalVideoComponents.find(near: URL(fileURLWithPath: "/other/model.gguf"), modelRoots: [root])
        XCTAssertEqual(result?.vae.path, repo.appendingPathComponent("vae/ltx-2.5-video-vae-conv-bf16.safetensors").path)
    }

    func testFindsComponentsBesideQuantAndReusesTheirPaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for dir in ["distilled", "vae", "text_encoders"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        let expected = ["vae/ltx-2.5-video-vae-conv-bf16.safetensors", "vae/ltx-2.5-audio-vae-bf16.safetensors", "text_encoders/gemma4-12b-with-proj-ltx-2.5-bf16.safetensors"]
        for path in expected { try Data([1]).write(to: root.appendingPathComponent(path)) }
        let result = ExternalVideoComponents.find(near: root.appendingPathComponent("distilled/model.gguf"))
        XCTAssertEqual(result?.vae.path, root.appendingPathComponent(expected[0]).path)
        XCTAssertEqual(result?.audioVae.path, root.appendingPathComponent(expected[1]).path)
        XCTAssertEqual(result?.encoder.path, root.appendingPathComponent(expected[2]).path)
        try FileManager.default.removeItem(at: root.appendingPathComponent(expected[1]))
        XCTAssertNil(ExternalVideoComponents.find(near: root.appendingPathComponent("distilled/model.gguf")))
    }
}
