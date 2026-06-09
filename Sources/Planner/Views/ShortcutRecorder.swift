import SwiftUI
import AppKit

/// 클릭하면 다음 키 입력을 캡처해 단축키로 기록하는 컨트롤.
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut

    func makeNSView(context: Context) -> RecorderView {
        let v = RecorderView()
        v.shortcut = shortcut
        v.onCapture = { context.coordinator.parent.shortcut = $0 }
        return v
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        context.coordinator.parent = self
        if !nsView.recording { nsView.shortcut = shortcut }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        var parent: ShortcutRecorder
        init(_ parent: ShortcutRecorder) { self.parent = parent }
    }
}

final class RecorderView: NSView {
    var shortcut: Shortcut = ShortcutSettings.defaultDropdown { didSet { needsDisplay = true } }
    var onCapture: (Shortcut) -> Void = { _ in }
    var recording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 24) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 {            // Esc → 취소
            recording = false
            return
        }
        let sc = Shortcut.make(keyCode: event.keyCode, flags: event.modifierFlags)
        if sc.hasModifier {
            shortcut = sc
            onCapture(sc)
            recording = false
        } else {
            NSSound.beep()                  // 보조키 없는 단독 키는 무시
        }
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.12)
                   : NSColor.controlColor).setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = recording ? "키 입력…" : shortcut.display
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: recording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(
            at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attrs)
    }
}
