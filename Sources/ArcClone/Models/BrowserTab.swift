import Foundation
import SwiftData

@Model
final class BrowserTab {
    @Attribute(.unique) var id: UUID
    var url: URL
    var title: String
    var favicon: Data?
    var lastActive: Date
    var isPinned: Bool
    var isShared: Bool = false
    var children: [BrowserTab]? // For folders
    var isFolder: Bool = false
    var emojiIcon: String? // Custom emoji icon
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isPlayingAudio: Bool = false
    var isLoading: Bool = false
    
    var pinnedURL: URL? // The original URL when pinned
    
    init(url: URL, title: String, isPinned: Bool = false, isShared: Bool = false, isFolder: Bool = false, children: [BrowserTab]? = nil, emojiIcon: String? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.lastActive = Date()
        self.isPinned = isPinned
        self.isShared = isShared
        if isPinned {
            self.pinnedURL = url
        }
        self.isFolder = isFolder
        self.children = children
        self.emojiIcon = emojiIcon
    }
    
    // Computed property to check if pinned tab has an active session
    var hasActiveSession: Bool {
        return canGoBack || canGoForward
    }
}
