import AppKit
import SwiftUI

@MainActor final class RecordingOverlay {
    private var panel: NSPanel?
    func show(recording: Bool, level: Double = 0) {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let size = NSSize(width: 220, height: 58)
        if panel == nil {
            let window = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isFloatingPanel = true; window.level = .statusBar; window.backgroundColor = .clear
            window.isOpaque = false; window.hasShadow = true; window.ignoresMouseEvents = true
            panel = window
        }
        panel?.contentView = NSHostingView(rootView: OverlayContent(recording: recording, level: level))
        panel?.setFrameOrigin(NSPoint(x: screen.midX - size.width / 2, y: screen.maxY - size.height - 14))
        panel?.orderFrontRegardless()
    }
    func hide() { panel?.orderOut(nil) }
}

private struct OverlayContent: View {
    let recording: Bool
    let level: Double
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: recording ? "mic.fill" : "waveform").foregroundStyle(recording ? .red : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(recording ? "Recording" : "Transcribing…").font(.system(size: 13, weight: .semibold))
                if recording { GeometryReader { proxy in Capsule().fill(.red.opacity(0.75)).frame(width: max(4, proxy.size.width * level), height: 3) }.frame(height: 3) }
            }
        }.padding(.horizontal, 16).padding(.vertical, 12).frame(width: 220, height: 58)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2)))
    }
}
