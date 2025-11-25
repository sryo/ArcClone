import SwiftUI
import WebKit
import SwiftData

struct WebView: NSViewRepresentable {
    let tab: BrowserTab
    let contextID: UUID
    @Environment(\.modelContext) var modelContext
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, modelContext: modelContext)
    }
    
    func makeNSView(context: Context) -> NSView {
        let webView = WebEngine.shared.getWebView(for: tab, contextID: contextID)
        context.coordinator.webView = webView
        context.coordinator.setupObservation(for: webView)
        
        // Create container view
        let container = SnapshotContainerView()
        container.webView = webView
        container.tab = tab
        container.contextID = contextID
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? SnapshotContainerView else { return }
        
        // Check if we own this WebView
        let isOwned = WebEngine.shared.isWebViewOwnedByWindow(tab, contextID: contextID)
        container.updateOwnership(isOwned: isOwned, tab: tab)
        
        // Only reload if the tab's URL is fundamentally different from what the WebView has
        if let webView = context.coordinator.webView,
           webView.url != tab.url && !webView.isLoading && isOwned {
            let request = URLRequest(url: tab.url)
            webView.load(request)
        }
    }
    
    class Coordinator: NSObject {
        var parent: WebView
        var modelContext: ModelContext
        var webView: WKWebView?
        var observations: [NSKeyValueObservation] = []
        
        init(_ parent: WebView, modelContext: ModelContext) {
            self.parent = parent
            self.modelContext = modelContext
        }
        
        func setupObservation(for webView: WKWebView) {
            observations.removeAll()
            
            observations.append(webView.observe(\.canGoBack, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.tab.canGoBack = webView.canGoBack
                }
            })
            
            observations.append(webView.observe(\.canGoForward, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.tab.canGoForward = webView.canGoForward
                }
            })
            
            observations.append(webView.observe(\.url, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    if let url = webView.url {
                        self?.parent.tab.url = url
                        self?.recordVisit(url: url, title: webView.title)
                    }
                }
            })
            
            observations.append(webView.observe(\.title, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    if let title = webView.title {
                        self?.parent.tab.title = title
                    }
                }
            })
        }
        
        private func recordVisit(url: URL, title: String?) {
            guard url.absoluteString != "about:blank" else { return }
            
            let entry = HistoryEntry(url: url, title: title)
            modelContext.insert(entry)
            try? modelContext.save()
        }
    }
}

// Container view that can show either WebView or snapshot
class SnapshotContainerView: NSView {
    var webView: WKWebView?
    var tab: BrowserTab?
    var contextID: UUID?
    var snapshotImageView: NSImageView?
    var isCurrentlyOwned = true
    
    func updateOwnership(isOwned: Bool, tab: BrowserTab) {
        if isOwned == isCurrentlyOwned { return }
        isCurrentlyOwned = isOwned
        
        if isOwned {
            // Show real WebView
            snapshotImageView?.removeFromSuperview()
            snapshotImageView = nil
            
            if let webView = webView, webView.superview != self {
                addSubview(webView)
                webView.frame = bounds
            }
        } else {
            // Show snapshot
            webView?.removeFromSuperview()
            
            if let snapshot = WebEngine.shared.getSnapshot(for: tab) {
                let imageView = NSImageView(frame: bounds)
                imageView.image = snapshot
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.autoresizingMask = [.width, .height]
                addSubview(imageView)
                snapshotImageView = imageView
            }
        }
    }
    
    override func layout() {
        super.layout()
        webView?.frame = bounds
        snapshotImageView?.frame = bounds
    }
}
