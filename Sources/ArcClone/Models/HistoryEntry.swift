import SwiftData
import Foundation

@Model
final class HistoryEntry {
    var url: URL
    var urlString: String = ""
    var title: String?
    var visitDate: Date
    
    init(url: URL, title: String? = nil, visitDate: Date = Date()) {
        self.url = url
        self.urlString = url.absoluteString
        self.title = title
        self.visitDate = visitDate
    }
}
