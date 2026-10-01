import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let minimumSilenceTimeout = 1.5
    @Published var selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "base.en"
    @Published var recordingMode = UserDefaults.standard.string(forKey: "recordingMode") ?? "Toggle"
    @Published var autoInsert = UserDefaults.standard.object(forKey: "autoInsert") as? Bool ?? true
    @Published var copyToClipboard = UserDefaults.standard.bool(forKey: "copyToClipboard")
    @Published var removeFillers = UserDefaults.standard.bool(forKey: "removeFillers")
    @Published var language = UserDefaults.standard.string(forKey: "language") ?? "auto"
    @Published var silenceTimeout = max(minimumSilenceTimeout, UserDefaults.standard.double(forKey: "silenceTimeout") == 0 ? minimumSilenceTimeout : UserDefaults.standard.double(forKey: "silenceTimeout"))
    init() {
        $selectedModel.dropFirst().sink { UserDefaults.standard.set($0, forKey: "selectedModel") }.store(in: &cancellables)
        $recordingMode.dropFirst().sink { UserDefaults.standard.set($0, forKey: "recordingMode") }.store(in: &cancellables)
        $autoInsert.dropFirst().sink { UserDefaults.standard.set($0, forKey: "autoInsert") }.store(in: &cancellables)
        $copyToClipboard.dropFirst().sink { UserDefaults.standard.set($0, forKey: "copyToClipboard") }.store(in: &cancellables)
        $removeFillers.dropFirst().sink { UserDefaults.standard.set($0, forKey: "removeFillers") }.store(in: &cancellables)
        $language.dropFirst().sink { UserDefaults.standard.set($0, forKey: "language") }.store(in: &cancellables)
        $silenceTimeout.dropFirst().sink { UserDefaults.standard.set($0, forKey: "silenceTimeout") }.store(in: &cancellables)
    }
    private var cancellables = Set<AnyCancellable>()
}

@MainActor struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var models: ModelStore
    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "slider.horizontal.3") }
            ModelManagerView(settings: settings, models: models).tabItem { Label("Models", systemImage: "square.and.arrow.down") }
            audio.tabItem { Label("Audio", systemImage: "mic") }
            privacy.tabItem { Label("Privacy", systemImage: "lock.shield") }
        }.padding(20)
    }
    private var general: some View {
        Form {
            LabeledContent("Recording mode", value: "Toggle (push-to-talk planned)")
            LabeledContent("Global shortcut", value: "Control + Space")
            Toggle("Automatically insert transcription", isOn: $settings.autoInsert)
            Toggle("Copy transcription to clipboard", isOn: $settings.copyToClipboard)
            Toggle("Remove filler words", isOn: $settings.removeFillers)
            TextField("Language (auto or e.g. en)", text: $settings.language)
            Divider()
            Button("Start / Stop Recording") { NotificationCenter.default.post(name: .whisperDictHotkey, object: nil) }
            Text("Use the menu-bar icon to monitor recording and transcription status.").foregroundStyle(.secondary)
        }.padding(18)
    }
    private var audio: some View {
        Form {
            Text("Microphone access is used only while recording. Audio stays on this Mac. Recording stops after speech and the configured silence timeout.")
            Slider(value: $settings.silenceTimeout, in: AppSettings.minimumSilenceTimeout...4, step: 0.1) { Text("Silence timeout: \(settings.silenceTimeout, specifier: "%.1f") seconds") }
            LabeledContent("Text insertion", value: TextInjectionService.isTrusted ? "Accessibility enabled" : "Accessibility permission required")
            if !TextInjectionService.isTrusted { Button("Open Accessibility Settings") { TextInjectionService.requestAccessibilityPermission() } }
        }.padding(18)
    }
    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Local transcription", systemImage: "lock.fill").font(.title2)
            Text("Audio is processed on this Mac using whisper.cpp. It is never uploaded. Model downloads are initiated explicitly and fetched from Hugging Face.")
            Text("Models: \(ModelStore.directory.path)").font(.callout).textSelection(.enabled)
            Text("No transcription history is stored by WhisperDict.")
            Spacer()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
    }
}
