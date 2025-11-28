import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("ArcClone")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("A browser reimagined with spaces, profiles, and more.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Built with SwiftUI and WebKit.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.top)
        }
        .padding(40)
        .frame(width: 300)
    }
}
