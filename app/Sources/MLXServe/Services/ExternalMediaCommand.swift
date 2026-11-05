import Foundation

enum ExternalMediaCommand {
    enum InputError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let message): return message }
        }
    }

    static func seedVR2(model: String, input: String, output: String, scale: Int) throws -> [String] {
        guard !model.isEmpty, !input.isEmpty, !output.isEmpty else { throw InputError.invalid("Model, input and output are required.") }
        guard (1...8).contains(scale) else { throw InputError.invalid("Choose a scale between 1 and 8.") }
        guard URL(fileURLWithPath: input).standardizedFileURL.resolvingSymlinksInPath() != URL(fileURLWithPath: output).standardizedFileURL.resolvingSymlinksInPath() else {
            throw InputError.invalid("Choose a different output file from the input image.")
        }
        return ["upscale", "--model", model, "--image-path", input, "--resolution", "\(scale)x", "--output", output]
    }

    static func ltx25(model: String, vae: String, audioVae: String, textEncoder: String, prompt: String, output: String, width: Int, height: Int, frames: Int, steps: Int = 20, guidance: Double = 3, initialImage: String? = nil) throws -> [String] {
        guard [model, vae, audioVae, textEncoder, prompt, output].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw InputError.invalid("A model, video VAE, audio VAE, text encoder, prompt and output are required.")
        }
        guard width > 0, height > 0, frames > 0 else { throw InputError.invalid("Video dimensions and frame count must be positive.") }
        guard width % 32 == 0, height % 32 == 0, (frames - 1) % 8 == 0 else {
            throw InputError.invalid("Use dimensions divisible by 32 and a frame count of 8n + 1.")
        }
        guard URL(fileURLWithPath: output).pathExtension.lowercased() == "avi" else { throw InputError.invalid("Choose a .avi output file.") }
        guard steps > 0, guidance.isFinite, guidance >= 0 else { throw InputError.invalid("Steps and guidance are invalid.") }
        var args = ["-M", "vid_gen", "--diffusion-model", model, "--vae", vae, "--audio-vae", audioVae,
                "--llm", textEncoder, "-p", prompt, "-W", "\(width)", "-H", "\(height)",
                "--video-frames", "\(frames)", "--steps", "\(steps)", "--cfg-scale", "\(guidance)",
                "--sampling-method", "euler", "--offload-to-cpu", "-o", output]
        if let initialImage, !initialImage.isEmpty { args += ["--init-img", initialImage] }
        return args
    }
}
