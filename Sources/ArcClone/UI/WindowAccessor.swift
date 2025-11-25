import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            
            // Configure window for "frameless" look with traffic lights
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            
            // Ensure standard window buttons (traffic lights) are visible
            window.standardWindowButton(.zoomButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.closeButton)?.isHidden = false
            
            // Explicitly remove the toolbar to ensure no toolbar background or items are shown
            window.toolbar = nil
            
            window.isMovableByWindowBackground = true
            
            // Optional: Adjust traffic light position if needed (requires more complex NSWindow subclassing usually, 
            // but default position in fullSizeContentView is usually top-left of window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
