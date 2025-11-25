import SwiftUI
import SwiftData

@main
struct ArcCloneApp: App {
    init() {
        // Ensure Dock icon and menu bar appear when running via command line
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(AppModelContainer.shared.container)
    }
}
