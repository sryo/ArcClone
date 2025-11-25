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
    @Binding var selectedSection: LibrarySection?
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            HStack {
                Text("Library")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            List(LibrarySection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                }
            }
            
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
                ContentUnavailableView("Media", systemImage: "photo.on.rectangle", description: Text("Images, videos, and screenshots will appear here."))
            case .downloads:
                ContentUnavailableView("Downloads", systemImage: "arrow.down.circle", description: Text("Your downloaded files will appear here."))
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
    }
}
