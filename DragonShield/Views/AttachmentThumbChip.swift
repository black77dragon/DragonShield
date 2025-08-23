import SwiftUI

struct AttachmentThumbChip: View {
    let attachment: Attachment
    var onTap: () -> Void
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(attachment.ext?.uppercased() ?? "FILE")
                    .font(.caption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .frame(width: 40, height: 40)
        .clipped()
        .onTapGesture { onTap() }
        .onAppear {
            ThumbnailService().ensureThumbnail(attachment: attachment) { img in
                self.image = img
            }
        }
    }
}

