import SwiftUI
import AppKit
import AVKit
import UniformTypeIdentifiers

/// The LTX 2.5 GGUF route requires a transformer and three supporting files.
struct ExternalVideoView: View {
    var initialModel: URL? = nil
    init(initialModel: URL? = nil) { self.initialModel = initialModel }
    @EnvironmentObject private var server: ServerManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var media: ExternalMediaService
    @State private var model: URL?
    @State private var vae: URL?
    @State private var audioVae: URL?
    @State private var encoder: URL?
    @State private var output: URL?
    @State private var initialImage: URL?
    @State private var prompt = ""
    @State private var width = 704
    @State private var height = 448
    @State private var frames = 33
    @State private var steps = 20
    @State private var guidance = 3.0
    @State private var message = ""
    @State private var player: AVPlayer?

    private enum Component { case model, vae, audioVae, encoder }
    private var engine: URL {
        let override = ProcessInfo.processInfo.environment["MLX_SERVE_SDCLI_PATH"]
        return URL(fileURLWithPath: override ?? NSHomeDirectory() + "/.mlx-serve/runtimes/stable-diffusion/bin/sd-cli")
    }

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("LTX 2.5 Video").font(.app(.title2).weight(.semibold))
                    Menu("Choose downloaded model") {
                        ForEach(appState.localModels.filter { $0.modelType == "external_ltx25" }) { item in
                            Button(item.name + " " + (item.quantLabel ?? "")) { model = URL(fileURLWithPath: item.path) }
                        }
                    }
                    fileRow("GGUF model", url: model) { choose(.model) }
                    fileRow("Video VAE", url: vae) { choose(.vae) }
                    fileRow("Audio VAE", url: audioVae) { choose(.audioVae) }
                    fileRow("Text encoder", url: encoder) { choose(.encoder) }
                    if profile == .uncensored {
                        Text("This engine uses the standard LTX 2.5 video VAE and this pack's Q4 text encoder.").font(.app(.caption)).foregroundStyle(.secondary)
                    }
                    Button("Download missing components", action: downloadComponents)
                        .disabled(model == nil || missingNames.isEmpty || componentDownload != nil)
                    if let state = componentDownload {
                        ProgressView(value: state.progress)
                        Text(state.statusText).font(.app(.caption))
                    }
                    Text("Prompt").font(.app(.headline))
                    TextEditor(text: $prompt).frame(height: 100).border(.quaternary)
                    fileRow("Starting image (optional)", url: initialImage, action: chooseInitialImage)
                    if initialImage != nil { Button("Remove starting image") { initialImage = nil } }
                    HStack {
                        VStack(alignment: .leading) { Text("Width"); TextField("Width", value: $width, format: .number) }
                        VStack(alignment: .leading) { Text("Height"); TextField("Height", value: $height, format: .number) }
                        VStack(alignment: .leading) { Text("Frames"); TextField("Frames", value: $frames, format: .number) }
                    }
                    HStack {
                        VStack(alignment: .leading) { Text("Steps"); TextField("Steps", value: $steps, format: .number) }
                        VStack(alignment: .leading) { Text("Guidance"); TextField("Guidance", value: $guidance, format: .number) }
                    }
                    Text("Larger sizes and longer clips need more memory.").font(.app(.caption)).foregroundStyle(.secondary)
                    fileRow("Save to", url: output, action: chooseOutput)
                    HStack {
                        Button("Generate", action: start)
                            .disabled(media.isRunning || model == nil || vae == nil || audioVae == nil || encoder == nil || output == nil || prompt.isEmpty)
                        if media.isRunning && media.kind == .video {
                            ProgressView().controlSize(.small)
                            Button("Cancel") { media.cancel() }
                        }
                    }
                    if !message.isEmpty { Text(message).font(.app(.body)).textSelection(.enabled) }
                    if media.kind == .video && !media.message.isEmpty { Text(media.message).font(.app(.body)).textSelection(.enabled) }
                    if media.isRunning && media.kind != .video { Text("Another media job is running.").font(.app(.caption)) }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minWidth: 340, idealWidth: 380)
            VStack {
                if let player { VideoPlayer(player: player) }
                else { ContentUnavailableView("Generated video", systemImage: "film") }
            }.padding(16).frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear { player?.pause() }
        .onAppear { if model == nil { model = initialModel }; updatePlayer() }
        .onChange(of: media.resultURL) { _, _ in updatePlayer() }
        .onChange(of: model) { _, selected in
            let components = selected.map { ExternalVideoComponents.available(near: $0, modelRoots: downloads.readRoots.map { URL(fileURLWithPath: $0) }) }
            vae = components?.vae
            audioVae = components?.audioVae
            encoder = components?.encoder
        }
    }

    private func fileRow(_ title: String, url: URL?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.app(.headline))
            HStack { Text(url?.lastPathComponent ?? "Choose a file").lineLimit(1).truncationMode(.middle); Spacer(); Button("Choose…", action: action) }
        }
    }

    private func choose(_ component: Component) {
        let panel = OpenPanel.make()
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mlx-serve/models")
        guard AppActivation.runModal(panel) == .OK, let selected = panel.url else { return }
        switch component {
        case .model: model = selected
        case .vae: vae = selected
        case .audioVae: audioVae = selected
        case .encoder: encoder = selected
        }
    }

    private func chooseOutput() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "generated.avi"
        if let avi = UTType(filenameExtension: "avi") { panel.allowedContentTypes = [avi] }
        if AppActivation.runModal(panel) == .OK { output = panel.url }
    }

    private func chooseInitialImage() {
        let panel = OpenPanel.make()
        panel.allowedContentTypes = [.image]
        if AppActivation.runModal(panel) == .OK { initialImage = panel.url }
    }

    private func updatePlayer() {
        guard media.kind == .video, let result = media.resultURL else { player = nil; return }
        player = AVPlayer(url: result)
    }

    private var missingNames: Set<String> {
        var result = Set<String>()
        if vae == nil { result.insert((profile.paths[0] as NSString).lastPathComponent) }
        if audioVae == nil { result.insert((profile.paths[1] as NSString).lastPathComponent) }
        if encoder == nil { result.insert((profile.paths[2] as NSString).lastPathComponent) }
        return result
    }

    private var profile: ExternalVideoComponents.Profile { model.map { .forModel($0) } ?? .standard }
    private var componentDownload: DownloadManager.DownloadState? {
        profile.repos.compactMap { downloads.downloads[$0] }.first { $0.status == .downloading }
    }

    private func downloadComponents() {
        guard let selected = model else { return }
        let selectedProfile = profile
        downloads.startLTX25Components(profile: selectedProfile, names: missingNames) {
            guard model == selected else { return }
            let found = ExternalVideoComponents.available(near: selected, modelRoots: downloads.readRoots.map { URL(fileURLWithPath: $0) })
            if vae == nil { vae = found.vae }
            if audioVae == nil { audioVae = found.audioVae }
            if encoder == nil { encoder = found.encoder }
            let failure = selectedProfile.repos.compactMap { downloads.downloads[$0]?.error }.first
            message = missingNames.isEmpty ? "Components ready." : (failure ?? "Some components are missing.")
        }
    }

    private func start() {
        guard let model, let vae, let audioVae, let encoder, let output else { return }
        message = ""
        guard ExternalGGUF.isLTX25(at: model) else {
            message = "Choose a compatible LTX 2.5 GGUF video model."
            return
        }
        do {
            let args = try ExternalMediaCommand.ltx25(model: model.path, vae: vae.path, audioVae: audioVae.path,
                textEncoder: encoder.path, prompt: prompt, output: output.path, width: width, height: height, frames: frames,
                steps: steps, guidance: guidance, initialImage: initialImage?.path)
            media.start(kind: .video, executable: engine, arguments: args, output: output, server: server)
        } catch {
            message = error.localizedDescription
        }
    }
}
