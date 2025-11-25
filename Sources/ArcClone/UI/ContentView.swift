import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrowserSpace.name) private var spaces: [BrowserSpace]
    @State private var selectedTab: BrowserTab?
    @State private var selectedSpace: BrowserSpace?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var windowID = UUID()
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if showLibrary {
                LibrarySidebar(selectedSection: $selectedLibrarySection, isPresented: $showLibrary)
            } else {

                VStack(spacing: 0) {
                    // URL Bar
                    HStack(spacing: 8) {
                        Button(action: {
                            isNewTabMode = false
                            showCommandPalette = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedTab?.title ?? "New Tab")
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Text(formatURLForDisplay(selectedTab?.url))
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 10))
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        
                        if selectedTab != nil {
                            Button(action: {
                                if let url = selectedTab?.url.absoluteString {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url, forType: .string)
                                }
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy URL")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    
                    List(selection: $selectedTab) {
                        if let space = selectedSpace {
                            DisclosureGroup(isExpanded: $pinnedSectionExpanded) {
                                if space.pinnedTabs.isEmpty {
                                    Text("Drag to Pin")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(space.pinnedTabs) { tab in
                                        if tab.isFolder {
                                            DisclosureGroup(isExpanded: .constant(true)) {
                                                if let children = tab.children {
                                                    ForEach(children) { child in
                                                        NavigationLink(value: child) {
                                                            TabRowView(tab: child, spaces: spaces, currentSpace: space) { targetSpace in
                                                                moveTabToSpace(tab: child, targetSpace: targetSpace)
                                                            } onDelete: {
                                                                deleteTab(tab: child)
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                TabRowView(tab: tab, spaces: spaces, currentSpace: space) { targetSpace in
                                                    moveTabToSpace(tab: tab, targetSpace: targetSpace)
                                                } onDelete: {
                                                    deleteTab(tab: tab)
                                                }
                                            }
                                        } else {
                                            NavigationLink(value: tab) {
                                                TabRowView(tab: tab, spaces: spaces, currentSpace: space) { targetSpace in
                                                    moveTabToSpace(tab: tab, targetSpace: targetSpace)
                                                } onDelete: {
                                                    deleteTab(tab: tab)
                                                }
                                            }
                                            .draggable(tab.id.uuidString)
                                        }
                                    }
                                    .onMove { indices, newOffset in
                                        moveTab(from: indices, to: newOffset, in: &space.pinnedTabs)
                                    }
                                }
                            } label: {
                                Text("Pinned")
                                    .font(.headline)
                            }
                            .dropDestination(for: String.self) { items, location in
                                return moveTabs(ids: items, toPinned: true)
                            }
                            
                            DisclosureGroup(isExpanded: $todaySectionExpanded) {
                                ForEach(space.todayTabs) { tab in
                                    if tab.isFolder {
                                        DisclosureGroup(isExpanded: .constant(true)) {
                                            if let children = tab.children {
                                                ForEach(children) { child in
                                                    NavigationLink(value: child) {
                                                        TabRowView(tab: child, spaces: spaces, currentSpace: space) { targetSpace in
                                                            moveTabToSpace(tab: child, targetSpace: targetSpace)
                                                        } onDelete: {
                                                            deleteTab(tab: child)
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            TabRowView(tab: tab, spaces: spaces, currentSpace: space) { targetSpace in
                                                moveTabToSpace(tab: tab, targetSpace: targetSpace)
                                            } onDelete: {
                                                deleteTab(tab: tab)
                                            }
                                        }
                                    } else {
                                        NavigationLink(value: tab) {
                                            TabRowView(tab: tab, spaces: spaces, currentSpace: space) { targetSpace in
                                                moveTabToSpace(tab: tab, targetSpace: targetSpace)
                                            } onDelete: {
                                                deleteTab(tab: tab)
                                            }
                                        }
                                        .draggable(tab.id.uuidString)
                                    }
                                }
                                .onMove { indices, newOffset in
                                    moveTab(from: indices, to: newOffset, in: &space.todayTabs)
                                }
                            } label: {
                                Text("Today")
                                    .font(.headline)
                            }
                            .dropDestination(for: String.self) { items, location in
                                return moveTabs(ids: items, toPinned: false)
                            }
                        } else {
                            ContentUnavailableView("No Spaces", systemImage: "square.stack.3d.up")
                        }
                        
                        HStack {
                            Button(action: addTab) {
                                Label("New Tab", systemImage: "plus")
                            }
                            .buttonStyle(.glass)
                            
                            Spacer()
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                        
                        // Bottom Bar: Library + Spaces
                        HStack(spacing: 8) {
                            // Library Button (Icon only)
                            Button(action: {
                                showLibrary = true
                            }) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Library")
                            
                            Spacer()
                            
                            // Space Switcher
                            if spaces.count > 1 {
                                HStack(spacing: 4) {
                                    ForEach(spaces) { space in
                                        Button(action: {
                                            withAnimation {
                                                selectedSpace = space
                                            }
                                        }) {
                                            if let emoji = space.emojiIcon, !emoji.isEmpty {
                                                Text(emoji)
                                                    .font(.system(size: 14))
                                                    .frame(width: 20, height: 20)
                                                    .background(
                                                        Circle()
                                                            .stroke(Color.primary, lineWidth: selectedSpace == space ? 1.5 : 0)
                                                    )
                                            } else {
                                                Circle()
                                                    .fill(Color(hex: space.colorHex))
                                                    .frame(width: 10, height: 10)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.primary, lineWidth: selectedSpace == space ? 1.5 : 0)
                                                    )
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .help(space.name)
                                        .contextMenu {
                                            Button("Rename Space") {
                                                editingSpace = space
                                                newSpaceName = space.name
                                                newSpaceEmoji = space.emojiIcon ?? ""
                                                showRenameSpaceAlert = true
                                            }
                                            
                                            if spaces.count > 1 {
                                                Divider()
                                                Button("Delete Space", role: .destructive) {
                                                    deleteSpace(space)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Button(action: {
                                        createNewSpace()
                                    }) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("New Space")
                                }
                            } else {
                                // Show "New Space" button if only 1 space
                                Button(action: {
                                    createNewSpace()
                                }) {
                                    Image(systemName: "plus.square.on.square")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("New Space")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        } detail: {
            ZStack {
                if showLibrary {
                    LibraryContent(section: selectedLibrarySection, spaces: spaces)
                } else {
                    if let tab = selectedTab {
                        WebView(tab: tab, contextID: windowID)
                            .id(tab.id) // Force recreation when tab changes
                    } else {
                        ContentUnavailableView("Select a Tab", systemImage: "globe")
                    }
                }
            }
            .backgroundExtensionEffect()
        }
        .overlay {
            if showCommandPalette {
                CommandPalette(isPresented: $showCommandPalette, selectedTab: $selectedTab, contextID: windowID, isNewTabMode: isNewTabMode, onOpenLibrary: {
                    showLibrary = true
                }, onCreateTab: { url, title in
                    createNewTab(url: url, title: title)
                })
            }
        }
        .background(
            MouseTrackingView { location in
                handleMouseMove(location: location)
            }
        )
        .onAppear {
            if spaces.isEmpty {
                createDefaultSpace()
            }
            
            selectedSpace = spaces.first
            
            WebEngine.shared.createNewTabHandler = { [self] url in
                createNewTab(url: url, title: url.absoluteString)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if selectedTab?.canGoBack == true {
                    Button(action: {
                        if let tab = selectedTab {
                            WebEngine.shared.goBack(for: tab, contextID: windowID)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
                
                if selectedTab?.canGoForward == true {
                    Button(action: {
                        if let tab = selectedTab {
                            WebEngine.shared.goForward(for: tab, contextID: windowID)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .background(WindowAccessor())
        .edgesIgnoringSafeArea(.top)
        .toolbar(removing: .sidebarToggle)
        // Keyboard Shortcuts
        .background(
            Button("") {
                addTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .hidden()
        )
        .background(
            Button("") {
                editCurrentTab()
            }
            .keyboardShortcut("l", modifiers: .command)
            .hidden()
        )
        .background(
            Button("") {
                reopenLastClosedTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .hidden()
        )
        .background(
            Button("") {
                if let tab = selectedTab {
                    deleteTab(tab: tab)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .hidden()
        )
        .alert("Rename Space", isPresented: $showRenameSpaceAlert) {
            TextField("Space Name", text: $newSpaceName)
            TextField("Emoji", text: $newSpaceEmoji)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let space = editingSpace {
                    space.name = newSpaceName
                    if newSpaceEmoji.count > 0 {
                        space.emojiIcon = String(newSpaceEmoji.prefix(1))
                    } else {
                        space.emojiIcon = nil
                    }
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Enter a new name and an emoji for this space.")
        }
    }
    
    @State private var showCommandPalette = false
    @State private var isNewTabMode = false
    @State private var showLibrary = false
    @State private var selectedLibrarySection: LibrarySection? = .archivedTabs
    
    @State private var recentlyClosedTabs: [BrowserTab] = []
    
    // Section Expansion State
    @State private var pinnedSectionExpanded = true
    @State private var todaySectionExpanded = true
    
    // Space Customization State
    @State private var showRenameSpaceAlert = false
    @State private var editingSpace: BrowserSpace?
    @State private var newSpaceName = ""
    @State private var newSpaceEmoji = ""
    
    private func handleMouseMove(location: CGPoint) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if location.x < 10 {
                if columnVisibility != .all {
                    columnVisibility = .all
                }
            } else if location.x > 260 && columnVisibility == .all {
                columnVisibility = .detailOnly
            }
        }
    }
    
    private func addTab() {
        isNewTabMode = true
        showCommandPalette = true
    }
    
    private func editCurrentTab() {
        isNewTabMode = false
        showCommandPalette = true
    }
    
    private func createNewTab(url: URL, title: String) {
        guard let space = selectedSpace ?? spaces.first else { return }
        let newTab = BrowserTab(url: url, title: title)
        space.todayTabs.append(newTab)
        selectedTab = newTab
    }
    
    private func deleteTab(tab: BrowserTab) {
        guard let space = selectedSpace ?? spaces.first else { return }
        
        // If it's a pinned tab, just reset its URL to the original instead of removing it
        if tab.isPinned {
            // Reset to home page or original URL
            tab.url = URL(string: "https://www.apple.com")! // Or store original URL
            tab.title = "New Tab"
            // The web view will reload when switching back to this tab
            try? modelContext.save()
            return
        }
        
        // Remove from current lists (only for non-pinned tabs)
        if let index = space.todayTabs.firstIndex(of: tab) {
            space.todayTabs.remove(at: index)
        }
        
        // Update state
        tab.isPinned = false
        
        // Add to archived tabs
        space.archivedTabs.append(tab)
        
        if selectedTab == tab {
            selectedTab = nil
        }
        
        try? modelContext.save()
    }
    
    private func reopenLastClosedTab() {
        guard let space = selectedSpace ?? spaces.first, let lastArchived = space.archivedTabs.last else { return }
        
        // Remove from archive
        space.archivedTabs.removeLast()
        
        // Add back to Today
        space.todayTabs.append(lastArchived)
        selectedTab = lastArchived
        
        try? modelContext.save()
    }
    
    private func moveTab(from source: IndexSet, to destination: Int, in tabs: inout [BrowserTab]) {
        tabs.move(fromOffsets: source, toOffset: destination)
        try? modelContext.save()
    }
    
    private func moveTabs(ids: [String], toPinned: Bool) -> Bool {
        guard let space = selectedSpace ?? spaces.first else { return false }
        
        withAnimation {
            for idString in ids {
                guard let uuid = UUID(uuidString: idString) else { continue }
                
                // Find the tab in either list
                var tabToMove: BrowserTab?
                var sourceListIsPinned = false
                
                if let index = space.pinnedTabs.firstIndex(where: { $0.id == uuid }) {
                    tabToMove = space.pinnedTabs[index]
                    sourceListIsPinned = true
                } else if let index = space.todayTabs.firstIndex(where: { $0.id == uuid }) {
                    tabToMove = space.todayTabs[index]
                    sourceListIsPinned = false
                }
                
                guard let tab = tabToMove else { continue }
                
                // If already in the target section, do nothing (reordering is handled by onMove)
                if sourceListIsPinned == toPinned { continue }
                
                // Remove from source
                if sourceListIsPinned {
                    space.pinnedTabs.removeAll(where: { $0.id == uuid })
                } else {
                    space.todayTabs.removeAll(where: { $0.id == uuid })
                }
                
                // Add to destination
                if toPinned {
                    tab.isPinned = true
                    space.pinnedTabs.append(tab)
                } else {
                    tab.isPinned = false
                    space.todayTabs.append(tab)
                }
            }
        }
        
        try? modelContext.save()
        return true
    }
    
    private func moveTabToSpace(tab: BrowserTab, targetSpace: BrowserSpace) {
        guard let currentSpace = selectedSpace ?? spaces.first else { return }
        
        // Remove from current space
        if let index = currentSpace.pinnedTabs.firstIndex(of: tab) {
            currentSpace.pinnedTabs.remove(at: index)
        } else if let index = currentSpace.todayTabs.firstIndex(of: tab) {
            currentSpace.todayTabs.remove(at: index)
        }
        
        // Add to target space (as Today tab by default)
        tab.isPinned = false
        targetSpace.todayTabs.append(tab)
        
        if selectedTab == tab {
            selectedTab = nil
        }
        
        try? modelContext.save()
    }
    
    private func createDefaultSpace() {
        let space = BrowserSpace(name: "Space 1", colorHex: "#FF5733")
        modelContext.insert(space)
        
        let tab1 = BrowserTab(url: URL(string: "https://www.apple.com")!, title: "Apple", isPinned: true)
        space.pinnedTabs.append(tab1)
        
        try? modelContext.save()
    }
    
    private func createNewSpace() {
        let colors = ["#FF5733", "#33FF57", "#3357FF", "#F333FF", "#33FFF3"]
        let newSpace = BrowserSpace(name: "Space \(spaces.count + 1)", colorHex: colors.randomElement() ?? "#000000")
        modelContext.insert(newSpace)
        selectedSpace = newSpace
        try? modelContext.save()
    }
    
    private func deleteSpace(_ space: BrowserSpace) {
        guard spaces.count > 1 else { return }
        
        // If deleting the selected space, switch to another one first
        if selectedSpace == space {
            selectedSpace = spaces.first(where: { $0 != space })
        }
        
        modelContext.delete(space)
        try? modelContext.save()
    }
    
    private func formatURLForDisplay(_ url: URL?) -> String {
        guard let url = url else { return "Search or enter URL" }
        
        var displayString = url.absoluteString
        
        // Remove protocol
        displayString = displayString.replacingOccurrences(of: "https://", with: "")
        displayString = displayString.replacingOccurrences(of: "http://", with: "")
        
        // Remove www.
        if displayString.hasPrefix("www.") {
            displayString = String(displayString.dropFirst(4))
        }
        
        // Remove trailing slash if it's the only path
        if displayString.hasSuffix("/") && displayString.filter({ $0 == "/" }).count == 1 {
            displayString = String(displayString.dropLast())
        }
        
        return displayString
    }
}

struct TabRowView: View {
    @Bindable var tab: BrowserTab
    var spaces: [BrowserSpace]
    var currentSpace: BrowserSpace
    var onMoveToSpace: (BrowserSpace) -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showRenameAlert = false
    @State private var showEmojiAlert = false
    @State private var newTitle = ""
    @State private var newEmoji = ""
    
    var body: some View {
        HStack {
            if tab.isFolder {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
            } else {
                if let emoji = tab.emojiIcon, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 12))
                        .frame(width: 16, height: 16)
                } else {
                    // Favicon
                    AsyncImage(url: getFaviconURL(for: tab.url)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 16, height: 16)
                }
            }
            
            if isEditingTitle {
                TextField("Title", text: $editedTitle, onCommit: {
                    if !editedTitle.isEmpty {
                        tab.title = editedTitle
                    }
                    isEditingTitle = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            } else {
                Text(tab.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if isHovering {
                // For pinned tabs, only show close button if they have a session (been navigated)
                // For regular tabs, always show close button
                let shouldShowClose = !tab.isPinned || (tab.canGoBack || tab.canGoForward)
                
                if shouldShowClose {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Rename Tab") {
                editedTitle = tab.title
                isEditingTitle = true
            }
            
            Button("Change Icon") {
                newEmoji = tab.emojiIcon ?? ""
                showEmojiAlert = true
            }
            
            Menu("Move to Space") {
                ForEach(spaces) { space in
                    if space != currentSpace {
                        Button(space.name) {
                            onMoveToSpace(space)
                        }
                    }
                }
            }
        }
        .alert("Rename Tab", isPresented: $showRenameAlert) {
            TextField("New Title", text: $newTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                tab.title = newTitle
            }
        }
        .alert("Change Icon", isPresented: $showEmojiAlert) {
            TextField("Emoji", text: $newEmoji)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                // Simple validation to ensure it's likely an emoji or short string
                if newEmoji.count > 0 {
                    tab.emojiIcon = String(newEmoji.prefix(1))
                } else {
                    tab.emojiIcon = nil
                }
            }
        } message: {
            Text("Enter an emoji to use as the icon.")
        }
    }
    
    private func getFaviconURL(for url: URL) -> URL? {
        guard let host = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)")
    }
}

// Helper for Hex Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Configures an image (or view) to blur and extend under a sidebar or inspector panel.
    func backgroundExtensionEffect() -> some View {
        self
            .ignoresSafeArea()
    }
    
    /// Applies Liquid Glass to the view.
    func glassEffect() -> some View {
        self.background(.ultraThinMaterial)
    }
    
    /// Applies Liquid Glass to the view with a specific ID for morphing.
    func glassEffectID(_ id: AnyHashable, in namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}
