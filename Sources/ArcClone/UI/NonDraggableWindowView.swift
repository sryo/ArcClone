import SwiftUI

/// A view that prevents the window from being dragged when interacting with its content.
/// This is useful for draggable elements that should not trigger window dragging.
struct NonDraggableWindowView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NonDraggableNSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
}
