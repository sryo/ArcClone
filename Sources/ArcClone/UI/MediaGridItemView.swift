import SwiftUI
import AppKit

/// A view that represents a single media item in a grid.
struct MediaGridItemView: View {
    let mediaItem: DownloadManager.MediaItem
    
    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail = mediaItem.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipped()
                    .cornerRadius(8)
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            
            Text(mediaItem.filename)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
            
            Text(formatFileSize(mediaItem.fileSize))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
