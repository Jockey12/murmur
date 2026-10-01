import Carbon
import Foundation

extension Notification.Name { static let whisperDictHotkey = Notification.Name("WhisperDict.ToggleRecording") }
extension Notification.Name { static let whisperDictSpeechEnded = Notification.Name("WhisperDict.SpeechEnded") }

/// Registers Control-Space with the system hotkey manager, avoiding interception of ordinary keystrokes.
@MainActor final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private init() {}

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { NotificationCenter.default.post(name: .whisperDictHotkey, object: nil) }
            return noErr
        }, 1, &eventType, nil, &handler)
        let hotkeyID = EventHotKeyID(signature: OSType(0x57444654), id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey), hotkeyID, GetApplicationEventTarget(), 0, &reference)
        if status != noErr { NSLog("WhisperDict: global hotkey registration failed (%d)", status) }
    }
}
