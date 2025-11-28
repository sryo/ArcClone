import Foundation
import SwiftData

@Model
final class BrowserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdDate: Date
    var isIncognito: Bool
    @Relationship(deleteRule: .cascade) var sharedTabs: [BrowserTab] = []
    
    init(name: String, isIncognito: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.isIncognito = isIncognito
        self.sharedTabs = []
    }
}
