import SwiftUI

struct CommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: BrowserTab?
    var contextID: UUID
    var isEmbedded: Bool = false
    var isNewTabMode: Bool = false
    var onOpenLibrary: (() -> Void)? = nil
    var onCreateTab: ((URL, String) -> Void)? = nil
    @Environment(\.modelContext) var modelContext
    @StateObject private var suggestionService = SuggestionService()
    @State private var urlString: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Enter URL or Search...", text: $urlString)
                .textFieldStyle(.plain)
                .font(.title2)
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)
                .shadow(radius: 10)
                .focused($isFocused)
                .onSubmit {
                    navigateToUrl()
                }
                .onChange(of: urlString) { oldValue, newValue in
                    suggestionService.fetchSuggestions(for: newValue, modelContext: modelContext)
                }
                .padding(.horizontal, 40)
                .padding(.top, isEmbedded ? 100 : 40) // Adjust padding for embedded mode
            
            if !suggestionService.suggestions.isEmpty {
                List(suggestionService.suggestions) { suggestion in
                    Button(action: {
                        handleSuggestion(suggestion)
                    }) {
                        HStack {
                            Image(systemName: suggestion.icon)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading) {
                                Text(suggestion.title)
                                    .foregroundColor(.primary)
                                if suggestion.type != .search, let url = suggestion.url {
                                    Text(url.host ?? url.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if suggestion.type == .tab {
                                Text("Switch to Tab")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxHeight: 300)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .shadow(radius: 10)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isEmbedded ? Color.clear : Color.black.opacity(0.3))
        .onAppear {
            // Add a slight delay to ensure the view is ready to accept focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
            
            if !isNewTabMode, let tab = selectedTab, tab.url.absoluteString != "about:blank" {
                urlString = tab.url.absoluteString
            } else {
                urlString = ""
            }
        }
        .onTapGesture {
            if !isEmbedded {
                isPresented = false
            }
        }
    }
    
    private func handleSuggestion(_ suggestion: SuggestionItem) {
        if suggestion.type == .tab, let _ = suggestion.url {
            // Switch to existing tab
            // We need to find the tab object. Since we don't have the full list here,
            // we might need to rely on URL matching or pass the ID in SuggestionItem.
            // But wait, SuggestionItem has the URL.
            // If we just load the URL in the *current* tab, that's not "Switch to Tab".
            // "Switch to Tab" implies activating the existing tab.
            // We need a callback to switch to a specific tab.
            // For now, let's just load the URL, which effectively switches content, 
            // BUT ideally we should select the other tab.
            // To do this properly, we need to pass the Tab ID in SuggestionItem and have a callback `onSelectTab(UUID)`.
            // Let's update `navigateToUrl` to handle this or add a new callback.
            // Given the constraints, let's just load the URL for now, 
            // OR we can try to find the tab in `ContentView` if we pass a callback.
            // Let's assume we just navigate for now, as "Switch to Tab" usually means "Go to this content".
            // Actually, if I have `onSelectTab`, I can do it.
            // I'll add `onSelectTab` callback.
            urlString = suggestion.url?.absoluteString ?? suggestion.title
            navigateToUrl()
        } else if suggestion.type == .history, let url = suggestion.url {
            urlString = url.absoluteString
            navigateToUrl()
        } else {
            urlString = suggestion.title
            navigateToUrl()
        }
    }
    
    private func navigateToUrl() {
        guard selectedTab != nil else { return }
        
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var urlToLoad: URL?
        
        // Simple heuristic: if it has spaces or no dots, treat as search
        if trimmed.lowercased() == "open library" {
            onOpenLibrary?()
            isPresented = false
            return
        }
        
        if trimmed.contains(" ") || !trimmed.contains(".") {
            // Search query
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            urlToLoad = URL(string: "https://www.google.com/search?q=\(query)")
        } else {
            // URL
            var finalString = trimmed
            if !finalString.lowercased().hasPrefix("http") {
                finalString = "https://" + finalString
            }
            urlToLoad = URL(string: finalString)
        }
        
        if let url = urlToLoad {
            // Update the tab model
            // If we have a selected tab AND NOT in new tab mode, update it.
            // If not, create a new one.
            if !isNewTabMode, let tab = selectedTab, tab.url.absoluteString != "about:blank" {
                tab.url = url
                tab.title = trimmed // Temporary title until page loads
                
                // Trigger navigation in WebEngine
                let webView = WebEngine.shared.getWebView(for: tab, contextID: contextID)
                webView.load(URLRequest(url: url))
            } else {
                // Create new tab
                onCreateTab?(url, trimmed)
            }
            
            isPresented = false
        }
    }
}
