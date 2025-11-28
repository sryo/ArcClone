import SwiftUI
import WebKit
import SwiftData

struct WebView: NSViewRepresentable {
    let tab: BrowserTab
    let contextID: UUID
    let ownershipToken: UUID
    let profileID: UUID?
    @ObservedObject private var webEngine = WebEngine.shared
    @Environment(\.modelContext) var modelContext
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, modelContext: modelContext)
    }
    
    func makeNSView(context: Context) -> NSView {
        let webView = WebEngine.shared.getWebView(for: tab, contextID: contextID, profileID: profileID)
        context.coordinator.webView = webView
        context.coordinator.setupObservation(for: webView)
        
        // Register tab for audio polling
        WebEngine.shared.registerTab(tab)
        
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
        if let webView = context.coordinator.webView, isOwned, !webView.isLoading {
            let currentURL = webView.url
            let targetURL = tab.url
            
            // Check if we really need to load
            // 1. If URLs are identical, don't load
            // 2. If absolute strings match (ignoring potential object differences), don't load
            // 3. If one has trailing slash and other doesn't, treat as same
            let currentString = currentURL?.absoluteString ?? ""
            let targetString = targetURL.absoluteString
            
            let urlsMatch = currentURL == targetURL ||
                           currentString == targetString ||
                           currentString.trimmingCharacters(in: ["/"]) == targetString.trimmingCharacters(in: ["/"])
            
            if !urlsMatch {
                let request = URLRequest(url: tab.url)
                webView.load(request)
            }
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
            
            observations.append(webView.observe(\.isLoading, options: .new) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.tab.isLoading = webView.isLoading
                }
            })
            
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
            
            // Normalize URL for comparison (remove trailing slash)
            var normalizedString = url.absoluteString
            if normalizedString.hasSuffix("/") {
                normalizedString.removeLast()
            }
            
            let slashless = normalizedString
            let withSlash = normalizedString + "/"
            
            // Check for existing entry with either version of the URL
            let descriptor = FetchDescriptor<HistoryEntry>(
                predicate: #Predicate<HistoryEntry> { entry in
                    entry.urlString == slashless || entry.urlString == withSlash
                }
            )
            
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.visitDate = Date()
                if let title = title, !title.isEmpty {
                    existing.title = title
                }
                // Update to the latest specific URL visited
                existing.url = url
                existing.urlString = url.absoluteString
            } else {
                let entry = HistoryEntry(url: url, title: title)
                modelContext.insert(entry)
            }
            
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
    var isCurrentlyOwned: Bool? = nil
    
    func updateOwnership(isOwned: Bool, tab: BrowserTab) {
        if isOwned {
            // Transitioning from snapshot to real WebView
            let wasShowingSnapshot = snapshotImageView != nil && snapshotImageView?.superview != nil
            
            if let webView = webView {
                if wasShowingSnapshot {
                    // Show WebView immediately, removing snapshot
                    if webView.superview != self {
                        webView.frame = bounds
                        webView.alphaValue = 1.0
                        addSubview(webView)
                    } else {
                        webView.alphaValue = 1.0
                    }
                    
                    snapshotImageView?.removeFromSuperview()
                    snapshotImageView = nil
                } else {
                    // No snapshot, just show WebView normally
                    if webView.superview != self {
                        addSubview(webView)
                        webView.frame = bounds
                    }
                    webView.alphaValue = 1.0
                }
            }
            isCurrentlyOwned = true
        } else {
            // Transitioning from WebView to snapshot
            // Take snapshot first (handled by WebEngine), then show it immediately
            if webView?.superview == self {
                webView?.removeFromSuperview()
            }
            
            if let snapshot = WebEngine.shared.getSnapshot(for: tab) {
                if let imageView = snapshotImageView {
                    imageView.layer?.contents = snapshot
                    imageView.alphaValue = 1.0
                } else {
                    // Use a plain NSView with layer for proper Aspect Fill support
                    let imageView = NSImageView(frame: bounds)
                    imageView.wantsLayer = true
                    imageView.layer?.contents = snapshot
                    imageView.layer?.contentsGravity = .resizeAspectFill
                    imageView.image = nil // We use layer contents
                    imageView.autoresizingMask = [.width, .height]
                    imageView.alphaValue = 1.0
                    addSubview(imageView)
                    snapshotImageView = imageView
                }
            }
            
            isCurrentlyOwned = false
        }
    }
    
    override func layout() {
        super.layout()
        webView?.frame = bounds
        snapshotImageView?.frame = bounds
    }
}
