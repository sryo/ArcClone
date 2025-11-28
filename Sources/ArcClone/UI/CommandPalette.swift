import SwiftUI

struct CommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: BrowserTab?
    var contextID: UUID
    var isNewTabMode: Bool = false
    var onOpenLibrary: (() -> Void)? = nil
    var onCreateTab: ((URL, String) -> Void)? = nil

    @Environment(\.modelContext) var modelContext
    @StateObject private var suggestionService = SuggestionService()
    @State private var urlString: String = ""
    @State private var isFocused: Bool = false
    @State private var selectedSuggestionID: UUID?

    var body: some View {
        ZStack {
            // Background overlay that closes palette when tapped
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isPresented = false
                }

            // Dark overlay
            Color.black.opacity(0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Always centered presentation
            VStack(spacing: 0) {
                Spacer()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    unifiedContent
                }
                .frame(maxWidth: 600)

                Spacer()
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }

            if !isNewTabMode, let tab = selectedTab, tab.url.absoluteString != "about:blank" {
                urlString = tab.url.absoluteString
            } else {
                urlString = ""
            }
        }
    }

    private var unifiedContent: some View {
        VStack(spacing: 0) {
            CommandPaletteTextField(
                text: $urlString,
                placeholder: "Search or Enter URL...",
                isFocused: $isFocused,
                onMoveUp: { selectPreviousSuggestion() },
                onMoveDown: { selectNextSuggestion() },
                onTab: { selectNextSuggestion() },
                onCancel: { isPresented = false },
                onCommit: {
                    if let selectedID = selectedSuggestionID,
                        let suggestion = suggestionService.suggestions.first(where: {
                            $0.id == selectedID
                        })
                    {
                        handleSuggestion(suggestion)
                    } else {
                        navigateToUrl()
                    }
                },
                onNumberKey: { number in
                    let index = number - 1
                    if index < suggestionService.suggestions.count {
                        let suggestion = suggestionService.suggestions[index]
                        handleSuggestion(suggestion)
                    }
                }
            )
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onChange(of: urlString) { oldValue, newValue in
                suggestionService.fetchSuggestions(for: newValue, modelContext: modelContext)
                selectedSuggestionID = nil
            }

            if !suggestionService.suggestions.isEmpty {
                Divider()
                    .background(Color.primary.opacity(0.08))

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(suggestionService.suggestions.enumerated()), id: \.element.id)
                        { index, suggestion in
                            suggestionRow(index: index, suggestion: suggestion)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 320)
            }
        }
        .background(Color.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .padding(.horizontal, 40)
        .padding(.top, 0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8),
            value: suggestionService.suggestions.isEmpty)
    }

    // Helper for glass effect that handles OS version check internally if needed,
    // though for this specific unified view we might just use a modifier.
    // However, since we are replacing the old structure, let's define a clean modifier or use the existing helper logic adapted.

    private func glassBackgroundEffect() -> some View {
        glassContainer(tint: Color.accentColor.opacity(0.08)) {
            Color.clear
        }
    }

    @ViewBuilder
    private func glassContainer<Content: View>(tint: Color, @ViewBuilder content: () -> Content)
        -> some View
    {
        if #available(macOS 26.0, *) {
            content()
                .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 14))
        } else {
            content()
                .background(.ultraThinMaterial)
                .cornerRadius(14)
        }
    }

    private func suggestionRow(index: Int, suggestion: SuggestionItem) -> some View {
        SuggestionRowView(
            index: index,
            suggestion: suggestion,
            isSelected: selectedSuggestionID == suggestion.id,
            onTap: { handleSuggestion(suggestion) }
        )
    }
}

struct SuggestionRowView: View {
    let index: Int
    let suggestion: SuggestionItem
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: suggestion.icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(suggestion.title)
                        .foregroundColor(.primary)
                    if let description = suggestion.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if suggestion.type != .search, let url = suggestion.url {
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
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }

                if index < 9 {
                    HStack(spacing: 2) {
                        Image(systemName: "command")
                            .font(.system(size: 10))
                        Text("\(index + 1)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isSelected {
                        Color.accentColor.opacity(0.25)
                    } else if isHovering {
                        Color.white.opacity(0.08)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - CommandPalette Helper Methods
extension CommandPalette {
    private func selectNextSuggestion() {
        guard !suggestionService.suggestions.isEmpty else { return }

        if let currentID = selectedSuggestionID,
            let index = suggestionService.suggestions.firstIndex(where: { $0.id == currentID })
        {
            let nextIndex = min(index + 1, suggestionService.suggestions.count - 1)
            selectedSuggestionID = suggestionService.suggestions[nextIndex].id
        } else {
            selectedSuggestionID = suggestionService.suggestions.first?.id
        }
    }

    private func selectPreviousSuggestion() {
        guard !suggestionService.suggestions.isEmpty else { return }

        if let currentID = selectedSuggestionID,
            let index = suggestionService.suggestions.firstIndex(where: { $0.id == currentID })
        {
            let prevIndex = max(index - 1, 0)
            selectedSuggestionID = suggestionService.suggestions[prevIndex].id
        } else {
            selectedSuggestionID = suggestionService.suggestions.last?.id
        }
    }

    private func handleSuggestion(_ suggestion: SuggestionItem) {
        if suggestion.type == .tab, suggestion.url != nil {
            // Switch to existing tab
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
        let trimmed = urlString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
            let query =
                trimmed.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
                ?? trimmed
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
            // If current tab is pinned, always create a new tab
            if let tab = selectedTab, tab.isPinned {
                onCreateTab?(url, trimmed)
            }
            // In new tab mode OR no selected tab, create new tab
            else if isNewTabMode || selectedTab == nil {
                onCreateTab?(url, trimmed)
            } else if let tab = selectedTab {
                // Update existing non-pinned tab
                tab.url = url
                tab.title = trimmed  // Temporary title until page loads
            }

            isPresented = false
        }
    }
}
