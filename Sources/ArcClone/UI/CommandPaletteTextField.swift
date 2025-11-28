import SwiftUI
import AppKit

struct CommandPaletteTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var isFocused: Bool
    
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onTab: () -> Void
    var onCancel: () -> Void
    var onCommit: () -> Void
    var onNumberKey: (Int) -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = CommandPaletteNSTextField()
        textField.onNumberKey = onNumberKey
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 18) // Match .title2 approx
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textFieldDidChange(_:))
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // Handle focus
        if isFocused && nsView.window?.firstResponder != nsView.currentEditor() {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CommandPaletteTextField
        
        init(_ parent: CommandPaletteTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ sender: NSTextField) {
            parent.text = sender.stringValue
            // Don't auto-commit on change
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onMoveUp()
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onMoveDown()
                return true
            } else if commandSelector == #selector(NSResponder.insertTab(_:)) || commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                parent.onTab()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            
            return false
        }
    }
}

class CommandPaletteNSTextField: NSTextField {
    var onNumberKey: ((Int) -> Void)?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if let chars = event.characters, let number = Int(chars), number >= 1 && number <= 9 {
                onNumberKey?(number)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
