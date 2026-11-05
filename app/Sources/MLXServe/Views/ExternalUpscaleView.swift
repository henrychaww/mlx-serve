import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Local SeedVR2 restoration through the managed MLX-Gen process.
struct ExternalUpscaleView: View {
    var initialModel: URL? = nil
    init(initialModel: URL? = nil) {
        self.initialModel = initialModel
        _selectedRepo = State(initialValue: ExternalModelCatalog.seedVR2Repo(for: initialModel) ?? ExternalModelCatalog.seedVR2Repos[0])
    }
    @EnvironmentObject private var server: ServerManager
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var media: ExternalMediaService
    @State private var selectedRepo: String
    @State private var model: URL?
    @State private var input: URL?
    @State private var output: URL?
    @State private var scale = 2
    @State private var message = ""

    private var engine: URL {
        let override = ProcessInfo.processInfo.environment["MLX_SERVE_MLXGEN_PATH"]
        return URL(fileURLWithPath: override ?? NSHomeDirectory() + "/.mlx-serve/runtimes/mlx-gen/.venv/bin/mlxgen")
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Image Upscaler").font(.app(.title2).weight(.semibold))
                Picker("SeedVR2 model", selection: $selectedRepo) {
                    ForEach(ExternalModelCatalog.seedVR2Repos, id: \.self) { repo in
                        Text(repo).tag(repo)
                    }
                }
                HStack {
                    Button("Use downloaded model") { selectKnownModel() }
                    Button("Download") { downloadModel() }
                        .disabled(downloads.downloads[selectedRepo]?.status == .downloading)
                }
                Menu("Choose another downloaded model") {
                    ForEach(appState.localModels.filter { $0.modelType == "external_seedvr2" }) { item in
                        Button(item.name) { model = URL(fileURLWithPath: item.path) }
                    }
                }
                if let state = downloads.downloads[selectedRepo], state.status == .downloading {
                    ProgressView(value: state.progress)
                    Text(state.statusText).font(.app(.caption))
                }
                fileRow("Model", value: model?.lastPathComponent ?? "Choose a SeedVR2 model", action: chooseModel)
                fileRow("Image", value: input?.lastPathComponent ?? "Choose an image", action: chooseImage)
                fileRow("Save to", value: output?.lastPathComponent ?? "Choose an output", action: chooseOutput)
                Picker("Scale", selection: $scale) {
                    Text("2×").tag(2)
                    Text("4×").tag(4)
                }.pickerStyle(.segmented).frame(maxWidth: 220)
                HStack {
                    Button("Upscale", action: start)
                        .disabled(media.isRunning || model == nil || input == nil || output == nil)
                    if media.isRunning && media.kind == .image {
                        ProgressView().controlSize(.small)
                        Text(media.progressText).font(.app(.caption))
                        Button("Cancel") { media.cancel() }
                    }
                }
                if !message.isEmpty { Text(message).font(.app(.body)).textSelection(.enabled) }
                if media.kind == .image && !media.message.isEmpty { Text(media.message).font(.app(.body)).textSelection(.enabled) }
                if media.isRunning && media.kind != .image { Text("Another media job is running.").font(.app(.caption)) }
                Spacer()
            }
            .padding(16).frame(minWidth: 340, idealWidth: 380, alignment: .topLeading)
            VStack {
                if media.kind == .image, let path = media.resultURL, let image = NSImage(contentsOf: path) {
                    Image(nsImage: image).resizable().scaledToFit()
                } else if let path = input, let image = NSImage(contentsOf: path) {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    ContentUnavailableView("Choose an image", systemImage: "photo")
                }
            }.padding(16).frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { model = initialModel ?? knownModel() }
        .onChange(of: selectedRepo) { _, _ in
            if ExternalModelCatalog.seedVR2Repo(for: model) != selectedRepo { model = knownModel() }
            message = ""
        }
        .onChange(of: model) { _, selected in
            if let repo = ExternalModelCatalog.seedVR2Repo(for: selected), selectedRepo != repo { selectedRepo = repo }
        }
    }

    private func fileRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.app(.headline))
            HStack { Text(value).lineLimit(1).truncationMode(.middle); Spacer(); Button("Choose…", action: action) }
        }
    }

    private func chooseModel() {
        let panel = OpenPanel.make()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mlx-serve/models")
        if AppActivation.runModal(panel) == .OK { model = panel.url }
    }

    private func knownModel() -> URL? {
        for root in downloads.readRoots {
            let path = DownloadManager.newLayoutDir(rootDir: root, repoId: selectedRepo)
            let url = URL(fileURLWithPath: path)
            if ExternalModelCatalog.seedVR2Ready(at: url) { return url }
        }
        return nil
    }

    private func selectKnownModel() {
        if let existing = knownModel() { model = existing; message = "" }
        else { message = "That model is not fully downloaded yet." }
    }

    private func downloadModel() {
        if let existing = knownModel() { model = existing; message = "This model is already available."; return }
        let repo = selectedRepo
        downloads.startSeedVR2(repoId: repo) {
            let path = URL(fileURLWithPath: downloads.newLayoutDir(for: repo))
            guard selectedRepo == repo else { return }
            if ExternalModelCatalog.seedVR2Ready(at: path) {
                model = path
                message = "Model ready."
            } else {
                message = downloads.downloads[repo]?.error ?? "The model download is incomplete."
            }
        }
    }

    private func chooseImage() {
        let panel = OpenPanel.make()
        panel.allowedContentTypes = [.image]
        if AppActivation.runModal(panel) == .OK { input = panel.url }
    }

    private func chooseOutput() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "upscaled.png"
        if AppActivation.runModal(panel) == .OK { output = panel.url }
    }

    private func start() {
        guard let model, let input, let output else { return }
        message = ""
        guard ExternalModelCatalog.seedVR2Ready(at: model) else {
            message = "Choose a complete MLX-Gen SeedVR2 model."
            return
        }
        guard let files = ExternalModelCatalog.seedVR2WeightFiles(at: model),
              let bytes = ExternalMediaMemory.weightBytes(for: files),
              let minimum = ExternalMediaMemory.requiredBytes(weightBytes: bytes) else {
            message = "Could not determine the model's memory requirements."
            return
        }
        do {
            let args = try ExternalMediaCommand.seedVR2(model: model.path, input: input.path, output: output.path, scale: scale)
            media.start(kind: .image, executable: engine, arguments: args, output: output, server: server, minimumFreeBytes: minimum)
        } catch {
            message = error.localizedDescription
        }
    }
}
