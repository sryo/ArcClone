import Foundation
import WebKit
import Observation

@Observable
class WebEngine: NSObject {
    static let shared = WebEngine()
    
    // Key is just tabID - shared across all windows
    var webviewMap: [String: WKWebView] = [:]
    
    // Track which window currently owns each WebView
    var webviewOwners: [String: UUID] = [:]
    
    // Store snapshots for when WebView is in another window
    var snapshots: [String: NSImage] = [:]
    
    // Callback to open a new tab
    var createNewTabHandler: ((URL) -> Void)?
    
    // Track pinned status
    private var pinnedStatus: [WKWebView: Bool] = [:]
    
    override private init() {
        super.init()
    }
    
    @MainActor
    func takeSnapshot(for tab: BrowserTab) {
        let key = tab.id.uuidString
        guard let webView = webviewMap[key] else { return }
        
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { [weak self] image, error in
            if let image = image {
                self?.snapshots[key] = image
            }
        }
    }
    
    @MainActor
    func getWebView(for tab: BrowserTab, contextID: UUID) -> WKWebView {
        let key = tab.id.uuidString
        
        if let existingView = webviewMap[key] {
            // If this WebView is owned by another window, take a snapshot first
            if let currentOwner = webviewOwners[key], currentOwner != contextID {
                let snapshotConfig = WKSnapshotConfiguration()
                existingView.takeSnapshot(with: snapshotConfig) { [weak self] image, _ in
                    if let image = image {
                        self?.snapshots[key] = image
                    }
                }
            }
            
            // Update owner
            webviewOwners[key] = contextID
            
            // Update pinned status
            pinnedStatus[existingView] = tab.isPinned
            return existingView
        }
        
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.isFraudulentWebsiteWarningEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        
        // Load URL if present
        let request = URLRequest(url: tab.url)
        webView.load(request)
        
        webviewMap[key] = webView
        webviewOwners[key] = contextID
        pinnedStatus[webView] = tab.isPinned
        return webView
    }
    
    @MainActor
    func isWebViewOwnedByWindow(_ tab: BrowserTab, contextID: UUID) -> Bool {
        let key = tab.id.uuidString
        return webviewOwners[key] == contextID
    }
    
    @MainActor
    func getSnapshot(for tab: BrowserTab) -> NSImage? {
        return snapshots[tab.id.uuidString]
    }
    
    @MainActor
    func goBack(for tab: BrowserTab, contextID: UUID) {
        let webView = getWebView(for: tab, contextID: contextID)
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    @MainActor
    func goForward(for tab: BrowserTab, contextID: UUID) {
        let webView = getWebView(for: tab, contextID: contextID)
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    @MainActor
    func updateTab(_ tab: BrowserTab, with webView: WKWebView) {
        if let url = webView.url {
            tab.url = url
        }
        if let title = webView.title {
            tab.title = title
        }
        
        tab.canGoBack = webView.canGoBack
        tab.canGoForward = webView.canGoForward
        
        // Update pinned status just in case
        pinnedStatus[webView] = tab.isPinned
        
        // Note: Favicon fetching would go here
        // Simple heuristic: try to get /favicon.ico
        if let url = webView.url, let host = url.host {
            let _ = URL(string: "https://\(host)/favicon.ico")
            // In a real app, we'd fetch this asynchronously and update the model.
            // For now, we'll just store the URL string if we wanted to, or rely on a view to load it.
            // Let's assume the view will load the favicon from the URL.
        }
    }
}

extension WebEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Find the tab associated with this webView
        if let (key, _) = webviewMap.first(where: { $0.value == webView }) {
            // Key is "tabID_contextID"
            print("Finished loading for key \(key)")
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Check if this is Cmd+Click (or middle-click)
        if navigationAction.navigationType == .linkActivated {
            // Check for modifier keys (Command key)
            #if os(macOS)
            if navigationAction.modifierFlags.contains(.command) {
                // User is Cmd+Clicking - open in new tab with copied history
                if let url = navigationAction.request.url {
                    // Notify ContentView to create a new tab with this URL
                    // We'll use the same handler but with a special flag
                    DispatchQueue.main.async { [weak self] in
                        // Create new tab (ContentView will handle it)
                        self?.createNewTabHandler?(url)
                    }
                }
                decisionHandler(.cancel)
                return
            }
            #endif
            
            // Check if this is a pinned tab
            guard let isPinned = pinnedStatus[webView], isPinned else {
                // Not pinned, allow navigation
                decisionHandler(.allow)
                return
            }
            
            // This is a pinned tab and user clicked a link - open in new Today tab
            if let url = navigationAction.request.url {
                // Cancel the navigation in the pinned tab
                decisionHandler(.cancel)
                
                // Request ContentView to create a new tab with this URL
                DispatchQueue.main.async { [weak self] in
                    self?.createNewTabHandler?(url)
                }
                return
            }
        }
        
        // Default: allow navigation
        decisionHandler(.allow)
    }
}
