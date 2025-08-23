import SwiftUI
import AppKit

struct AttachmentThumbnailView: View {
    let attachment: Attachment
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .frame(width: 40, height: 40)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
        .task {
            await load()
        }
    }

    private func load() async {
        guard image == nil else { return }
        let thumbnailable = Set(["png", "jpg", "jpeg", "heic", "gif", "tiff"]) 
        guard let ext = attachment.ext?.lowercased(), thumbnailable.contains(ext) else { return }
        let service = ThumbnailService()
        if let img = await service.loadImage(for: attachment) {
            await MainActor.run { image = img }
        }
    }
}
