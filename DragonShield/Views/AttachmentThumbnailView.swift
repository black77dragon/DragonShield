import SwiftUI
import AppKit

struct AttachmentThumbnailView: View {
    let attachment: Attachment
    @State private var image: NSImage? = nil

    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(Color.secondary.opacity(0.2))
                    Text(attachment.ext?.uppercased() ?? "?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 40, height: 40)
        .cornerRadius(4)
        .onAppear { load() }
    }

    private func load() {
        Task { @MainActor in
            self.image = await ThumbnailService.shared.ensureThumbnail(attachment: attachment)
        }
    }
}
