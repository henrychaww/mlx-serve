import XCTest
@testable import MLXCore

final class ExternalModelCatalogTests: XCTestCase {
    func testNativeModelChooserOffersOnlyTheMatchingExternalKind() {
        func model(_ type: String) -> LocalModel {
            LocalModel(id: type, name: type, path: "/tmp/\(type)", sizeFormatted: "1 GB", modelType: type, source: .mlxServe, kind: .base)
        }
        let all = [model("external_ltx25"), model("external_seedvr2"), model("gguf")]
        XCTAssertEqual(ExternalModelCatalog.chooserModels(all, type: "external_ltx25").map(\.id), ["external_ltx25"])
        XCTAssertEqual(ExternalModelCatalog.chooserModels(all, type: "external_seedvr2").map(\.id), ["external_seedvr2"])
    }

    func testOnlyKnownSeedVR2PacksAppearCompatibleInDiscover() {
        func row(_ id: String) -> HFModel {
            HFModel(id: id, downloads: nil, likes: nil, lastModified: nil,
                    tags: ["mlx", "seedvr2"], safetensors: nil, pipelineTag: "image-to-image")
        }
        XCTAssertTrue(row("AbstractFramework/seedvr2-7b-8bit").isCompatible)
        XCTAssertNil(row("AbstractFramework/seedvr2-7b-8bit").incompatibleReason)
        XCTAssertFalse(row("other/seedvr2-unknown").isCompatible)
    }

    func testKnownLTXGGUFRepoCanBeDiscoveredWithoutWhitelistingAllVideo() {
        func row(_ id: String) -> HFModel {
            HFModel(id: id, downloads: nil, likes: nil, lastModified: nil,
                    tags: ["gguf", "ltx-2.5"], safetensors: nil, pipelineTag: "image-to-video")
        }
        XCTAssertTrue(row("unsloth/LTX-2.5-GGUF").isCompatible)
        XCTAssertNil(row("unsloth/LTX-2.5-GGUF").incompatibleReason)
        XCTAssertFalse(row("other/unknown-video").isCompatible)
        XCTAssertTrue(row("frtertaer/LTX-2.5-uncensored-v1.1-FP8").isCompatible)
        XCTAssertEqual(ExternalModelCatalog.videoTransformers(repo: "frtertaer/LTX-2.5-uncensored-v1.1-FP8", files: ["split/diffusion_models/model-Q4.gguf", "split/text_encoders/gguf/text-Q4.gguf"]), ["split/diffusion_models/model-Q4.gguf"])
    }

    func testSeedVR2NeedsEveryShardOfBothComponents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for part in ["transformer", "vae"] {
            let dir = root.appendingPathComponent(part)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let index = part == "transformer"
                ? #"{"weight_map":{"vid_in.proj.weight":"0.safetensors","txt_in.weight":"0.safetensors","emb_in.proj_in.weight":"0.safetensors"}}"#
                : #"{"weight_map":{"encoder.conv_in.weight":"0.safetensors","decoder.conv_out.weight":"0.safetensors"}}"#
            try Data(index.utf8).write(to: dir.appendingPathComponent("model.safetensors.index.json"))
            try Data([1]).write(to: dir.appendingPathComponent("0.safetensors"))
        }
        XCTAssertTrue(ExternalModelCatalog.seedVR2Ready(at: root))
        let models = DownloadManager.makeLocalModels(atDir: root.path, displayName: "SeedVR2", idKey: "seedvr2", source: .mlxServe)
        XCTAssertEqual(models.first?.modelType, "external_seedvr2")
        XCTAssertEqual(models.first?.isChatPickable, false)
        try Data(#"{"weight_map":{"unrelated.weight":"0.safetensors"}}"#.utf8).write(to: root.appendingPathComponent("transformer/model.safetensors.index.json"))
        XCTAssertFalse(ExternalModelCatalog.seedVR2Ready(at: root))
        try FileManager.default.removeItem(at: root.appendingPathComponent("vae/0.safetensors"))
        XCTAssertFalse(ExternalModelCatalog.seedVR2Ready(at: root))
    }

    func testRejectsShardPathsOutsideComponent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for part in ["transformer", "vae"] {
            let dir = root.appendingPathComponent(part)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(#"{"weight_map":{"a":"../other.safetensors"}}"#.utf8).write(to: dir.appendingPathComponent("model.safetensors.index.json"))
        }
        try Data([1]).write(to: root.appendingPathComponent("other.safetensors"))
        XCTAssertFalse(ExternalModelCatalog.seedVR2Ready(at: root))
    }

    func testSeedVR2CanReuseSymlinkedCacheWeights() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blob = root.appendingPathComponent("blob.safetensors")
        try Data([1]).write(to: blob)
        for part in ["transformer", "vae"] {
            let dir = root.appendingPathComponent(part)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let index = part == "transformer"
                ? #"{"weight_map":{"vid_in.proj.weight":"0.safetensors","txt_in.weight":"0.safetensors","emb_in.proj_in.weight":"0.safetensors"}}"#
                : #"{"weight_map":{"encoder.conv_in.weight":"0.safetensors","decoder.conv_out.weight":"0.safetensors"}}"#
            try Data(index.utf8).write(to: dir.appendingPathComponent("model.safetensors.index.json"))
            try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("0.safetensors"), withDestinationURL: blob)
        }
        XCTAssertTrue(ExternalModelCatalog.seedVR2Ready(at: root))
    }
}
