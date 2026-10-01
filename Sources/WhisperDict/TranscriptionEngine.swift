import Foundation

protocol TranscriptionEngine: Sendable {
    func transcribe(audioFile: URL, model: URL, language: String) async throws -> String
}

enum TranscriptionError: LocalizedError {
    case cliMissing, modelMissing, failed(String)
    var errorDescription: String? {
        switch self { case .cliMissing: "whisper-cli is not bundled. Build the native dependency using Scripts/build-whisper.sh."; case .modelMissing: "The selected model is not installed. Open Model Manager to download it."; case .failed(let message): "Local transcription failed: \(message)" }
    }
}

/// Invokes the real whisper.cpp CLI. The CLI and its linked native libraries are built from a pinned release and bundled with the .app.
struct WhisperCppEngine: TranscriptionEngine {
    func transcribe(audioFile: URL, model: URL, language: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: model.path) else { throw TranscriptionError.modelMissing }
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/whisper-cli")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw TranscriptionError.cliMissing }
        return try await Task.detached {
            let process = Process(); process.executableURL = executable
            process.arguments = ["-m", model.path, "-f", audioFile.path, "-l", language, "-np", "-nt"]
            let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
            try process.run(); let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw TranscriptionError.failed("whisper-cli exited with \(process.terminationStatus)") }
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
}
