import Foundation
import WebKit
import MediaPlayer


class WebEngine: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = WebEngine()
    
    // Key is just tabID - shared across all windows
    var webviewMap: [String: WKWebView] = [:]
    
    // Track which window currently owns each WebView
    var webviewOwners: [String: UUID] = [:]
    
    // Store snapshots for when WebView is in another window
    var snapshots: [String: NSImage] = [:]
    
    // Now Playing tracking
    private var nowPlayingTab: BrowserTab?
    private var commandCenter: MPRemoteCommandCenter?
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter?
    
    // Picture-in-Picture tracking
    private var tabsInPiP: Set<String> = []
    
    @Published private(set) var ownershipChangeToken = UUID()
    
    // Callback to open a new tab
    var createNewTabHandler: ((URL) -> Void)?
    
    // Callback to open a URL in a new window
    var openInNewWindowHandler: ((URL) -> Void)?
    
    // Track pinned status
    private var pinnedStatus: [WKWebView: Bool] = [:]
    
    override private init() {
        super.init()
        setupNowPlaying()
    }
    
    private func setupNowPlaying() {
        commandCenter = MPRemoteCommandCenter.shared()
        nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        
        // Play command
        commandCenter?.playCommand.addTarget { [weak self] _ in
            self?.handlePlayCommand()
            return .success
        }
        
        // Pause command
        commandCenter?.pauseCommand.addTarget { [weak self] _ in
            self?.handlePauseCommand()
            return .success
        }
        
        // Toggle play/pause
        commandCenter?.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handleTogglePlayPause()
            return .success
        }
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
    func getWebView(for tab: BrowserTab, contextID: UUID, profileID: UUID?) -> WKWebView {
        let key = tab.id.uuidString
        
        if let existingView = webviewMap[key] {
            let ownerChanged = webviewOwners[key] != contextID
            // If this WebView is owned by another window, take a snapshot first
            if let currentOwner = webviewOwners[key], currentOwner != contextID {
                let snapshotConfig = WKSnapshotConfiguration()
                existingView.takeSnapshot(with: snapshotConfig) { [weak self] image, _ in
                    Task { @MainActor in
                        if let image = image {
                            self?.snapshots[key] = image
                        }
                        self?.notifyOwnershipChange()
                    }
                }
            }
            
            // Update owner
            webviewOwners[key] = contextID
            if ownerChanged {
                notifyOwnershipChange()
            }
            
            // Update pinned status
            pinnedStatus[existingView] = tab.isPinned
            
            // Update handler for custom webview
            if let customWebView = existingView as? CustomWKWebView {
                customWebView.openInNewWindowHandler = openInNewWindowHandler
            }
            
            return existingView
        }
        
        let config = WKWebViewConfiguration()
        if let profileID = profileID {
            config.websiteDataStore = WKWebsiteDataStore(forIdentifier: profileID)
        } else {
            config.websiteDataStore = .default()
        }
        config.preferences.isFraudulentWebsiteWarningEnabled = true
        
        // Apply Ad Blocking
        if let ruleList = AdBlockerService.shared.contentRuleList {
            config.userContentController.add(ruleList)
        }
        
        let webView = CustomWKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        webView.openInNewWindowHandler = openInNewWindowHandler
        
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
        let webView = getWebView(for: tab, contextID: contextID, profileID: nil)
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    @MainActor
    func goForward(for tab: BrowserTab, contextID: UUID) {
        let webView = getWebView(for: tab, contextID: contextID, profileID: nil)
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    @MainActor
    func reload(for tab: BrowserTab, contextID: UUID) {
        let webView = getWebView(for: tab, contextID: contextID, profileID: nil)
        webView.reload()
    }
    
    @MainActor
    func updateTab(_ tab: BrowserTab, with webView: WKWebView) {
        if let url = webView.url {
            tab.url = url
        }
        if let title = webView.title, !title.isEmpty {
            tab.title = title
        }
        
        // Initial check
        checkAudioState(for: tab, webView: webView)
    }
    
    @MainActor
    private func checkAudioState(for tab: BrowserTab, webView: WKWebView) {
        let audioCheckJS = """
        (function() {
            const videos = document.querySelectorAll('video');
            const audios = document.querySelectorAll('audio');
            
            for (let v of videos) {
                if (!v.paused && !v.muted && v.currentTime > 0) {
                    return true;
                }
            }
            
            for (let a of audios) {
                if (!a.paused && !a.muted && a.currentTime > 0) {
                    return true;
                }
            }
            
            return false;
        })();
        """
        
        Task { @MainActor in
            do {
                let result = try await webView.evaluateJavaScript(audioCheckJS)
                if let isPlaying = result as? Bool {
                    if tab.isPlayingAudio != isPlaying {
                        tab.isPlayingAudio = isPlaying
                        await self.updateNowPlayingInfo(for: tab, isPlaying: isPlaying)
                    }
                }
            } catch {
                print("Error evaluating JavaScript for audio check: \(error)")
            }
        }
    }
    
    // Polling timer
    private var audioPollingTimer: Timer?
    
    @MainActor
    func startAudioPolling() {
        stopAudioPolling()
        audioPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollAllTabsForAudio()
            }
        }
    }
    
    @MainActor
    func stopAudioPolling() {
        audioPollingTimer?.invalidate()
        audioPollingTimer = nil
    }
    
    @MainActor
    private func pollAllTabsForAudio() {
        for (key, webView) in webviewMap {
            // Find the tab associated with this webView
            // Since we don't have a direct reverse map, we have to search or pass the tab.
            // But wait, we don't have easy access to the Tab object from the WebView key here without iterating all spaces.
            // However, we can iterate the owners or just iterate all known tabs if we had them.
            // A better way: The UI (WebView.swift) calls updateTab.
            // Let's rely on the UI to trigger updates or maintain a weak map of Tab objects if needed.
            // BUT, for global polling, we need to know which tab corresponds to which WebView.
            
            // For now, let's try to find the tab in the active spaces.
            // This is expensive if we do it every second.
            // ALTERNATIVE: When `getWebView` is called, we can store a weak reference to the Tab in a map `[String: Weak<BrowserTab>]`.
            
            // Let's implement the weak map approach for efficiency.
            if let tab = tabMap[key]?.value {
                checkAudioState(for: tab, webView: webView)
            }
        }
    }
    
    // Weak wrapper
    struct Weak<T: AnyObject> {
        weak var value: T?
    }
    
    private var tabMap: [String: Weak<BrowserTab>] = [:]
    
    @MainActor
    func registerTab(_ tab: BrowserTab) {
        tabMap[tab.id.uuidString] = Weak(value: tab)
    }
    
    // MARK: - WKUIDelegate - Context Menu Support
    
    /*
     // Disabled temporarily - using iOS-specific types that don't exist on macOS
    @available(macOS 13.0, *)
    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationFor elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping (NSUIContextMenuConfiguration?) -> Void
    ) {
        // Get the link URL if available
        let linkURL = elementInfo.linkURL
        
        // Check if there's an image by checking image URL
        var imageURL: URL?
        
        // The element info doesn't directly give us image URL, but we can check if the element is an image
        // For now, we'll use JavaScript to detect if we're clicking on an image
        // But for the basic implementation, let's check if linkURL points to an image
        if let url = linkURL {
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp"]
            if imageExtensions.contains(url.pathExtension.lowercased()) {
                imageURL = url
            }
        }
        
        // Create configuration with custom menu items
        let configuration = NSUIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] suggestedActions in
            var customActions: [NSUIMenuElement] = []
            
            // Add "Open Link in New Window" if there's a link (and it's not an image)
            if let url = linkURL, imageURL == nil {
                let openLinkAction = NSUIAction(
                    title: "Open Link in New Window",
                    image: NSImage(systemSymbolName: "arrow.up.forward.square", accessibilityDescription: nil)
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.openInNewWindowHandler?(url)
                    }
                }
                customActions.append(openLinkAction)
            }
            
            // Add "Open Image in New Window" if there's an image
            if let url = imageURL {
                let openImageAction = NSUIAction(
                    title: "Open Image in New Window",
                    image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.openInNewWindowHandler?(url)
                    }
                }
                customActions.append(openImageAction)
            }
            
            // If we have custom actions, combine them with suggested actions
            if !customActions.isEmpty {
                return NSUIMenu(title: "", children: customActions + suggestedActions)
            } else {
                // No custom actions, use default menu
                return NSUIMenu(title: "", children: suggestedActions)
            }
        }
        
        completionHandler(configuration)
    }
    */
    
    // MARK: - Now Playing Integration
    
    private func handlePlayCommand() {
        Task { @MainActor in
            guard let tab = nowPlayingTab,
                  let webView = webviewMap[tab.id.uuidString] else { return }
            
            do {
                let js = """
                (function() {
                    const media = document.querySelector('video, audio');
                    if (media) media.play();
                })();
                """
                _ = try await webView.evaluateJavaScript(js)
            } catch {
                print("Error evaluating JavaScript for play command: \(error)")
            }
        }
    }
    
    private func handlePauseCommand() {
        Task { @MainActor in
            guard let tab = nowPlayingTab,
                  let webView = webviewMap[tab.id.uuidString] else { return }
            
            do {
                let js = """
                (function() {
                    const media = document.querySelector('video, audio');
                    if (media) media.pause();
                })();
                """
                _ = try await webView.evaluateJavaScript(js)
            } catch {
                print("Error evaluating JavaScript for pause command: \(error)")
            }
        }
    }
    
    private func handleTogglePlayPause() {
        Task { @MainActor in
            guard let tab = nowPlayingTab,
                  let webView = webviewMap[tab.id.uuidString] else { return }
            
            do {
                let js = """
                (function() {
                    const media = document.querySelector('video, audio');
                    if (media) {
                        if (media.paused) {
                            media.play();
                        } else {
                            media.pause();
                        }
                    }
                })();
                """
                _ = try await webView.evaluateJavaScript(js)
            } catch {
                print("Error evaluating JavaScript for toggle play/pause command: \(error)")
            }
        }
    }
    
    @MainActor
    private func updateNowPlayingInfo(for tab: BrowserTab, isPlaying: Bool) async {
        guard let webView = webviewMap[tab.id.uuidString] else { return }
        
        // If this tab is playing, make it the Now Playing tab
        if isPlaying {
            nowPlayingTab = tab
            
            // Extract media info
            let js = """
            (function() {
                const title = document.title || 'Unknown';
                const domain = window.location.hostname;
                return { title: title, domain: domain };
            })();
            """
            
            do {
                let result = try await webView.evaluateJavaScript(js)
                if let dict = result as? [String: String],
                   let title = dict["title"],
                   let domain = dict["domain"] {
                    
                    var nowPlayingInfo: [String: Any] = [:]
                    nowPlayingInfo[MPMediaItemPropertyTitle] = title
                    nowPlayingInfo[MPMediaItemPropertyArtist] = domain
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                    
                    self.nowPlayingInfoCenter?.nowPlayingInfo = nowPlayingInfo
                }
            } catch {
                print("Error evaluating JavaScript for Now Playing info: \(error)")
            }
        } else if nowPlayingTab?.id == tab.id {
            // If the current Now Playing tab stopped, clear info
            nowPlayingTab = nil
            nowPlayingInfoCenter?.nowPlayingInfo = nil
        }
    }
    
    // MARK: - Picture-in-Picture
    
    @MainActor
    func hasPlayingVideo(for tab: BrowserTab) async -> Bool {
        guard let webView = webviewMap[tab.id.uuidString] else { return false }
        
        let videoCheckJS = """
        (function() {
            const videos = document.querySelectorAll('video');
            for (let video of videos) {
                if (!video.paused && !video.ended && video.readyState >= 2) {
                    return true;
                }
            }
            return false;
        })();
        """
        
        do {
            let result = try await webView.evaluateJavaScript(videoCheckJS)
            return (result as? Bool) ?? false
        } catch {
            print("Error checking for playing video: \(error)")
            return false
        }
    }
    
    @MainActor
    func enterPiP(for tab: BrowserTab) async {
        guard let webView = webviewMap[tab.id.uuidString] else {
            print("DEBUG: enterPiP - No WebView found for tab \(tab.id)")
            return
        }
        
        print("DEBUG: Attempting to enter PiP for tab \(tab.title)")
        
        let pipJS = """
        (function() {
            const videos = document.querySelectorAll('video');
            console.log("DEBUG: Found " + videos.length + " videos");
            
            for (let video of videos) {
                if (!video.paused && !video.ended && video.readyState >= 2) {
                    console.log("DEBUG: Found playing video");
                    
                    // Try standard API
                    if (document.pictureInPictureEnabled && !document.pictureInPictureElement) {
                        video.requestPictureInPicture()
                            .then(() => {
                                console.log("DEBUG: Standard PiP success");
                            })
                            .catch((error) => {
                                console.log("DEBUG: Standard PiP failed: " + error);
                                // Fallback to WebKit API
                                if (video.webkitSetPresentationMode) {
                                    video.webkitSetPresentationMode('picture-in-picture');
                                }
                            });
                        return true;
                    } 
                    // Fallback for WebKit (Safari/macOS often uses this)
                    else if (video.webkitSetPresentationMode) {
                        console.log("DEBUG: Using WebKit Presentation Mode");
                        video.webkitSetPresentationMode('picture-in-picture');
                        return true;
                    }
                }
            }
            return false;
        })();
        """
        
        do {
            let result = try await webView.evaluateJavaScript(pipJS)
            print("DEBUG: enterPiP JS result: \(String(describing: result))")
            if let success = result as? Bool, success {
                self.tabsInPiP.insert(tab.id.uuidString)
            }
        } catch {
            print("Error evaluating JavaScript for enter PiP: \(error)")
        }
    }
    
    @MainActor
    func exitPiP(for tab: BrowserTab) async {
        guard let webView = webviewMap[tab.id.uuidString] else { return }
        
        let exitPipJS = """
        (function() {
            if (document.pictureInPictureElement) {
                document.exitPictureInPicture();
                return true;
            }
            return false;
        })();
        """
        
        do {
            _ = try await webView.evaluateJavaScript(exitPipJS)
            self.tabsInPiP.remove(tab.id.uuidString)
        } catch {
            print("Error evaluating JavaScript for exit PiP: \(error)")
        }
    }
    
    @MainActor
    func isInPiP(tab: BrowserTab) -> Bool {
        return tabsInPiP.contains(tab.id.uuidString)
    }
    
    @MainActor
    func stopLoading(for tab: BrowserTab, contextID: UUID) {
        let webView = getWebView(for: tab, contextID: contextID, profileID: nil)
        webView.stopLoading()
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let tab = findTab(for: webView) {
            Task { @MainActor in
                tab.isLoading = true
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let tab = findTab(for: webView) {
            Task { @MainActor in
                tab.isLoading = false
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let tab = findTab(for: webView) {
            Task { @MainActor in
                tab.isLoading = false
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let tab = findTab(for: webView) {
            Task { @MainActor in
                tab.isLoading = false
            }
        }
    }
    
    private func findTab(for webView: WKWebView) -> BrowserTab? {
        // Find the key (tab ID) in webviewMap where the value is this webView
        guard let tabID = webviewMap.first(where: { $0.value === webView })?.key else { return nil }
        return tabMap[tabID]?.value
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Check if this is a pinned tab (we need to find which tab this webview belongs to)
        // For now, we rely on the fact that we set the delegate.
        // Ideally we should map webView -> Tab, but for now let's check if we need to open in new tab.
        
        // If it's a download, let's handle it
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        
        // Check if this webview is for a pinned tab
        // We now allow navigation in pinned tabs, so we don't cancel here.
        // The original pinned URL is stored in tab.pinnedURL and can be reset.
        
        /* 
        // OLD BEHAVIOR: Prevent navigation in pinned tabs
        if pinnedStatus[webView] == true, navigationAction.navigationType == .linkActivated {
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
        */
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }
    
    // MARK: - WKDownloadDelegate
    
    // MARK: - WKDownloadDelegate
    
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        // We need to get the suggested filename somehow, but WKDownload doesn't provide it immediately in this callback.
        // It's provided in decideDestinationUsing.
        // So we just set the delegate here.
        download.delegate = DownloadManager.shared
        
        // We can't start tracking it in DownloadManager until we get the filename in decideDestinationUsing
        // But we can't pass data easily between these two delegates unless we wrap it.
        // For now, let's let DownloadManager handle it fully as the delegate.
    }
    
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = DownloadManager.shared
        
        // Attempt to guess filename from response if possible, but decideDestination is better.
        let filename = navigationResponse.response.suggestedFilename ?? "download"
        
        Task { @MainActor in
            DownloadManager.shared.startDownload(download, suggestedFilename: filename)
            // Trigger animation
            downloadStartTrigger = UUID()
        }
    }
    
    // Download State - Delegated to DownloadManager
    // We keep lastDownloadStatus for the UI toast for now, but ideally we observe DownloadManager
    @Published var lastDownloadStatus: String?
    @Published var downloadStartTrigger: UUID?

    @MainActor
    func updatePinnedState(for tab: BrowserTab) {
        let key = tab.id.uuidString
        if let webView = webviewMap[key] {
            pinnedStatus[webView] = tab.isPinned
        }
    }
    
    @MainActor
    func detach(tabID: UUID) {
        let key = tabID.uuidString
        if let webView = webviewMap[key] {
            webView.stopLoading()
            pinnedStatus.removeValue(forKey: webView)
        }
        webviewMap.removeValue(forKey: key)
        webviewOwners.removeValue(forKey: key)
        snapshots.removeValue(forKey: key)
    }
    
    @MainActor
    func notifyOwnershipChange() {
        ownershipChangeToken = UUID()
    }
    
    @MainActor
    func removeProfileData(profileID: UUID) {
        let dataStore = WKWebsiteDataStore(forIdentifier: profileID)
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
            print("DEBUG: Removed all data for profile \(profileID)")
        }
    }
    
    @MainActor
    func clearBrowsingData(types: Set<String>, since date: Date) async {
        // Clear default data store
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: date) {
                continuation.resume()
            }
        }
        
        // We should also clear data for all profiles if possible, or maybe just the active ones?
        // For now, let's just clear the default one as profiles use separate data stores.
        // Ideally we would iterate over all known profile IDs, but WebEngine doesn't track them all.
        // We can leave that for a future improvement or if the user specifically asks for "All Profiles".
    }
}


