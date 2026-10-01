import AppKit
import ApplicationServices

struct TextInsertionTarget: Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
}

enum TextInsertionResult: Equatable {
    case insertedDirectly
    case pasted
    case missingPermission
    case noTarget
    case failed
}

@MainActor enum TextInjectionService {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func captureTarget() -> TextInsertionTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return TextInsertionTarget(processIdentifier: app.processIdentifier, bundleIdentifier: app.bundleIdentifier)
    }

    static func insert(_ text: String, into target: TextInsertionTarget?, keepOnClipboard: Bool) async -> TextInsertionResult {
        guard !text.isEmpty else { return .failed }
        guard isTrusted else { return .missingPermission }
        guard let target else { return .noTarget }
        // Accessibility often claims a selected-text write succeeded even when an app ignores it.
        // Pasting into the captured frontmost app is the most compatible path for browsers, editors,
        // terminals, and Electron apps; direct AX insertion remains a fallback for paste-restricted fields.
        if await paste(text, into: target, keepOnClipboard: keepOnClipboard) { return .pasted }
        return insertDirectly(text, into: target) ? .insertedDirectly : .failed
    }

    private static func insertDirectly(_ text: String, into target: TextInsertionTarget) -> Bool {
        let appElement = AXUIElementCreateApplication(target.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }

    private static func paste(_ text: String, into target: TextInsertionTarget, keepOnClipboard: Bool) async -> Bool {
        guard let app = NSRunningApplication(processIdentifier: target.processIdentifier) else { return false }
        let pasteboard = NSPasteboard.general
        // Pasteboard items supplied by other apps can reject NSCopying with an Objective-C
        // exception, which Swift cannot catch. Plain text is safe to preserve and restore.
        let previousText = keepOnClipboard ? nil : pasteboard.string(forType: .string)
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }
        let writeChangeCount = pasteboard.changeCount
        guard app.activate(options: [.activateIgnoringOtherApps]) else { return false }
        try? await Task.sleep(for: .milliseconds(350))
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        if !keepOnClipboard {
            try? await Task.sleep(for: .milliseconds(400))
            if pasteboard.changeCount == writeChangeCount {
                pasteboard.clearContents()
                if let previousText { pasteboard.setString(previousText, forType: .string) }
            }
        }
        return true
    }
}
