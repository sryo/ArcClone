import SwiftUI

/// A view that shows a grid of downloaded media items.
struct MediaGridView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    
    var body: some View {
        if downloadManager.mediaItems.isEmpty {
            ContentUnavailableView(
                "No Media",
                systemImage: "photo.on.rectangle",
                description: Text("Downloaded images will appear here.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(downloadManager.mediaItems) { mediaItem in
                        Button(action: {
                            // Reveal in Finder
                            NSWorkspace.shared.activateFileViewerSelecting([mediaItem.url])
                        }) {
                            MediaGridItemView(mediaItem: mediaItem)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
    
    private var columns: [GridItem] {
        [ GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16) ]
    }
}
