import SwiftUI
import SwiftData

@available(macOS 26.0, *)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrowserSpace.orderIndex) private var spaces: [BrowserSpace]
    @Query(sort: \BrowserProfile.createdDate) private var profiles: [BrowserProfile]
    @StateObject private var store = BrowserStore()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var urlCopiedFlash = false
    @State private var sidebarDrag: CGFloat = 0
    // @State private var scrolledID: Int? // Removed
    @State private var dynamicSidebarWidth: CGFloat = 260
    @ObservedObject private var webEngine = WebEngine.shared
    
    @State private var hostingWindow: NSWindow?
    @State private var showOnboarding: Bool = false
    @State private var downloadAnimations: [DownloadAnimation] = []

    @State private var libraryButtonFrame: CGRect = .zero
    
    // New Space Gesture State
    @State private var newSpaceProgress: CGFloat = 0
    @State private var newSpaceGestureLocation: CGPoint = .zero
    @State private var lastHapticProgress: CGFloat = 0
    @State private var overscrollSide: ScrollWheelPager.OverscrollSide = .end
    
    private let minSidebarWidth: CGFloat = 200
    private let idealSidebarWidth: CGFloat = 260
    private let maxSidebarWidth: CGFloat = 400
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Sidebar layout is fragile; keep it in split view instead of overlays.
            NavigationSplitView(columnVisibility: $columnVisibility) {
                ZStack {
                    sidebarBackground
                        .animation(.easeInOut(duration: 0.18), value: store.selectedSpace?.id)
                        .animation(.easeInOut(duration: 0.18), value: store.librarySection)
                    
                    VStack(spacing: 0) {
                        // Use opacity to avoid structural changes during scroll
                        urlBar
                            .opacity(store.sidebarIndex > 0 ? 1 : 0)
                        
                        sidebarPager
                        
                        bottomBar
                    }
                    .padding(.top, 0)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onChange(of: proxy.size.width, initial: true) { _, newWidth in
                                    dynamicSidebarWidth = newWidth
                                }
                        }
                    )
                    
                    // New Space / Close Library Gesture Overlay
                    if newSpaceProgress > 0 {
                        let isCloseLibrary = overscrollSide == .start
                        RadialProgressView(progress: newSpaceProgress, icon: isCloseLibrary ? "sidebar.left" : "plus")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                }
                .navigationSplitViewColumnWidth(min: minSidebarWidth, ideal: idealSidebarWidth, max: maxSidebarWidth)
            } detail: {
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            if store.showCommandPalette {
                CommandPalette(
                    isPresented: $store.showCommandPalette,
                    selectedTab: $store.selectedTab,
                    contextID: store.windowID,
                    isNewTabMode: store.isNewTabMode,
                    onOpenLibrary: {
                        withAnimation {
                            store.openLibrary()
                        }
                    },
                    onCreateTab: { url, title in
                        _ = store.createTab(url: url, title: title, spaces: spaces)
                    }
                )
            }
            
            // Download animations overlay
            DownloadAnimationContainer(animations: $downloadAnimations)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            

            

        }
        .coordinateSpace(name: "content")
        .background(WindowAccessor { window in
            self.hostingWindow = window
        })
        .edgesIgnoringSafeArea(.top)
        .background(keyboardShortcuts)
        .background(keyboardShortcuts)
        .sheet(item: $store.editingSpace) { space in
            SpaceEditView(space: space, isPresented: Binding(
                get: { store.editingSpace != nil },
                set: { if !$0 { store.editingSpace = nil } }
            ))
            .environmentObject(store)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            columnVisibility = .all
            store.attachContext(modelContext)
            if spaces.isEmpty {
                createDefaultSpace()
            }
            store.syncSelection(with: spaces)
            
            // Check for first launch
            let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            if !hasLaunchedBefore {
                showOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            }
            
            WebEngine.shared.createNewTabHandler = { [self] url in
                _ = store.createTab(url: url, title: url.absoluteString, spaces: spaces)
            }
            
            WebEngine.shared.openInNewWindowHandler = { url in
                // Open URL in a new browser window
                let workspace = NSWorkspace.shared
                workspace.open(url)
            }
            
            // Monitor window activation to claim WebView ownership
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { [weak store] notification in
                guard let window = notification.object as? NSWindow,
                      let selfWindow = hostingWindow,
                      window === selfWindow else {
                    return
                }
                
                // When this window becomes active, claim ownership of the selected tab's WebView
                Task { @MainActor in
                    guard let store = store else { return }
                    if let tab = store.selectedTab {
                        _ = WebEngine.shared.getWebView(for: tab, contextID: store.windowID, profileID: store.selectedSpace?.profile?.id)
                    }
                }
            }
            
            // Session Restore: Reset all pinned tabs to their pinned URL
            for space in spaces {
                for tab in space.pinnedTabs {
                    store.resetTabToPinnedURL(tab)
                }
            }
            
            // Startup Autofocus: If no tab is selected, open Command Palette
            if store.selectedTab == nil {
                store.isNewTabMode = true
                store.showCommandPalette = true
            }
            
            // Initialize scroll position
            // scrolledID = store.sidebarIndex // Removed
            
            NotificationCenter.default.addObserver(forName: .shouldClearTabs, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let sinceDate = userInfo["since"] as? Date {
                    Task { @MainActor in
                        store.clearTabs(since: sinceDate, spaces: spaces)
                    }
                }
            }
        }
        .onChange(of: spaces) { _, _ in
            store.syncSelection(with: spaces)
        }
        .onChange(of: webEngine.downloadStartTrigger) { _, _ in
            // Calculate start and end points for animation
            guard let window = hostingWindow,
                  let contentView = window.contentView else { return }
            
            // Start from center-top of content view (where download started)
            // Use content view bounds to match the coordinate space of libraryButtonFrame
            let startPoint = CGPoint(
                x: contentView.bounds.width / 2,
                y: 100 // Near top of window
            )
            
            // End at library button's actual location (in "content" coordinate space)
            let endPoint = CGPoint(
                x: libraryButtonFrame.midX,
                y: libraryButtonFrame.midY
            )
            
            downloadAnimations.append(DownloadAnimation(
                startPoint: startPoint,
                endPoint: endPoint
            ))
        }
        .onChange(of: store.selectedTab) { oldTab, newTab in
            // Handle Picture-in-Picture on tab switch
            if let old = oldTab, !webEngine.isInPiP(tab: old) {
                // Check if previous tab has a playing video
                Task { @MainActor in
                    if await webEngine.hasPlayingVideo(for: old) {
                        await webEngine.enterPiP(for: old)
                    }
                }
            }
            
            if let new = newTab, webEngine.isInPiP(tab: new) {
                // Returning to a tab in PiP, exit PiP
                Task { @MainActor in
                    await webEngine.exitPiP(for: new)
                }
            }
        }
    }
    
    private var sidebarPages: [SidebarPage] {
        var pages: [SidebarPage] = [.library]
        pages.append(contentsOf: spaces.map { SidebarPage.space($0.id) })
        return pages
    }
    
    @State private var visualPageIndex: CGFloat = 0
    
    private var sidebarPager: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(sidebarPages.enumerated()), id: \.offset) { index, page in
                    sidebarPageView(for: page)
                        .frame(width: dynamicSidebarWidth)
                        .id(index)
                }
            }
            .offset(x: -visualPageIndex * dynamicSidebarWidth)
        }
        .background(
            ScrollWheelPager(
                visualPageIndex: $visualPageIndex,
                targetPageIndex: Binding(
                    get: { store.sidebarIndex },
                    set: { _ in } // Read-only for the pager's internal reference
                ),
                pageCount: sidebarPages.count,
                pageWidth: dynamicSidebarWidth,
                onSnap: { newIndex in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        visualPageIndex = CGFloat(newIndex)
                    }
                    if newIndex != store.sidebarIndex {
                        updateSidebarIndex(newIndex)
                    }
                },
                onOverscroll: { overscrollData in
                    if let (side, progress, location) = overscrollData {
                        newSpaceProgress = progress
                        overscrollSide = side
                        
                        // Haptic feedback on progress
                        if abs(newSpaceProgress - lastHapticProgress) > 0.1 {
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            lastHapticProgress = newSpaceProgress
                        }
                        
                        // Convert window location to local coordinates
                        if let window = hostingWindow {
                            let windowHeight = window.contentView?.bounds.height ?? 0
                            newSpaceGestureLocation = CGPoint(x: location.x, y: windowHeight - location.y)
                        }
                        
                        if newSpaceProgress >= 1.0 {
                            // Trigger action
                            newSpaceProgress = 0
                            lastHapticProgress = 0
                            // Haptic feedback - Success
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            
                            switch side {
                            case .start:
                                // Close library - navigate back to selected space
                                if let space = store.selectedSpace ?? spaces.first {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        store.select(space: space, spaces: spaces)
                                        updateSidebarIndex(pageIndex(for: space))
                                    }
                                }
                            case .end:
                                // Create new space
                                if let newSpace = store.createSpace(spaces: spaces, profiles: profiles) {
                                    withAnimation {
                                        store.select(space: newSpace, spaces: spaces)
                                        updateSidebarIndex(pageIndex(for: newSpace))
                                    }
                                }
                            }
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            newSpaceProgress = 0
                        }
                        lastHapticProgress = 0
                    }
                }
            )
        )
        .onChange(of: store.sidebarIndex) { _, newIndex in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                visualPageIndex = CGFloat(newIndex)
            }
        }
        .onAppear {
            visualPageIndex = CGFloat(store.sidebarIndex)
        }
    }
    
    @ViewBuilder
    private func sidebarPageView(for page: SidebarPage) -> some View {
        Group {
            switch page {
            case .library:
                if let section = store.librarySection {
                    LibrarySectionSidebar(
                        section: section,
                        spaces: spaces,
                        webEngine: webEngine,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.librarySection = nil
                            }
                        },
                        onSelectSpace: { space in
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.select(space: space, spaces: spaces)
                                updateSidebarIndex(pageIndex(for: space))
                            }
                        },
                        onClearArchivedTabs: { space in
                            store.clearArchivedTabs(for: space)
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    LibrarySidebar(
                        onBack: {
                            if let space = store.selectedSpace ?? spaces.first {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    store.select(space: space, spaces: spaces)
                                    updateSidebarIndex(pageIndex(for: space))
                                }
                            }
                        },
                        onSelectSection: { section in
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.openLibrarySection(section)
                            }
                        }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            case .space(let id):
                if let space = spaces.first(where: { $0.id == id }) {
                    tabList(for: space)
                } else {
                    Color.clear
                }
            }
        }
    }
    
    
    private var urlBar: some View {
        Button(action: {
            store.isNewTabMode = false
            store.showCommandPalette = true
        }) {
            HStack(spacing: 8) {
                // Image(systemName: "magnifyingglass")
                //     .foregroundColor(.secondary)
                //     .font(.system(size: 12, weight: .medium))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedTab?.title ?? "Search or Enter URL")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if let url = store.selectedTab?.url, url.absoluteString != "about:blank" {
                        Text(store.formatURLForDisplay(url))
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                }
                
                Spacer()
                
                if store.selectedTab != nil {
                    Button(action: {
                        if let url = store.selectedTab?.url.absoluteString {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                            withAnimation(.easeInOut(duration: 0.15)) {
                                urlCopiedFlash.toggle()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    urlCopiedFlash = false
                                }
                            }
                        }
                    }) {
                        Image(systemName: urlCopiedFlash ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(urlCopiedFlash ? .green : .secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(urlCopiedFlash ? "Copied!" : "Copy URL")
                }
                

            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(nsColor: .controlBackgroundColor).opacity(0.6),
                                Color(nsColor: .controlBackgroundColor).opacity(0.4)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )

        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private func tabList(for space: BrowserSpace) -> some View {
        List(selection: $store.selectedTab) {
            spaceHeader(space: space)
            sharedSection(space: space)
            pinnedSection(space: space)
            todaySection(space: space)
            
            Spacer()
        }
        .listStyle(.sidebar)
        .onChange(of: store.selectedTab) { oldValue, newValue in
            if newValue == nil && oldValue != nil {
                store.selectedTab = oldValue
            }
        }
    }
    
    private func spaceHeader(space: BrowserSpace) -> some View {
        HStack(spacing: 8) {
            Text(space.emojiIcon ?? String(space.name.prefix(1)))
                .font(.system(size: 16))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill((Color(hex: space.colorHex) ?? .gray).opacity(0.2))
                )
            
            Text(space.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private func sharedSection(space: BrowserSpace) -> some View {
        DisclosureGroup(isExpanded: $store.sharedSectionExpanded) {
            if let profile = space.profile, profiles.contains(where: { $0.id == profile.id }) {
                if profile.sharedTabs.isEmpty {
                    Text("Drag to Share")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(profile.sharedTabs) { tab in
                        tabRow(tab: tab, space: space)
                    }
                    .onMove { indices, newOffset in
                        // Basic reordering within shared tabs
                        // Note: This modifies the profile's sharedTabs directly
                        var tabs = profile.sharedTabs
                        tabs.move(fromOffsets: indices, toOffset: newOffset)
                        profile.sharedTabs = tabs
                    }
                }
            }
        } label: {
            HStack {
                Text("Shared")
                    .font(.headline)
                Spacer()
            }
        }
        .dropDestination(for: String.self) { items, _ in
            return _ = store.moveTabs(ids: items, toPinned: false, toShared: true, spaces: spaces)
        }
    }
    
    private func pinnedSection(space: BrowserSpace) -> some View {
        DisclosureGroup(isExpanded: $store.pinnedSectionExpanded) {
            if space.pinnedTabs.isEmpty {
                Text("Drag to Pin")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(space.pinnedTabs) { tab in
                    tabRow(tab: tab, space: space)
                }
                .onMove { indices, newOffset in
                    moveTab(from: indices, to: newOffset, in: &space.pinnedTabs)
                }
            }
        } label: {
            HStack {
                Text("Pinned")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("New Folder") {
                        store.createFolder(in: space, isPinned: true)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                }
                .tint(.secondary)
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .dropDestination(for: String.self) { items, _ in
            return _ = store.moveTabs(ids: items, toPinned: true, spaces: spaces)
        }
    }
    
    private func todaySection(space: BrowserSpace) -> some View {
        DisclosureGroup(isExpanded: $store.todaySectionExpanded) {
            if space.todayTabs.isEmpty {
                Button(action: {
                    store.isNewTabMode = false
                    store.showCommandPalette = true
                }) {
                    HStack {
                        // Image(systemName: "magnifyingglass")
                        Text("New Tab")
                    }
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            } else {
                ForEach(space.todayTabs) { tab in
                    tabRow(tab: tab, space: space)
                }
                .onMove { indices, newOffset in
                    moveTab(from: indices, to: newOffset, in: &space.todayTabs)
                }
            }
        } label: {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Clear", role: .destructive) {
                        store.clearTodayTabs(spaces: spaces)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                }
                .tint(.secondary)
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .dropDestination(for: String.self) { items, _ in
            return _ = store.moveTabs(ids: items, toPinned: false, spaces: spaces)
        }
    }
    
    private func tabRow(tab: BrowserTab, space: BrowserSpace) -> some View {
        Group {
            if tab.isFolder {
                DisclosureGroup(isExpanded: .constant(true)) {
                    if let children = tab.children {
                        ForEach(children) { child in
                            TabRowView(tab: child, spaces: spaces, currentSpace: space) { targetSpace in
                                    _ = _ = store.moveTab(child, to: targetSpace, spaces: spaces)
                                } onDelete: {
                                    store.deleteTab(child, spaces: spaces)
                                } onUnpin: {
                                    store.unpinTab(child, spaces: spaces)
                                }
                                .tag(child)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if store.selectedTab == child && child.isPinned {
                                        store.resetTabToPinnedURL(child)
                                    } else {
                                        store.selectedTab = child
                                    }
                                }
                        }
                    }
                } label: {
                    TabRowView(tab: tab, spaces: spaces, currentSpace: space) { targetSpace in
                        _ = _ = store.moveTab(tab, to: targetSpace, spaces: spaces)
                    } onDelete: {
                        store.deleteTab(tab, spaces: spaces)
                    } onUnpin: {
                        store.unpinTab(tab, spaces: spaces)
                    }
                }
                .draggable(tab.id.uuidString)
            } else {
                TabRowView(tab: tab, spaces: spaces, currentSpace: space) { targetSpace in
                        _ = _ = store.moveTab(tab, to: targetSpace, spaces: spaces)
                    } onDelete: {
                        store.deleteTab(tab, spaces: spaces)
                    } onUnpin: {
                        store.unpinTab(tab, spaces: spaces)
                    }
                    .tag(tab)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if store.selectedTab == tab && tab.isPinned {
                            store.resetTabToPinnedURL(tab)
                        } else {
                            store.selectedTab = tab
                        }
                    }
                    .draggable(tab.id.uuidString)
            }
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                if store.sidebarIndex == 0 {
                    // Back to space
                    if let space = store.selectedSpace ?? spaces.first {
                        let index = pageIndex(for: space)
                        withAnimation {
                            store.select(space: space, spaces: spaces)
                            updateSidebarIndex(index)
                        }
                    }
                } else {
                    // Open library
                    withAnimation {
                        store.openLibrary()
                        updateSidebarIndex(0)
                    }
                }
            }) {
                Image(systemName: store.sidebarIndex == 0 ? "chevron.left" : "books.vertical")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Library")
            .background(GeometryReader { geometry in
                Color.clear.preference(key: LibraryButtonFrameKey.self, value: geometry.frame(in: .named("content")))
            })
            .onPreferenceChange(LibraryButtonFrameKey.self) { frame in
                libraryButtonFrame = frame
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(spaces) { space in
                    Button(action: {
                        let index = pageIndex(for: space)
                        withAnimation {
                            store.select(space: space, spaces: spaces)
                            updateSidebarIndex(index)
                        }
                    }) {
                        Text(space.emojiIcon ?? String(space.name.prefix(1)))
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .grayscale(store.selectedSpace == space ? 0 : 1)
                            .opacity(store.selectedSpace == space ? 1 : 0.6)
                            .glassEffect(.regular.tint(store.selectedSpace == space ? Color.accentColor.opacity(0.3) : Color.clear), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .help(space.name)
                    .contextMenu {
                        Button("Edit Space") {
                            store.editingSpace = space
                        }
                        
                        if spaces.count > 1 {
                            Divider()
                            Button("Delete Space", role: .destructive) {
                                store.deleteSpace(space, spaces: spaces)
                            }
                        }
                    }
                    .dropDestination(for: String.self) { items, location in
                        let index = pageIndex(for: space)
                        withAnimation {
                            store.select(space: space, spaces: spaces)
                            updateSidebarIndex(index)
                        }
                        return true
                    } isTargeted: { isTargeted in
                        if isTargeted {
                            // Switch space after a short delay to allow "hover to switch"
                            let index = pageIndex(for: space)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if isTargeted {
                                    withAnimation {
                                        store.select(space: space, spaces: spaces)
                                        updateSidebarIndex(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                _ = store.createSpace(spaces: spaces, profiles: profiles)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("New Space")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private var detailContent: some View {
        ZStack {
            if store.librarySection == .spaces {
                SpacesOverviewView(
                    onSelectSpace: { space in
                        withAnimation {
                            store.select(space: space, spaces: spaces)
                            updateSidebarIndex(pageIndex(for: space))
                            store.librarySection = nil
                        }
                    },
                    onMoveTab: { tab, targetSpace in
                        _ = _ = store.moveTab(tab, to: targetSpace, spaces: spaces)
                    },
                    onDeleteTab: { tab, space in
                        store.deleteTab(tab, spaces: spaces)
                    },
                    onUnpinTab: { tab, space in
                        store.unpinTab(tab, spaces: spaces)
                    },
                    onMoveSpace: { source, destination in
                        store.moveSpace(from: source, to: destination, spaces: spaces)
                    }
                )
            } else if let tab = store.selectedTab {
                WebView(tab: tab, contextID: store.windowID, ownershipToken: webEngine.ownershipChangeToken, profileID: store.selectedSpace?.profile?.id)
                    .id(tab.id)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "globe")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.05))
                        )
                    
                    VStack(spacing: 8) {
                        Text("No Tab Selected")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.8))
                        
                        Text("Select a tab from the sidebar or create a new one to get started.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }
                    
                    Text("⌘T to create a new tab")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(currentSpaceTint ?? Color(nsColor: .windowBackgroundColor))
            }
        }
        .extensionEffectBackground()
        .overlay(alignment: .bottomTrailing) {
            if let status = webEngine.lastDownloadStatus {
                Text(status)
                    .padding()
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                    .cornerRadius(8)
                    .padding()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if webEngine.lastDownloadStatus == status {
                                webEngine.lastDownloadStatus = nil
                            }
                        }
                    }
            }
        }
        .background(
        )
        .toolbar(id: "navigation") {
            ToolbarItem(id: "back", placement: .navigation) {
                Button(action: {
                    if let tab = store.selectedTab {
                        WebEngine.shared.goBack(for: tab, contextID: store.windowID)
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(store.selectedTab?.canGoBack != true)
            }
            
            ToolbarItem(id: "forward", placement: .navigation) {
                Button(action: {
                    if let tab = store.selectedTab {
                        WebEngine.shared.goForward(for: tab, contextID: store.windowID)
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(store.selectedTab?.canGoForward != true)
            }
            
            ToolbarItem(id: "reload", placement: .navigation) {
                if let tab = store.selectedTab {
                    Button(action: {
                        if tab.isLoading {
                            WebEngine.shared.stopLoading(for: tab, contextID: store.windowID)
                        } else {
                            WebEngine.shared.reload(for: tab, contextID: store.windowID)
                        }
                    }) {
                        Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                    }
                    .help(tab.isLoading ? "Stop Loading" : "Reload Page")
                }
            }
            
            ToolbarItem(id: "progress", placement: .navigation) {
                if store.selectedTab?.isLoading == true {
                    LoadingProgressBar()
                        .frame(width: 100, height: 4)
                        .opacity(0.8)
                }
            }

        }
        .toolbar(.visible, for: .windowToolbar)
        .toolbar(removing: .title)
    }
    
    private var keyboardShortcuts: some View {
        Group {
            Button("") {
                addTab()
            }
            .keyboardShortcut("t", modifiers: .command)
            .hidden()
            
            Button("") {
                editCurrentTab()
            }
            .keyboardShortcut("l", modifiers: .command)
            .hidden()
            
            Button("") {
                store.reopenLastClosedTab(spaces: spaces)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .hidden()
            
            Button("") {
                if let tab = store.selectedTab {
                    store.deleteTab(tab, spaces: spaces)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .hidden()
            
            // Reload
            Button("") {
                if let tab = store.selectedTab {
                    WebEngine.shared.reload(for: tab, contextID: store.windowID)
                }
            }
            .keyboardShortcut("r", modifiers: .command)
            .hidden()
            
            // Tab Switching - Next
            Button("") {
                store.cycleTab(forward: true, spaces: spaces)
            }
            .keyboardShortcut(.tab, modifiers: .control)
            .hidden()
            
            Button("") {
                store.cycleTab(forward: true, spaces: spaces)
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .hidden()
            
            // Tab Switching - Previous
            Button("") {
                store.cycleTab(forward: false, spaces: spaces)
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])
            .hidden()
            
            Button("") {
                store.cycleTab(forward: false, spaces: spaces)
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .hidden()
            
            // Navigation - Back
            Button("") {
                if let tab = store.selectedTab {
                    WebEngine.shared.goBack(for: tab, contextID: store.windowID)
                }
            }
            .keyboardShortcut("[", modifiers: .command)
            .hidden()
            
            // Navigation - Forward
            Button("") {
                if let tab = store.selectedTab {
                    WebEngine.shared.goForward(for: tab, contextID: store.windowID)
                }
            }
            .keyboardShortcut("]", modifiers: .command)
            .hidden()
        }
    }
    

    
    private func addTab() {
        store.isNewTabMode = true
        store.showCommandPalette = true
    }
    
    private func editCurrentTab() {
        store.isNewTabMode = false
        store.showCommandPalette = true
    }
    
    private func moveTab(from source: IndexSet, to destination: Int, in tabs: inout [BrowserTab]) {
        tabs.move(fromOffsets: source, toOffset: destination)
        try? modelContext.save()
    }
    
    private func createDefaultSpace() {
        // Ensure a default profile exists
        let profile = BrowserProfile(name: "Default")
        modelContext.insert(profile)
        
        // 1. Personal Space
        let personalSpace = BrowserSpace(name: "Personal", colorHex: "#4A90E2", profile: profile)
        personalSpace.emojiIcon = "🏠"
        personalSpace.orderIndex = 0
        modelContext.insert(personalSpace)
        
        // Add "yadarola.com.ar" as pinned
        if let url = URL(string: "https://yadarola.com.ar") {
            let tab = BrowserTab(url: url, title: "Yadarola", isPinned: true)
            tab.pinnedURL = url
            personalSpace.pinnedTabs.append(tab)
        }
        
        // Add "Drag me to pinned" in Today
        let dragMeTab = BrowserTab(url: URL(string: "about:blank")!, title: "Drag me to pinned", isPinned: false)
        personalSpace.todayTabs.append(dragMeTab)
        
        // 2. Work Space
        let workSpace = BrowserSpace(name: "Work", colorHex: "#FF5733", profile: profile)
        workSpace.emojiIcon = "💼"
        workSpace.orderIndex = 1
        modelContext.insert(workSpace)
        
        // Select Personal space by default
        store.selectedSpace = personalSpace
        store.sidebarIndex = 1
        store.selectedTab = personalSpace.pinnedTabs.first
        
        try? modelContext.save()
    }
    
    private func updateSidebarIndex(_ index: Int) {
        store.setSidebarIndex(index, spaces: spaces)
    }
    
    private func pageIndex(for space: BrowserSpace) -> Int {
        if let index = spaces.firstIndex(where: { $0.id == space.id }) {
            return index + 1
        }
        return 1
    }
    
    private var currentSidebarWidth: CGFloat {
        idealSidebarWidth
    }
    
    private var currentSpaceForChrome: BrowserSpace? {
        // Don't return a space when in library view (index 0) to keep background transparent
        guard store.sidebarIndex != 0 else {
            return nil
        }
        
        if let selected = store.selectedSpace {
            return selected
        }
        return spaces.first
    }
    
    private var currentSpaceTintNSColor: NSColor? {
        guard let space = currentSpaceForChrome,
              !space.colorHex.isEmpty,
              let color = Color(hex: space.colorHex) else {
            return nil
        }
        return NSColor(color)
    }
    
    private var currentSpaceTint: Color? {
        guard let nsColor = currentSpaceTintNSColor else {
            return nil
        }
        return Color(nsColor: nsColor).opacity(0.2)
    }
    
    private var sidebarBackground: some View {
        (currentSpaceTint ?? Color.clear)
            .ignoresSafeArea()
    }
}

struct SpaceEditView: View {
    @Bindable var space: BrowserSpace
    @Binding var isPresented: Bool
    @EnvironmentObject var store: BrowserStore
    @Query(sort: \BrowserSpace.orderIndex) private var spaces: [BrowserSpace]
    @State private var selectedColor: Color = .blue
    @State private var useTransparent: Bool = true
    @State private var showDeleteConfirmation = false
    
    let funEmojis = [
        "🚀", "🎨", "🎮", "🎵", "📚", "💻", "🌍", "🍕", "⚡️", "🌈",
        "🔮", "🕹️", "🏖️", "💡", "📸", "🐶", "🐱", "🦊", "🐻", "🐼",
        "🐨", "🐯", "🦁", "🐮", "🐷", "🦄", "🐝", "🦋", "🌸", "🌺",
        "🌻", "🌙", "⭐️", "☀️", "☁️", "🌊", "🔥", "💧", "🍎", "🍊",
        "🍋", "🍇", "🍓", "🥑", "🌮", "🍔", "🍣", "🍜", "☕️", "🍰",
        "🎯", "🎪", "🎭", "🎬", "🎤", "🎧", "🎸", "🎹", "🎺", "🎻"
    ]
    
    let extendedColorOptions: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow, .green, .gray,
        .mint, .teal, .cyan, .indigo, .brown
    ]
    
    // Fallback for older macOS if needed, but we are targeting 26.0 so these should be fine.
    // If we wanted custom hex colors we could define them here.
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Space")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(20) // Increased padding
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PROFILE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text("With profiles, you can keep all your browsing info separate, like bookmarks, history, and other settings.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        
                        ProfilePickerView(selectedProfile: $space.profile)
                            .environmentObject(store)
                    }
                    
                    // Name Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NAME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        TextField("Space Name", text: $space.name, prompt: Text("Work, Personal, Side Projects..."))
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Icon Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ICON")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(funEmojis, id: \.self) { emoji in
                                    Button(action: {
                                        space.emojiIcon = emoji
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 24))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(space.emojiIcon == emoji ? Color.accentColor.opacity(0.15) : Color.clear)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(space.emojiIcon == emoji ? Color.accentColor : Color.clear, lineWidth: 2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                    }
                    
                    // Color Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THEME")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Spacer()
                            CircularThemePicker(
                                selectedColorHex: space.colorHex,
                                onSelect: { color, isTransparent in
                                    if isTransparent {
                                        useTransparent = true
                                        space.colorHex = ""
                                        selectedColor = .blue // Default for state
                                    } else {
                                        useTransparent = false
                                        if let color = color {
                                            selectedColor = color
                                            space.colorHex = color.toHex() ?? ""
                                        }
                                    }
                                }
                            )
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    
                    if spaces.count > 1 {
                        Divider()
                            .padding(.top, 10)
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Space")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(.red)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            useTransparent = space.colorHex.isEmpty
            if !useTransparent, let color = Color(hex: space.colorHex) {
                selectedColor = color
            }
        }
        .confirmationDialog("Are you sure you want to delete this space?", isPresented: $showDeleteConfirmation) {
            Button("Delete Space", role: .destructive) {
                store.deleteSpace(space, spaces: spaces)
                isPresented = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All tabs in this space will be closed.")
        }
    }
    
    private func colorsMatch(_ color1: Color, _ color2: Color) -> Bool {
        return color1.toHex() == color2.toHex()
    }
}

struct CircularThemePicker: View {
    let selectedColorHex: String
    let onSelect: (Color?, Bool) -> Void
    
    // Generate colors programmatically for high density and smooth gradients
    // Inner: Very light pastels (low saturation, high brightness)
    private let innerColors: [Color] = (0..<10).map { i in
        Color(nsColor: NSColor(hue: CGFloat(i) / 10.0, saturation: 0.15, brightness: 1.0, alpha: 1.0))
    }
    
    // Middle: Medium colors
    private let middleColors: [Color] = (0..<16).map { i in
        Color(nsColor: NSColor(hue: CGFloat(i) / 16.0, saturation: 0.6, brightness: 0.90, alpha: 1.0))
    }
    
    // Outer: Dark vibrant colors (high saturation, lower brightness)
    private let outerColors: [Color] = (0..<24).map { i in
        Color(nsColor: NSColor(hue: CGFloat(i) / 24.0, saturation: 1.0, brightness: 0.75, alpha: 1.0))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient Ring Background
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red]),
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 270, height: 270)
                    .opacity(0.4)
                    .blur(radius: 4)
                
                // Outer Ring (High Density Overlap)
                ForEach(0..<outerColors.count, id: \.self) { index in
                    let angle = Angle.degrees(Double(index) / Double(outerColors.count) * 360 - 90)
                    let radius: CGFloat = 98
                    
                    ThemeColorButton(
                        color: outerColors[index],
                        isSelected: !selectedColorHex.isEmpty && colorsMatch(Color(hex: selectedColorHex) ?? .clear, outerColors[index]),
                        isTransparentOption: false,
                        size: 46
                    )
                    .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
                    .onTapGesture { onSelect(outerColors[index], false) }
                }
                
                // Middle Ring
                ForEach(0..<middleColors.count, id: \.self) { index in
                    let angle = Angle.degrees(Double(index) / Double(middleColors.count) * 360 - 90 + 11.25)
                    let radius: CGFloat = 68
                    
                    ThemeColorButton(
                        color: middleColors[index],
                        isSelected: !selectedColorHex.isEmpty && colorsMatch(Color(hex: selectedColorHex) ?? .clear, middleColors[index]),
                        isTransparentOption: false,
                        size: 46
                    )
                    .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
                    .onTapGesture { onSelect(middleColors[index], false) }
                }
                
                // Inner Ring
                ForEach(0..<innerColors.count, id: \.self) { index in
                    let angle = Angle.degrees(Double(index) / Double(innerColors.count) * 360 - 90)
                    let radius: CGFloat = 38
                    
                    ThemeColorButton(
                        color: innerColors[index],
                        isSelected: !selectedColorHex.isEmpty && colorsMatch(Color(hex: selectedColorHex) ?? .clear, innerColors[index]),
                        isTransparentOption: false,
                        size: 46
                    )
                    .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
                    .onTapGesture { onSelect(innerColors[index], false) }
                }
                
                // Center: Transparent/Default
                ThemeColorButton(
                    color: .white,
                    isSelected: selectedColorHex.isEmpty,
                    isTransparentOption: true,
                    size: 52
                )
                .zIndex(100)
                .onTapGesture { onSelect(nil, true) }
            }
            .frame(width: 290, height: 290)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectColor(at: value.location, center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
                    }
            )
        }
        .frame(width: 290, height: 290)
    }
    
    private func selectColor(at point: CGPoint, center: CGPoint) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx*dx + dy*dy)
        
        // Check center
        if distance < 25 {
            onSelect(nil, true)
            return
        }
        
        // Calculate angle in degrees (0-360, starting from top/12 o'clock to match our layout)
        // atan2 returns -pi to pi. -pi/2 is top.
        var angle = atan2(dy, dx) * 180 / .pi
        angle = angle + 90 // Rotate so 0 is top
        if angle < 0 { angle += 360 }
        
        // Determine ring based on distance
        // Inner: ~38, Middle: ~68, Outer: ~98
        // Boundaries: 25-53 (Inner), 53-83 (Middle), 83+ (Outer)
        
        if distance < 53 {
            // Inner Ring
            let index = Int(round(angle / 360 * Double(innerColors.count))) % innerColors.count
            onSelect(innerColors[index], false)
        } else if distance < 83 {
            // Middle Ring
            // Adjust for offset of 11.25 degrees
            let adjustedAngle = angle - 11.25
            let normalizedAngle = adjustedAngle < 0 ? adjustedAngle + 360 : adjustedAngle
            let index = Int(round(normalizedAngle / 360 * Double(middleColors.count))) % middleColors.count
            onSelect(middleColors[index], false)
        } else {
            // Outer Ring
            let index = Int(round(angle / 360 * Double(outerColors.count))) % outerColors.count
            onSelect(outerColors[index], false)
        }
    }
    

    
    private func colorsMatch(_ color1: Color, _ color2: Color) -> Bool {
        return color1.toHex() == color2.toHex()
    }
}

struct ThemeColorButton: View {
    let color: Color
    let isSelected: Bool
    let isTransparentOption: Bool
    var size: CGFloat = 44
    
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size - 8, height: size - 8)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .overlay(
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: isTransparentOption ? 1 : 0)
                )
            
            if isTransparentOption {
                Image(systemName: "slash.circle")
                    .font(.system(size: size / 2))
                    .foregroundColor(.secondary)
            }
            
            if isSelected {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .frame(width: size, height: size)
            } else if isHovering {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
        .scaleEffect(isHovering ? 1.3 : 1.0) // Increased scale
        .zIndex(isHovering ? 100 : (isSelected ? 50 : 0)) // Pop to top
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .frame(width: size, height: size)
    }
}

struct TabRowView: View {
    @Bindable var tab: BrowserTab
    var spaces: [BrowserSpace]
    var currentSpace: BrowserSpace
    var onMoveToSpace: (BrowserSpace) -> Void
    let onDelete: () -> Void
    let onUnpin: () -> Void
    
    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showRenameAlert = false
    @State private var showEmojiAlert = false
    @State private var newTitle = ""
    @State private var newEmoji = ""
    
    var body: some View {
        HStack(spacing: 8) {
            if tab.isFolder {
                Image(systemName: "folder.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                    .allowsHitTesting(false)
            } else {
                if let emoji = tab.emojiIcon, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 14))
                        .frame(width: 16, height: 16)
                        .allowsHitTesting(false)
                } else {
                    AsyncImage(url: getFaviconURL(for: tab.url)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    .allowsHitTesting(false)
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
                    .font(.system(size: 13))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .allowsHitTesting(false)
            }
            
            Spacer()
            
            if tab.isPlayingAudio {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            
            HStack(spacing: 4) {
                if tab.isPinned {
                    // For pinned tabs: show close if has session, unpin if no session
                    if tab.hasActiveSession {
                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Close Session")
                    } else {
                        Button(action: onUnpin) {
                            Image(systemName: "pin.slash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Move to Today")
                    }
                } else {
                    // For non-pinned tabs: always show close
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
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

extension View {
    func extensionEffectBackground() -> some View {
        if #available(macOS 26.0, *) {
            return AnyView(self.backgroundExtensionEffect())
        } else {
            return AnyView(self.ignoresSafeArea())
        }
    }
    
    func glassEffect() -> some View {
        self.background(.ultraThinMaterial)
    }
    
    func glassEffectID(_ id: AnyHashable, in namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }
}

struct ArcGlassButtonStyle: ButtonStyle {
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

extension ButtonStyle where Self == ArcGlassButtonStyle {
    static var glass: ArcGlassButtonStyle { ArcGlassButtonStyle() }
}
