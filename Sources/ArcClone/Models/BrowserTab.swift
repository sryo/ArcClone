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
    var children: [BrowserTab]? // For folders
    var isFolder: Bool = false
    var emojiIcon: String? // Custom emoji icon
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    
    init(url: URL, title: String, isPinned: Bool = false, isFolder: Bool = false, children: [BrowserTab]? = nil, emojiIcon: String? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.lastActive = Date()
        self.isPinned = isPinned
        self.isFolder = isFolder
        self.children = children
        self.emojiIcon = emojiIcon
    }
}
