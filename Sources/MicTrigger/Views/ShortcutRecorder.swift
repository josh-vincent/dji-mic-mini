import AppKit
import SwiftUI

struct ShortcutRecorder: View {
    @Binding var action: ShortcutAction
    @State private var isRecording = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(isRecording ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 7)
                .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
            HStack(spacing: 6) {
                Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                Text(isRecording ? "Type shortcut" : action.display)
                    .font(.caption.monospaced())
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            ShortcutCaptureRepresentable(isRecording: $isRecording) { chord in
                action = .keyChord(chord)
                isRecording = false
            }
            .opacity(0.001)
        }
        .frame(width: 132, height: 28)
        .contentShape(Rectangle())
        .onTapGesture { isRecording = true }
        .accessibilityLabel("Record keyboard shortcut")
    }
}

private struct ShortcutCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (KeyChord) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onCapture = onCapture
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class CaptureView: NSView {
        var isRecording = false
        var onCapture: ((KeyChord) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == 53 {
                isRecording = false
                return
            }

            let modifiers = ShortcutModifiers.from(event.modifierFlags)
            let label = Self.label(for: event)
            onCapture?(KeyChord(keyCode: event.keyCode, modifiers: modifiers, keyLabel: label))
        }

        private static func label(for event: NSEvent) -> String {
            switch event.keyCode {
            case 36: "Return"
            case 48: "Tab"
            case 49: "Space"
            case 51: "Delete"
            case 123: "←"
            case 124: "→"
            case 125: "↓"
            case 126: "↑"
            default:
                event.charactersIgnoringModifiers?.uppercased().trimmingCharacters(in: .controlCharacters)
                    .nilIfEmpty ?? "Key \(event.keyCode)"
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
