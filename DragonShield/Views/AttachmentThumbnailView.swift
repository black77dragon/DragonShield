import SwiftUI
import AppKit

struct AttachmentThumbnailView: View {
    let attachment: Attachment
    let service: ThumbnailService
    @State private var image: NSImage?
    @State private var started = false

    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        Text((attachment.ext ?? "?").uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            Task {
                image = await service.ensureThumbnail(attachment)
            }
        }
    }
}
