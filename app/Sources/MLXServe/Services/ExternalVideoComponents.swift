import Foundation

struct ExternalVideoComponents {
    static let vaePath = "vae/ltx-2.5-video-vae-conv-bf16.safetensors"
    static let audioPath = "vae/ltx-2.5-audio-vae-bf16.safetensors"
    static let encoderPath = "text_encoders/gemma4-12b-with-proj-ltx-2.5-bf16.safetensors"

    enum Profile {
        case standard, uncensored

        struct Source {
            let repo: String
            let path: String
        }

        static func forModel(_ model: URL) -> Profile {
            model.lastPathComponent.lowercased().hasPrefix("ltx25_uncensored_v1.1-") ? .uncensored : .standard
        }
        var repo: String {
            switch self {
            case .standard: return "unsloth/LTX-2.5-GGUF"
            case .uncensored: return "frtertaer/LTX-2.5-uncensored-v1.1-FP8"
            }
        }
        var sources: [Source] {
            switch self {
            case .standard:
                return [ExternalVideoComponents.vaePath, ExternalVideoComponents.audioPath, ExternalVideoComponents.encoderPath].map { Source(repo: repo, path: $0) }
            case .uncensored:
                return [Source(repo: Profile.standard.repo, path: ExternalVideoComponents.vaePath),
                        Source(repo: repo, path: "split/vae/ltx25_uncensored_audio_vae.safetensors"),
                        Source(repo: repo, path: "split/text_encoders/gguf/gemma4_12b_ltx25_uncensored-Q4_K_M.gguf")]
            }
        }
        var paths: [String] { sources.map(\.path) }
        var repos: [String] { sources.map(\.repo).reduce(into: []) { if !$0.contains($1) { $0.append($1) } } }
    }

    struct Available {
        let profile: Profile
        let vae: URL?
        let audioVae: URL?
        let encoder: URL?
        var missingNames: Set<String> {
            var names = Set<String>()
            if vae == nil { names.insert((profile.paths[0] as NSString).lastPathComponent) }
            if audioVae == nil { names.insert((profile.paths[1] as NSString).lastPathComponent) }
            if encoder == nil { names.insert((profile.paths[2] as NSString).lastPathComponent) }
            return names
        }
    }
    let vae: URL
    let audioVae: URL
    let encoder: URL

    static func find(near model: URL, modelRoots: [URL] = []) -> ExternalVideoComponents? {
        let parts = available(near: model, modelRoots: modelRoots)
        guard let vae = parts.vae, let audio = parts.audioVae, let encoder = parts.encoder else { return nil }
        return ExternalVideoComponents(vae: vae, audioVae: audio, encoder: encoder)
    }

    static func available(near model: URL, modelRoots: [URL] = []) -> Available {
        let parent = model.deletingLastPathComponent()
        let grandparent = parent.deletingLastPathComponent()
        let profile = Profile.forModel(model)
        let nearby = [parent, grandparent, grandparent.deletingLastPathComponent()]
        func first(_ source: Profile.Source) -> URL? {
            let roots = nearby + modelRoots.map { $0.appendingPathComponent(source.repo) }
            return roots.map { $0.appendingPathComponent(source.path) }.first(where: nonemptyFile)
        }
        return Available(profile: profile, vae: first(profile.sources[0]), audioVae: first(profile.sources[1]), encoder: first(profile.sources[2]))
    }

    private static func nonemptyFile(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path),
              attrs[.type] as? FileAttributeType == .typeRegular,
              let size = attrs[.size] as? NSNumber else { return false }
        return size.int64Value > 0
    }
}
