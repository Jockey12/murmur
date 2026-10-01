import Foundation
import SwiftUI
import Combine

struct WhisperModel: Identifiable, Sendable {
    let id: String
    let title: String
    let size: String
    let url: URL
    static let catalog: [WhisperModel] = [
        .init(id: "tiny", title: "Tiny", size: "75 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin")!),
        .init(id: "base", title: "Base", size: "142 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!),
        .init(id: "small", title: "Small", size: "466 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!),
        .init(id: "medium", title: "Medium", size: "1.5 GB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin")!),
        .init(id: "large-v3", title: "Large v3", size: "3.1 GB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!),
        .init(id: "large-v3-turbo", title: "Large v3 Turbo", size: "1.6 GB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!),
        .init(id: "base.en", title: "Base English", size: "142 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!)
    ]
    var fileName: String { "ggml-\(id).bin" }
}

enum ModelPaths {
    static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WhisperDict/models", isDirectory: true)
}

@MainActor final class ModelStore: ObservableObject {
    static var directory: URL { ModelPaths.directory }
    @Published var downloading: String?
    @Published var progress: Double = 0
    @Published var error: String?
    @Published private(set) var installedIDs = Set<String>()
    init() { refreshInstalledModels() }
    func delete(_ model: WhisperModel) {
        try? FileManager.default.removeItem(at: Self.directory.appendingPathComponent(model.fileName))
        refreshInstalledModels()
    }
    func download(_ model: WhisperModel) {
        guard downloading == nil else { return }
        downloading = model.id; progress = 0; error = nil
        Task.detached { [weak self] in
            do {
                try FileManager.default.createDirectory(at: ModelPaths.directory, withIntermediateDirectories: true)
                let (temporary, response) = try await URLSession.shared.download(from: model.url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let destination = ModelPaths.directory.appendingPathComponent(model.fileName)
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporary, to: destination)
                await MainActor.run { self?.refreshInstalledModels(); self?.downloading = nil }
            } catch {
                await MainActor.run { self?.error = "Download failed: \(error.localizedDescription)"; self?.downloading = nil }
            }
        }
    }
    private func refreshInstalledModels() {
        installedIDs = Set(WhisperModel.catalog.compactMap { model in
            FileManager.default.fileExists(atPath: Self.directory.appendingPathComponent(model.fileName).path) ? model.id : nil
        })
    }
}

@MainActor struct ModelManagerView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var models: ModelStore
    var body: some View {
        let installedIDs = models.installedIDs
        let downloading = models.downloading
        let downloadProgress = models.progress
        let downloadError = models.error
        let selectedModel = settings.selectedModel
        VStack(alignment: .leading) {
            Text("Whisper models").font(.title2.bold())
            Text("Choose a model and download it when you’re ready. Downloads come from Hugging Face; transcription remains local.").foregroundStyle(.secondary)
            List(WhisperModel.catalog) { model in
                HStack {
                    VStack(alignment: .leading) { Text(model.title).font(.headline); Text("\(model.size) • \(model.id)").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if installedIDs.contains(model.id) {
                        if selectedModel == model.id { Label("Selected", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                        else { Button("Use") { Task { @MainActor in settings.selectedModel = model.id } } }
                        Button("Delete", role: .destructive) { Task { @MainActor in models.delete(model) } }
                    } else { Button(downloading == model.id ? "Downloading…" : "Download") { Task { @MainActor in models.download(model) } }.disabled(downloading != nil) }
                }.padding(.vertical, 4)
            }
            if let downloadError { Text(downloadError).foregroundStyle(.red) }
            if let downloading { ProgressView("Downloading \(downloading)…", value: downloadProgress, total: 1) }
        }.padding(14)
    }
}
