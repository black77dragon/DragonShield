import SwiftUI
import AppKit

/// Read-only slide-out style reader for portfolio theme updates.
struct ThemeUpdateReaderView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let update: PortfolioThemeUpdate
    var onEdit: (PortfolioThemeUpdate) -> Void = { _ in }
    var onClose: () -> Void = {}

    @State private var links: [Link] = []
    @State private var attachments: [Attachment] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Update — \(update.title) (\(DateFormatting.userFriendly(update.createdAt)))")
                    .font(.headline)
                Spacer()
            }
            Text("Author: \(update.author)  •  Type: \(update.type.rawValue)" + (update.pinned ? "  •  ★Pinned" : ""))
                .font(.subheadline)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if FeatureFlags.portfolioLinksEnabled() && !links.isEmpty {
                        Divider()
                        Text("Links (\(links.count))")
                            .font(.headline)
                        ForEach(links, id: \.id) { link in
                            HStack {
                                Text(link.title ?? link.rawURL)
                                    .lineLimit(1)
                                Spacer()
                                Button("Open") {
                                    if let url = URL(string: link.rawURL) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                Button("Copy") {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(link.rawURL, forType: .string)
                                }
                            }
                        }
                    }
                    if FeatureFlags.portfolioAttachmentsEnabled() && !attachments.isEmpty {
                        Divider()
                        Text("Files (\(attachments.count))")
                            .font(.headline)
                        ForEach(attachments, id: \.id) { att in
                            HStack {
                                Text(att.originalFilename)
                                    .lineLimit(1)
                                Spacer()
                                Button("Quick Look") {
                                    AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id)
                                }
                                Button("Reveal") {
                                    AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id)
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("Close") { onClose() }
            }
        }
        .padding(16)
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            links = ThemeUpdateLinkRepository(dbManager: dbManager).listLinks(updateId: update.id)
            attachments = ThemeUpdateRepository(dbManager: dbManager).listAttachments(updateId: update.id)
        }
    }
}
