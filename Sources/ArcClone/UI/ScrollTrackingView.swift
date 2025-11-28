import SwiftUI

struct ScrollTrackingView: NSViewRepresentable {
    var onScroll: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> ScrollTrackingNSView {
        let view = ScrollTrackingNSView()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: ScrollTrackingNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

class ScrollTrackingNSView: NSView {
    var onScroll: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
        // We don't call super.scrollWheel(with: event) because we want to consume the event
        // or at least handle it ourselves. However, for standard scrolling behavior (like in a list),
        // we might want to let it bubble if we weren't handling it.
        // But here we are using it for custom paging, so we likely want to consume it.
        // If we want to allow vertical scrolling to pass through, we should check the delta.
        
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            // Horizontal scroll - consume it for paging
        } else {
            // Vertical scroll - let it bubble up to potential vertical scroll views
            super.scrollWheel(with: event)
        }
    }
}
