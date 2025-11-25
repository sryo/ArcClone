import Foundation
import SwiftData

@MainActor
class AppModelContainer {
    static let shared = AppModelContainer()
    
    let container: ModelContainer
    
    private init() {
        do {
            let schema = Schema([
                BrowserTab.self,
                BrowserSpace.self,
                HistoryEntry.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Could not create ModelContainer: \(error)")
            // Attempt to delete the store and recreate it
            // This is a destructive action but necessary for development if migration fails
            let schema = Schema([
                BrowserTab.self,
                BrowserSpace.self,
                HistoryEntry.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            
            do {
                // We can't easily delete the store via SwiftData API directly without the URL.
                // But we can try to initialize with a new configuration or just fail gracefully?
                // Actually, let's try to remove the default store file if we can find it.
                // Or easier: just use in-memory if persistent fails, or try to nuke.
                
                // Let's try to find the default URL
                if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("default.store") {
                    try? FileManager.default.removeItem(at: url)
                    try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
                    try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
                }
                
                self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }
}
