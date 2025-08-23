import SwiftUI
import AppKit

struct AttachmentRowView: View {
    let attachment: Attachment
    let thumbnailService: ThumbnailService
    let attachmentService: AttachmentService
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            AttachmentThumbnailView(attachment: attachment, service: thumbnailService)
                .frame(width: 48, height: 48)
                .cornerRadius(4)
            VStack(alignment: .leading) {
                Text(attachment.originalFilename)
                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Quick Look") { attachmentService.quickLook(attachmentId: attachment.id) }
                .accessibilityLabel("Quick Look \(attachment.originalFilename)")
            Button("Reveal in Finder") { attachmentService.revealInFinder(attachmentId: attachment.id) }
                .accessibilityLabel("Reveal \(attachment.originalFilename) in Finder")
            Button("Remove") { onRemove() }
                .accessibilityLabel("Remove attachment \(attachment.originalFilename)")
        }
    }
}
