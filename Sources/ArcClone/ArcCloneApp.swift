import SwiftUI
import SwiftData

@available(macOS 26.0, *)
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
                .onAppear {
                    WebEngine.shared.startAudioPolling()
                }
        }
        .modelContainer(AppModelContainer.shared.container)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ArcClone") {
                    let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                        styleMask: [.titled, .closable, .miniaturizable],
                        backing: .buffered, defer: false)
                    window.center()
                    window.title = "About"
                    window.contentView = NSHostingView(rootView: AboutView())
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        
        Settings {
            PreferencesView()
        }
    }
}
