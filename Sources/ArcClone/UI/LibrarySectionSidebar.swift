import SwiftUI

struct LibrarySectionSidebar: View {
    let section: LibrarySection
    let spaces: [BrowserSpace]
    @ObservedObject var webEngine: WebEngine
    var onBack: () -> Void
    var onSelectSpace: (BrowserSpace) -> Void
    var onClearArchivedTabs: ((BrowserSpace) -> Void)? = nil
    
    @State private var searchText = ""
    
    var body: some View {
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredSpaces = filteredSpaces(for: searchTerm)
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Text(section.rawValue)
                    .font(.headline)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding()
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            ScrollView {
                switch section {
                case .spaces:
                    SpacesSidebarList(spaces: filteredSpaces, searchTerm: searchTerm, onSelectSpace: onSelectSpace)
                case .downloads:
                    DownloadsSidebarList(searchTerm: searchTerm)
                case .archivedTabs:
                    ArchivedTabsSidebarList(spaces: filteredSpaces, searchTerm: searchTerm, onClearArchivedTabs: onClearArchivedTabs)
                case .media:
                    MediaSidebarList(searchTerm: searchTerm)
                }
                
                if searchTerm.count > 0 && filteredSpaces.isEmpty && section != .downloads && section != .media {
                    Text("No results")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
    
    private func filteredSpaces(for term: String) -> [BrowserSpace] {
        guard !term.isEmpty else { return spaces }
        return spaces.filter { space in
            let nameMatch = space.name.lowercased().contains(term)
            let pinnedMatch = space.pinnedTabs.contains { $0.title.lowercased().contains(term) }
            let todayMatch = space.todayTabs.contains { $0.title.lowercased().contains(term) }
            let archivedMatch = space.archivedTabs.contains { $0.title.lowercased().contains(term) || ($0.url.host ?? "").lowercased().contains(term) }
            return nameMatch || pinnedMatch || todayMatch || archivedMatch
        }
    }
}

struct SpacesSidebarList: View {
    let spaces: [BrowserSpace]
    let searchTerm: String
    var onSelectSpace: (BrowserSpace) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(spaces) { space in
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { onSelectSpace(space) }) {
                        HStack {
                            Text(space.emojiIcon ?? "")
                            Text(space.name)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    let filteredPinned = filteredTabs(space.pinnedTabs)
                    if !filteredPinned.isEmpty {
                        Text("Pinned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        
                        ForEach(filteredPinned) { tab in
                            HStack {
                                if let icon = tab.emojiIcon {
                                    Text(icon).font(.caption)
                                } else {
                                    Image(systemName: "globe").font(.caption)
                                }
                                Text(tab.title)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                            .padding(.leading, 16)
                            .padding(.vertical, 2)
                        }
                    }
                    
                    let filteredToday = filteredTabs(space.todayTabs)
                    if !filteredToday.isEmpty && searchTerm.isEmpty == false {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        ForEach(filteredToday) { tab in
                            HStack {
                                if let icon = tab.emojiIcon {
                                    Text(icon).font(.caption)
                                } else {
                                    Image(systemName: "globe").font(.caption)
                                }
                                Text(tab.title)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                
                                if tab.isPlayingAudio {
                                    Spacer()
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.leading)
            }
        }
        .padding(.top)
    }
    
    private func filteredTabs(_ tabs: [BrowserTab]) -> [BrowserTab] {
        guard !searchTerm.isEmpty else { return tabs }
        return tabs.filter { $0.title.lowercased().contains(searchTerm) }
    }
}

struct DownloadsSidebarList: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    let searchTerm: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let downloads = filteredDownloads()
            if downloads.isEmpty {
                Text("No active downloads")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(downloads) { download in
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(download.filename)
                            .lineLimit(1)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top)
    }
    
    private func filteredDownloads() -> [DownloadManager.DownloadItem] {
        guard !searchTerm.isEmpty else { return downloadManager.downloads }
        return downloadManager.downloads.filter { $0.filename.lowercased().contains(searchTerm) }
    }
}

struct ArchivedTabsSidebarList: View {
    let spaces: [BrowserSpace]
    let searchTerm: String
    var onClearArchivedTabs: ((BrowserSpace) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(spaces) { space in
                let filteredTabs = filteredArchivedTabs(space.archivedTabs)
                if !filteredTabs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(space.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let onClear = onClearArchivedTabs {
                                Button("Clear") {
                                    onClear(space)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        ForEach(filteredTabs) { tab in
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(tab.title)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        }
                    }
                    Divider().padding(.leading)
                }
            }
        }
        .padding(.top)
    }
    
    private func filteredArchivedTabs(_ tabs: [BrowserTab]) -> [BrowserTab] {
        guard !searchTerm.isEmpty else { return tabs }
        return tabs.filter {
            $0.title.lowercased().contains(searchTerm) ||
            ($0.url.host ?? "").lowercased().contains(searchTerm)
        }
    }
}

struct MediaSidebarList: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    let searchTerm: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let mediaItems = filteredMedia()
            if mediaItems.isEmpty {
                if searchTerm.isEmpty {
                    ContentUnavailableView(
                        "No Media",
                        systemImage: "photo.on.rectangle",
                        description: Text("Downloaded images will appear here.")
                    )
                } else {
                    Text("No results")
                        .foregroundColor(.secondary)
                        .padding()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                        ForEach(mediaItems) { mediaItem in
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([mediaItem.url])
                            }) {
                                VStack(spacing: 4) {
                                    if let thumbnail = mediaItem.thumbnail {
                                        Image(nsImage: thumbnail)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(6)
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    
                                    Text(mediaItem.filename)
                                        .font(.caption2)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 100)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top)
    }
    
    private var columns: [GridItem] {
        [ GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12) ]
    }
    
    private func filteredMedia() -> [DownloadManager.MediaItem] {
        guard !searchTerm.isEmpty else { return downloadManager.mediaItems }
        return downloadManager.mediaItems.filter {
            $0.filename.lowercased().contains(searchTerm)
        }
    }
}
