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
            print("Could not create persistent ModelContainer: \(error)")
            let schema = Schema([
                BrowserTab.self,
                BrowserSpace.self,
                HistoryEntry.self
            ])
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                self.container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                print("Running with in-memory store due to initialization failure.")
            } catch {
                fatalError("Could not create ModelContainer even in memory: \(error)")
            }
        }
    }
}
