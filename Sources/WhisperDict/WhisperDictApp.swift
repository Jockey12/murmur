import SwiftUI

@main
struct WhisperDictApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    // These instances are process-wide services used by the menu-bar delegate.
    // Observing them here avoids giving the Settings scene a second ownership role.
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var models = ModelStore()

    var body: some Scene {
        Settings {
            SettingsView(settings: settings, models: models)
                .frame(minWidth: 620, minHeight: 520)
        }
        .commands { CommandGroup(replacing: .appInfo) { Button("About WhisperDict") { NSApp.orderFrontStandardAboutPanel() } } }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var hotkeyObserver: NSObjectProtocol?
    private var speechObserver: NSObjectProtocol?
    private var levelTimer: Timer?
    private let overlay = RecordingOverlay()
    private var insertionTarget: TextInsertionTarget?
    private var isTranscribing = false
    private var lastTranscript: String?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        GlobalHotkeyManager.shared.register()
        hotkeyObserver = NotificationCenter.default.addObserver(forName: .whisperDictHotkey, object: nil, queue: .main) { _ in
            Task { @MainActor in self.togglePipeline() }
        }
        speechObserver = NotificationCenter.default.addObserver(forName: .whisperDictSpeechEnded, object: nil, queue: .main) { _ in
            Task { @MainActor in if AudioCaptureService.shared.isRecording { self.togglePipeline() } }
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WhisperDict")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start / Stop Recording", action: #selector(toggleRecording), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Last Transcription", action: #selector(copyLastTranscription), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Model Manager & Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit WhisperDict", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
    }
    @objc private func openSettings() { NSApp.activate(ignoringOtherApps: true); NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
    @objc private func toggleRecording() { togglePipeline() }
    @objc private func copyLastTranscription() {
        guard let lastTranscript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
        report("Copied transcription to the clipboard.", icon: "doc.on.clipboard")
    }
    private func togglePipeline() {
        let recorder = AudioCaptureService.shared
        let settings = AppSettings.shared
        guard !isTranscribing else { return }
        if !recorder.isRecording {
            insertionTarget = TextInjectionService.captureTarget()
            recorder.start(); item.button?.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording"); overlay.show(recording: true)
            levelTimer?.invalidate(); levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                Task { @MainActor in guard let self, AudioCaptureService.shared.isRecording else { return }; self.overlay.show(recording: true, level: AudioCaptureService.shared.audioLevel) }
            }
            return
        }
        levelTimer?.invalidate(); levelTimer = nil
        guard let audio = recorder.stop() else { item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WhisperDict"); overlay.hide(); return }
        item.button?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Transcribing")
        overlay.show(recording: false)
        isTranscribing = true
        Task {
            defer { try? FileManager.default.removeItem(at: audio); isTranscribing = false; item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "WhisperDict"); overlay.hide() }
            do {
                let model = ModelPaths.directory.appendingPathComponent("ggml-\(settings.selectedModel).bin")
                let raw = try await WhisperCppEngine().transcribe(audioFile: audio, model: model, language: settings.language)
                let text = TextProcessor.process(raw, removeFillers: settings.removeFillers)
                lastTranscript = text
                if settings.autoInsert {
                    let result = await TextInjectionService.insert(text, into: insertionTarget, keepOnClipboard: settings.copyToClipboard)
                    reportInsertion(result)
                } else if settings.copyToClipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    report("Copied transcription to the clipboard.", icon: "doc.on.clipboard")
                } else {
                    report("Transcription ready.", icon: "checkmark.circle")
                }
            } catch { recorder.error = error.localizedDescription; NSLog("WhisperDict transcription error: %@", error.localizedDescription) }
        }
    }
    private func reportInsertion(_ result: TextInsertionResult) {
        report(insertionMessage(for: result), icon: result == .failed || result == .missingPermission ? "exclamationmark.triangle" : "checkmark.circle")
    }
    private func report(_ message: String, icon: String) {
        item.button?.image = NSImage(systemSymbolName: icon, accessibilityDescription: message)
        NSLog("WhisperDict: %@", message)
    }
    private func insertionMessage(for result: TextInsertionResult) -> String {
        switch result {
        case .insertedDirectly: "Inserted transcription."
        case .pasted: "Pasted transcription into the original app."
        case .missingPermission: "Accessibility permission is required. Open Settings in WhisperDict, enable the exact dist/WhisperDict.app copy, quit it, then relaunch it."
        case .noTarget: "No destination app was detected. Keep the text field focused before starting recording."
        case .failed: "Could not insert the transcription. Check Accessibility permission, then use the Copy button in Settings."
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
