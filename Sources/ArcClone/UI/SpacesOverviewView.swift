import SwiftUI
import SwiftData

struct SpacesOverviewView: View {
    @Query(sort: \BrowserSpace.orderIndex) private var spaces: [BrowserSpace]
    @Environment(\.modelContext) private var modelContext
    var onSelectSpace: (BrowserSpace) -> Void
    var onMoveTab: (BrowserTab, BrowserSpace) -> Void
    var onDeleteTab: (BrowserTab, BrowserSpace) -> Void
    var onUnpinTab: (BrowserTab, BrowserSpace) -> Void
    var onMoveSpace: (IndexSet, Int) -> Void
    
    @State private var draggingSpace: BrowserSpace?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(spaces) { space in
                    SpaceCardView(
                        space: space,
                        draggingSpace: $draggingSpace,
                        onSelect: { onSelectSpace(space) },
                        onMoveTab: { tab in onMoveTab(tab, space) },
                        onDeleteTab: { tab in onDeleteTab(tab, space) },
                        onUnpinTab: { tab in onUnpinTab(tab, space) }
                    )
                    .frame(width: 300)
                    .contentShape(Rectangle())
                    .frame(width: 300)
                    .contentShape(Rectangle())
                    .dropDestination(for: String.self) { items, location in
                        guard let sourceIDString = items.first,
                              let sourceID = UUID(uuidString: sourceIDString),
                              let sourceSpace = spaces.first(where: { $0.id == sourceID }) else { return false }
                        
                        // Reordering spaces
                        guard let sourceIndex = spaces.firstIndex(of: sourceSpace),
                              let destinationIndex = spaces.firstIndex(of: space) else {
                            // If not reordering spaces, check if it's a tab drop
                            return handleTabDrop(items: items, targetSpace: space)
                        }
                        
                        if sourceIndex != destinationIndex {
                            withAnimation {
                                onMoveSpace(IndexSet(integer: sourceIndex), destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex)
                            }
                        }
                        return true
                    }
                }
                
                Button(action: createSpace) {
                    VStack {
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("New Space")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 300, height: 500) // Approximate height, adjust as needed
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.secondary.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func createSpace() {
        let newSpace = BrowserSpace(name: "New Space", colorHex: "#808080", orderIndex: spaces.count)
        modelContext.insert(newSpace)
    }
    
    private func handleTabDrop(items: [String], targetSpace: BrowserSpace) -> Bool {
        guard let tabIDString = items.first, let tabID = UUID(uuidString: tabIDString) else { return false }
        
        // Find the tab in any space
        for space in spaces {
            if let tab = space.pinnedTabs.first(where: { $0.id == tabID }) {
                onMoveTab(tab, targetSpace)
                return true
            }
            if let tab = space.todayTabs.first(where: { $0.id == tabID }) {
                onMoveTab(tab, targetSpace)
                return true
            }
        }
        return false
    }
}

struct SpaceCardView: View {
    @Bindable var space: BrowserSpace
    @Binding var draggingSpace: BrowserSpace?
    var onSelect: () -> Void
    var onMoveTab: (BrowserTab) -> Void
    var onDeleteTab: (BrowserTab) -> Void
    var onUnpinTab: (BrowserTab) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                    .padding(.trailing, 4)
                
                Text(space.emojiIcon ?? "🪐")
                    .font(.title2)
                Text(space.name)
                    .font(.headline)
                Spacer()
                Button(action: onSelect) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding()
            // Background removed to fix split color
            .contentShape(Rectangle())
            .draggable(space.id.uuidString) {
                Text(space.name)
                    .frame(width: 200, height: 50)
                    .background(Color(hex: space.colorHex) ?? .gray)
                    .cornerRadius(8)
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Pinned Tabs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pinned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        if space.pinnedTabs.isEmpty {
                            Text("Drop tabs here to pin")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .frame(height: 40)
                        } else {
                            ForEach(space.pinnedTabs) { tab in
                                SpaceCardTabRow(tab: tab, onDelete: { onDeleteTab(tab) }, onUnpin: { onUnpinTab(tab) })
                            }
                        }
                    }
                        // Logic to handle dropping tabs into pinned section of this space
                        // We need to find the tab by ID. Since we are inside SpaceCardView, we don't have access to all spaces.
                        // We should probably delegate this to the parent or pass a lookup closure.
                        // But wait, the parent `SpacesOverviewView` has the logic in `handleTabDrop`.
                        // If we return false here, it might bubble up?
                        // Actually, dropDestination consumes the drop.
                        // Let's remove this dropDestination and let the parent handle it, OR
                        // we need to pass the drop handler down.
                        // For simplicity, let's let the parent handle the drop on the whole card.
                        EmptyView()
                    
                    // Today Tabs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        if space.todayTabs.isEmpty {
                            Text("No tabs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(space.todayTabs) { tab in
                                SpaceCardTabRow(tab: tab, onDelete: { onDeleteTab(tab) }, onUnpin: { onUnpinTab(tab) })
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .background(
            ZStack {
                // Prevent window dragging from interfering with card dragging
                NonDraggableWindowView()
                Color(nsColor: .controlBackgroundColor)
                Color(hex: space.colorHex)?.opacity(0.1) ?? Color.gray.opacity(0.1)
            }
        )
        .contentShape(Rectangle())
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            // Consumes tap to prevent window dragging
        }
        // We handle drop in the parent view for better coordination with space reordering
        // but we can also accept drops here for tabs specifically if needed
    }
}

struct SpaceCardTabRow: View {
    let tab: BrowserTab
    let onDelete: () -> Void
    let onUnpin: () -> Void
    
    var body: some View {
        HStack {
            if let faviconData = tab.favicon, let icon = NSImage(data: faviconData) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Text(tab.title)
                .font(.system(size: 13))
                .lineLimit(1)
            
            Spacer()
            
            if tab.isPlayingAudio {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .draggable(tab.id.uuidString)
    }
}
