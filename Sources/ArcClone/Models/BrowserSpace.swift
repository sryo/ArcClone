import Foundation
import SwiftData

@Model
final class BrowserSpace {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    
    var emojiIcon: String?
    @Relationship(deleteRule: .cascade) var pinnedTabs: [BrowserTab] = []
    @Relationship(deleteRule: .cascade) var todayTabs: [BrowserTab]
    @Relationship(deleteRule: .cascade) var archivedTabs: [BrowserTab]
    
    init(name: String, colorHex: String = "#000000", emojiIcon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.pinnedTabs = []
        self.todayTabs = []
        self.archivedTabs = []
    }
}
