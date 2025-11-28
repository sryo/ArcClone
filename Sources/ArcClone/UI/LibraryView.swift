import SwiftUI
import SwiftData

enum LibrarySection: String, CaseIterable, Identifiable {
    case media = "Media"
    case downloads = "Downloads"
    case spaces = "Spaces"
    case archivedTabs = "Archived Tabs"
    
    var id: String { self.rawValue }
    var icon: String {
        switch self {
        case .media: return "photo.on.rectangle"
        case .downloads: return "arrow.down.circle"
        case .spaces: return "square.stack.3d.up"
        case .archivedTabs: return "archivebox"
        }
    }
}

struct LibrarySidebar: View {
    var onBack: () -> Void
    var onSelectSection: (LibrarySection) -> Void
    
    var body: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Text("Library")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding()
            
            List(LibrarySection.allCases) { section in
                Button(action: { onSelectSection(section) }) {
                    Label(section.rawValue, systemImage: section.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            
            Spacer()
            
            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Passwords-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label("Passwords", systemImage: "key")
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.bottom)
        }
    }
}

struct LibraryContent: View {
    let section: LibrarySection?
    let spaces: [BrowserSpace]
    
    var body: some View {
        if let section = section {
            switch section {
            case .media:
                MediaGridView()
            case .downloads:
                DownloadsView()
            case .spaces:
                SpacesListView(spaces: spaces)
            case .archivedTabs:
                ArchivedTabsView(spaces: spaces)
            }
        } else {
            ContentUnavailableView("Select a Section", systemImage: "books.vertical")
        }
    }
}

struct SpacesListView: View {
    let spaces: [BrowserSpace]
    
    var body: some View {
        List {
            ForEach(spaces) { space in
                Section(space.name) {
                    DisclosureGroup("Pinned Tabs") {
                        ForEach(space.pinnedTabs) { tab in
                            Text(tab.title)
                        }
                    }
                    DisclosureGroup("Today Tabs") {
                        ForEach(space.todayTabs) { tab in
                            Text(tab.title)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct ArchivedTabsView: View {
    let spaces: [BrowserSpace]
    
    var body: some View {
        List {
            ForEach(spaces) { space in
                Section(space.name) {
                    if space.archivedTabs.isEmpty {
                        Text("No archived tabs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(space.archivedTabs) { tab in
                            HStack {
                                Text(tab.title)
                                Spacer()
                                Text(tab.url.host ?? "")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct DownloadsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    
    var body: some View {
        List {
            if downloadManager.downloads.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Your downloaded files will appear here."))
            } else {
                ForEach(downloadManager.groupedDownloads, id: \.group) { groupData in
                    DisclosureGroup(groupData.group.rawValue) {
                        ForEach(groupData.items) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.filename)
                                        .font(.headline)
                                    
                                    if item.state == .downloading {
                                        ProgressView(value: item.progress)
                                            .progressViewStyle(.linear)
                                    } else if case .failed(let error) = item.state {
                                        Text(error.localizedDescription)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text("Completed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if item.state == .finished {
                                    Button(action: {
                                        if let url = item.destinationURL {
                                            NSWorkspace.shared.activateFileViewerSelecting([url])
                                        }
                                    }) {
                                        Image(systemName: "magnifyingglass")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

