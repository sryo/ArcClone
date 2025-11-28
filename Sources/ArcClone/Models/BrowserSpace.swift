import Foundation
import SwiftData

@Model
final class BrowserSpace {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    
    var emojiIcon: String?
    var orderIndex: Int = 0
    var lastSelectedTabID: UUID?
    @Relationship(deleteRule: .cascade) var pinnedTabs: [BrowserTab] = []
    @Relationship(deleteRule: .cascade) var todayTabs: [BrowserTab]
    @Relationship(deleteRule: .cascade) var archivedTabs: [BrowserTab]
    @Relationship var profile: BrowserProfile?
    
    init(name: String, colorHex: String = "#000000", emojiIcon: String? = nil, orderIndex: Int = 0, profile: BrowserProfile? = nil, lastSelectedTabID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.emojiIcon = emojiIcon
        self.orderIndex = orderIndex
        self.lastSelectedTabID = lastSelectedTabID
        self.pinnedTabs = []
        self.todayTabs = []
        self.archivedTabs = []
        self.profile = profile
    }
}
