import Foundation

enum ExternalModelCatalog {
    static func chooserModels(_ models: [LocalModel], type: String) -> [LocalModel] {
        models.filter { $0.modelType == type && $0.defect == nil && !$0.isDownloading }
    }
    static let ltx25GGUFRepos = ["unsloth/LTX-2.5-GGUF", "frtertaer/LTX-2.5-uncensored-v1.1-FP8"]

    static func videoTransformers(repo: String, files: [String]) -> [String] {
        if repo == "frtertaer/LTX-2.5-uncensored-v1.1-FP8" {
            return files.filter { $0.hasPrefix("split/diffusion_models/") && $0.lowercased().hasSuffix(".gguf") }
        }
        return files
    }
    static let seedVR2Repos = [
        "AbstractFramework/seedvr2-7b-8bit",
        "AbstractFramework/seedvr2-7b-4bit",
        "AbstractFramework/seedvr2-3b-8bit",
        "AbstractFramework/seedvr2-3b-4bit"
    ]

    static func seedVR2Repo(for model: URL?) -> String? {
        guard let model else { return nil }
        return seedVR2Repos.first { ($0 as NSString).lastPathComponent == model.lastPathComponent }
    }

    static func seedVR2Ready(at root: URL) -> Bool {
        componentReady(at: root.appendingPathComponent("transformer"), requiredKeys: ["vid_in.proj.weight", "txt_in.weight", "emb_in.proj_in.weight"])
            && componentReady(at: root.appendingPathComponent("vae"), requiredKeys: ["encoder.conv_in.weight", "decoder.conv_out.weight"])
    }

    private static func componentReady(at directory: URL, requiredKeys: Set<String>) -> Bool {
        let index = directory.appendingPathComponent("model.safetensors.index.json")
        guard let data = try? Data(contentsOf: index),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let weights = object["weight_map"] as? [String: String], requiredKeys.isSubset(of: Set(weights.keys)) else { return false }
        return Set(weights.values).allSatisfy { name in
            guard !name.isEmpty, name == (name as NSString).lastPathComponent,
                  name != ".", name != "..", name.hasSuffix(".safetensors") else { return false }
            let url = directory.appendingPathComponent(name)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path),
                  attrs[.type] as? FileAttributeType == .typeRegular,
                  let size = attrs[.size] as? NSNumber else { return false }
            return size.int64Value > 0
        }
    }
}
