import AVFoundation
import Foundation
import SwiftUI

/// AVAudioEngine invokes taps on its own render queue. This keeps captured samples ordered
/// without scheduling a main-actor task for every audio buffer.
final class AudioSampleStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    func reset() { lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock() }
    func append(_ buffer: [Float]) { lock.lock(); samples.append(contentsOf: buffer); lock.unlock() }
    func take() -> [Float] { lock.lock(); defer { lock.unlock() }; let result = samples; samples.removeAll(keepingCapacity: true); return result }
}

@MainActor final class AudioCaptureService: ObservableObject {
    static let shared = AudioCaptureService()
    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Double = 0
    @Published var error: String?
    private let engine = AVAudioEngine()
    private let storage = AudioSampleStorage()
    private var sampleRate: Double = 16_000
    private var quietDuration = 0.0
    private var speechDetected = false
    private var silenceStopSent = false
    func start() {
        guard !isRecording else { return }
        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        guard permission == .authorized else {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in if granted { self?.start() } else { self?.error = "Microphone access is required. Enable it in System Settings → Privacy & Security → Microphone." } }
            }
            return
        }
        do {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            let storage = storage
            sampleRate = format.sampleRate
            storage.reset()
            quietDuration = 0; speechDetected = false; silenceStopSent = false
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?[0] else { return }
                let count = Int(buffer.frameLength)
                let captured = Array(UnsafeBufferPointer(start: channel, count: count))
                storage.append(captured)
                var sum: Float = 0
                for sample in captured { sum += sample * sample }
                let level = sqrt(sum / Float(max(1, count)))
                Task { @MainActor in
                    guard let self, self.isRecording else { return }
                    self.audioLevel = min(1, Double(level) * 8)
                    if level > 0.018 { self.speechDetected = true; self.quietDuration = 0 }
                    else if self.speechDetected {
                        self.quietDuration += Double(count) / self.sampleRate
                        if self.quietDuration >= AppSettings.shared.silenceTimeout && !self.silenceStopSent {
                            self.silenceStopSent = true
                            NotificationCenter.default.post(name: .whisperDictSpeechEnded, object: nil)
                        }
                    }
                }
            }
            engine.prepare(); try engine.start(); isRecording = true; error = nil
        } catch { self.error = "Could not start microphone: \(error.localizedDescription)" }
    }
    func stop() -> URL? {
        guard isRecording else { return nil }
        engine.inputNode.removeTap(onBus: 0); engine.stop(); isRecording = false; audioLevel = 0
        let samples = storage.take()
        guard !samples.isEmpty else { error = "No audio was captured. Check the selected microphone."; return nil }
        let ratio = 16_000 / sampleRate
        let outputCount = Int(Double(samples.count) * ratio)
        var pcm = [Int16](); pcm.reserveCapacity(outputCount)
        for index in 0..<outputCount {
            let position = Double(index) / ratio
            let low = min(Int(position), samples.count - 1)
            let high = min(low + 1, samples.count - 1)
            let fraction = Float(position - Double(low))
            let value = max(-1, min(1, samples[low] * (1 - fraction) + samples[high] * fraction))
            pcm.append(Int16(value * Float(Int16.max)))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("whisperdict-\(UUID().uuidString).wav")
        do { try Self.writeWAV(pcm, to: url); return url }
        catch { self.error = "Could not prepare audio for transcription: \(error.localizedDescription)"; return nil }
    }

    private static func writeWAV(_ samples: [Int16], to url: URL) throws {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        data.append(contentsOf: "RIFF".utf8); append(UInt32(36 + samples.count * 2)); data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(UInt32(16_000)); append(UInt32(32_000)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8); append(UInt32(samples.count * 2))
        for sample in samples { append(sample) }
        try data.write(to: url, options: .atomic)
    }
}
