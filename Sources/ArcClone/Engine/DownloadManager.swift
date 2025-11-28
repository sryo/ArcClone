import Foundation
import WebKit
import Combine
import AppKit

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()
    
    struct DownloadItem: Identifiable {
        let id = UUID()
        let task: WKDownload
        var filename: String
        var progress: Double
        var state: State
        var destinationURL: URL?
        var dateAdded: Date
        
        enum State: Equatable {
            case downloading
            case finished
            case failed(Error)
            case canceled
            
            static func == (lhs: State, rhs: State) -> Bool {
                switch (lhs, rhs) {
                case (.downloading, .downloading): return true
                case (.finished, .finished): return true
                case (.canceled, .canceled): return true
                case (.failed(let e1), .failed(let e2)):
                    return e1.localizedDescription == e2.localizedDescription
                default: return false
                }
            }
        }
    }
    
    struct MediaItem: Identifiable, Equatable {
        let id = UUID()
        let filename: String
        let url: URL
        let thumbnail: NSImage?
        let dateAdded: Date
        let fileSize: Int64
        
        static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    @Published var downloads: [DownloadItem] = []
    @Published var mediaItems: [MediaItem] = []
    
    enum DownloadTimeGroup: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case older = "Older"
        
        func contains(date: Date) -> Bool {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                return calendar.isDateInToday(date)
            case .yesterday:
                return calendar.isDateInYesterday(date)
            case .last7Days:
                guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
                return date >= sevenDaysAgo && !calendar.isDateInToday(date) && !calendar.isDateInYesterday(date)
            case .last30Days:
                guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return false }
                guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
                return date >= thirtyDaysAgo && date < sevenDaysAgo
            case .older:
                guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return false }
                return date < thirtyDaysAgo
            }
        }
    }
    
    var groupedDownloads: [(group: DownloadTimeGroup, items: [DownloadItem])] {
        var result: [(group: DownloadTimeGroup, items: [DownloadItem])] = []
        
        for group in DownloadTimeGroup.allCases {
            let items = downloads.filter { group.contains(date: $0.dateAdded) }
            if !items.isEmpty {
                result.append((group: group, items: items))
            }
        }
        
        return result
    }
    
    // We need to keep track of delegates to avoid them being deallocated if they were separate objects,
    // but here the Manager itself will likely be the delegate or coordinate it.
    // Actually, WKDownloadDelegate methods are called on the navigation delegate usually, or we set it explicitly.
    
    override private init() {
        super.init()
    }
    
    @MainActor
    func startDownload(_ download: WKDownload, suggestedFilename: String) {
        let item = DownloadItem(
            task: download,
            filename: suggestedFilename,
            progress: 0.0,
            state: .downloading,
            destinationURL: nil,
            dateAdded: Date()
        )
        downloads.append(item)
        download.delegate = self
    }
    
    @MainActor
    func updateProgress(_ download: WKDownload, progress: Double) {
        if let index = downloads.firstIndex(where: { $0.task == download }) {
            downloads[index].progress = progress
        }
    }
    
    @MainActor
    func finishDownload(_ download: WKDownload, url: URL) {
        if let index = downloads.firstIndex(where: { $0.task == download }) {
            downloads[index].state = .finished
            downloads[index].destinationURL = url
            downloads[index].progress = 1.0
            
            // Add to media items if it's an image
            if isImageFile(url) {
                let thumbnail = generateThumbnail(for: url)
                let size = fileSize(at: url)
                let mediaItem = MediaItem(
                    filename: url.lastPathComponent,
                    url: url,
                    thumbnail: thumbnail,
                    dateAdded: Date(),
                    fileSize: size
                )
                mediaItems.insert(mediaItem, at: 0) // Add to beginning for most recent first
            }
        }
    }
    
    @MainActor
    func failDownload(_ download: WKDownload, error: Error) {
        if let index = downloads.firstIndex(where: { $0.task == download }) {
            downloads[index].state = .failed(error)
        }
    }
    
    // MARK: - Media Helpers
    
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "heic", "heif", "svg"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func generateThumbnail(for url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let targetSize = CGSize(width: 200, height: 200)
        let aspectRatio = image.size.width / image.size.height
        
        var thumbnailSize = targetSize
        if aspectRatio > 1 {
            // Landscape
            thumbnailSize.height = targetSize.width / aspectRatio
        } else {
            // Portrait
            thumbnailSize.width = targetSize.height * aspectRatio
        }
        
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    private func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }
}

extension DownloadManager: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let fileManager = FileManager.default
        guard let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            completionHandler(nil)
            return
        }
        
        let destinationURL = downloadsURL.appendingPathComponent(suggestedFilename)
        completionHandler(destinationURL)
        
        Task { @MainActor in
            // Update filename if it changed
            if let index = downloads.firstIndex(where: { $0.task == download }) {
                downloads[index].filename = suggestedFilename
            }
        }
    }
    
    func download(_ download: WKDownload, didFinishTo url: URL) {
        Task { @MainActor in
            finishDownload(download, url: url)
        }
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        Task { @MainActor in
            failDownload(download, error: error)
        }
    }
}
