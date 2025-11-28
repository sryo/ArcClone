import Foundation

import SwiftData
import SwiftUI

enum SuggestionType: String {
    case tab = "Switch to Tab"
    case history = "History"
    case search = "Search"
}

struct SuggestionItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: URL?
    let type: SuggestionType
    let icon: String
    var description: String? = nil
    var imageURL: URL? = nil
    
    init(title: String, url: URL?, type: SuggestionType, icon: String, description: String? = nil, imageURL: URL? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.type = type
        self.icon = icon
        self.description = description
        self.imageURL = imageURL
    }
}

@MainActor
class SuggestionService: ObservableObject {
    @Published var suggestions: [SuggestionItem] = []
    private var fetchTask: Task<Void, Never>?
    
    func fetchSuggestions(for query: String, modelContext: ModelContext) {
        fetchTask?.cancel()
        guard !query.isEmpty else {
            self.suggestions = []
            return
        }
        
        fetchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            
            let results = await buildSuggestions(for: query, modelContext: modelContext)
            guard !Task.isCancelled else { return }
            self.suggestions = results
        }
    }
    
    private func buildSuggestions(for query: String, modelContext: ModelContext) async -> [SuggestionItem] {
        var newSuggestions: [SuggestionItem] = []
        var seenURLs = Set<String>() // Track normalized URLs to prevent duplicates
        let lowerQuery = query.lowercased()
        
        let descriptor = FetchDescriptor<BrowserSpace>()
        if let spaces = try? modelContext.fetch(descriptor), let space = spaces.first {
            let allTabs = space.pinnedTabs + space.todayTabs
            let matchingTabs = allTabs.filter { tab in
                tab.title.lowercased().contains(lowerQuery) ||
                tab.url.absoluteString.lowercased().contains(lowerQuery)
            }
            
            for tab in matchingTabs {
                let normalizedURL = normalizedURLString(from: tab.url)
                
                // Only add if we haven't seen this URL before
                if !seenURLs.contains(normalizedURL) {
                    seenURLs.insert(normalizedURL)
                    newSuggestions.append(SuggestionItem(
                        title: tab.title,
                        url: tab.url,
                        type: .tab,
                        icon: tab.emojiIcon ?? "macwindow"
                    ))
                }
            }
        }
        
        let historyDescriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate<HistoryEntry> { entry in
                entry.title?.localizedStandardContains(query) == true ||
                entry.urlString.localizedStandardContains(query) == true
            },
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        
        // Fetch more items initially to allow for deduplication
        var historyItems: [HistoryEntry] = []
        if let history = try? modelContext.fetch(historyDescriptor) {
            historyItems = Array(history.prefix(50))
        }
        
        var addedHistoryCount = 0
        for entry in historyItems {
            guard addedHistoryCount < 5 else { break }
            guard let entryURL = URL(string: entry.urlString) else { continue }
            let normalizedURL = normalizedURLString(from: entryURL)
            
            // Only add if we haven't seen this URL before
            if !seenURLs.contains(normalizedURL) {
                seenURLs.insert(normalizedURL)
                newSuggestions.append(SuggestionItem(
                    title: entry.title ?? entry.urlString,
                    url: entryURL,
                    type: .history,
                    icon: "clock"
                ))
                addedHistoryCount += 1
            }
        }
        
        // Use a client that returns rich data if possible, or just parse what we can.
        // Google's 'chrome' client returns JSON with more details.
        let urlString = "https://suggestqueries.google.com/complete/search?client=chrome&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: urlString) {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                   json.count > 1,
                   let suggestionsList = json[1] as? [String] {
                    
                    // The 'chrome' client returns: [query, [suggestions], [descriptions], [], [types], ...]
                    // Index 2 might contain descriptions/URLs.
                    let descriptions = (json.count > 2) ? (json[2] as? [String]) : nil
                    
                    for (index, suggestion) in suggestionsList.prefix(5).enumerated() {
                        var desc: String? = nil
                        if let descs = descriptions, index < descs.count, !descs[index].isEmpty {
                            desc = descs[index]
                        }
                        
                        newSuggestions.append(SuggestionItem(
                            title: suggestion,
                            url: nil,
                            type: .search,
                            icon: "magnifyingglass",
                            description: desc
                        ))
                    }
                }
            }
        }
        
        return newSuggestions
    }
    
    private func normalizedURLString(from url: URL) -> String {
        var string = url.absoluteString.lowercased()
        
        // Remove scheme
        if let schemeRange = string.range(of: "://") {
            string.removeSubrange(..<schemeRange.upperBound)
        }
        
        // Remove www.
        if string.hasPrefix("www.") {
            string.removeFirst(4)
        }
        
        // Remove trailing slash
        if string.hasSuffix("/") {
            string.removeLast()
        }
        
        return string
    }
}
