import Foundation

import SwiftData
import SwiftUI

enum SuggestionType: String {
    case tab = "Switch to Tab"
    case history = "History"
    case search = "Search"
}

struct SuggestionItem: Identifiable, Hashable {
    var id: String {
        return "\(type.rawValue)_\(url?.absoluteString ?? "")_\(title)"
    }
    let title: String
    let url: URL?
    let type: SuggestionType
    let icon: String
}

@MainActor
class SuggestionService: ObservableObject {
    @Published var suggestions: [SuggestionItem] = []
    
    func fetchSuggestions(for query: String, modelContext: ModelContext) {
        guard !query.isEmpty else {
            self.suggestions = []
            return
        }
        
        Task {
            var newSuggestions: [SuggestionItem] = []
            let lowerQuery = query.lowercased()
            
            // 1. Active & Pinned Tabs (Switch to Tab)
            // We need to fetch spaces from the context
            let descriptor = FetchDescriptor<BrowserSpace>()
            if let spaces = try? modelContext.fetch(descriptor), let space = spaces.first {
                let allTabs = space.pinnedTabs + space.todayTabs
                let matchingTabs = allTabs.filter { tab in
                    tab.title.lowercased().contains(lowerQuery) ||
                    tab.url.absoluteString.lowercased().contains(lowerQuery)
                }
                
                for tab in matchingTabs {
                    newSuggestions.append(SuggestionItem(
                        title: tab.title,
                        url: tab.url,
                        type: .tab,
                        icon: tab.emojiIcon ?? "macwindow"
                    ))
                }
            }
            
            // 2. History
            // Fetch history entries matching query
            let historyDescriptor = FetchDescriptor<HistoryEntry>(
                predicate: #Predicate<HistoryEntry> { entry in
                    entry.title?.localizedStandardContains(query) == true ||
                    entry.urlString.localizedStandardContains(query) == true
                },
                sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
            )
            // Limit to 5 history items
            var historyItems: [HistoryEntry] = []
            if let history = try? modelContext.fetch(historyDescriptor) {
                historyItems = Array(history.prefix(5))
            }
            
            for entry in historyItems {
                // Avoid duplicates if already in tabs
                if !newSuggestions.contains(where: { $0.url == entry.url }) {
                    newSuggestions.append(SuggestionItem(
                        title: entry.title ?? entry.urlString,
                        url: entry.url,
                        type: .history,
                        icon: "clock"
                    ))
                }
            }
            
            // 3. Google Suggestions
            let urlString = "http://suggestqueries.google.com/complete/search?client=firefox&q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: urlString) {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                       json.count > 1,
                       let googleSuggestions = json[1] as? [String] {
                        
                        for suggestion in googleSuggestions.prefix(5) {
                            newSuggestions.append(SuggestionItem(
                                title: suggestion,
                                url: nil, // Search query
                                type: .search,
                                icon: "magnifyingglass"
                            ))
                        }
                    }
                }
            }
            
            self.suggestions = newSuggestions
        }
    }
}
