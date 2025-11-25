import SwiftUI

struct MouseTrackingView: NSViewRepresentable {
    var onMove: (CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class TrackingNSView: NSView {
    var onMove: ((CGPoint) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        // Flip Y coordinate to match SwiftUI (0 at top) if needed, but for X we are fine.
        // Actually locationInWindow is bottom-left origin.
        // convert(..., from: nil) converts to view coordinates.
        // If the view fills the window, it should be fine.
        onMove?(location)
    }
}
