import SwiftUI
import AppKit

struct ThemeUpdateReaderView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let update: PortfolioThemeUpdate
    let isReadOnly: Bool
    var onEdit: (PortfolioThemeUpdate) -> Void
    var onPinToggle: (PortfolioThemeUpdate) -> Void
    var onDelete: (PortfolioThemeUpdate) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var links: [Link] = []
    @State private var attachments: [Attachment] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Update — \(update.title) (\(DateFormatting.userFriendly(update.createdAt)))")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            Text("Author: \(update.author)  •  Type: \(update.type.rawValue)\(update.pinned ? "  •  ★Pinned" : "")")
                .font(.subheadline)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                    if FeatureFlags.portfolioLinksEnabled(), !links.isEmpty {
                        Divider()
                        Text("Links (\(links.count))").font(.subheadline)
                        ForEach(links, id: \.id) { link in
                            HStack {
                                Text(displayTitle(link))
                                Spacer()
                                Button("Open") { openLink(link) }
                                Button("Copy") { copyLink(link) }
                            }
                        }
                    }
                    if FeatureFlags.portfolioAttachmentsEnabled(), !attachments.isEmpty {
                        Divider()
                        Text("Files (\(attachments.count))").font(.subheadline)
                        ForEach(attachments, id: \.id) { att in
                            HStack {
                                Text(att.originalFilename)
                                Spacer()
                                Button("Quick Look") { AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id) }
                                Button("Reveal") { AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id) }
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button("Edit") { onEdit(update) }.disabled(isReadOnly)
                Button(update.pinned ? "Unpin" : "Pin") { onPinToggle(update) }.disabled(isReadOnly)
                Button("Delete", role: .destructive) { onDelete(update) }.disabled(isReadOnly)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { load() }
    }

    private func load() {
        if FeatureFlags.portfolioLinksEnabled() {
            let repo = ThemeUpdateLinkRepository(dbManager: dbManager)
            links = repo.listLinks(updateId: update.id)
        }
        if FeatureFlags.portfolioAttachmentsEnabled() {
            let repo = ThemeUpdateRepository(dbManager: dbManager)
            attachments = repo.listAttachments(updateId: update.id)
        }
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyLink(_ link: Link) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(link.rawURL, forType: .string)
    }

    private func displayTitle(_ link: Link) -> String {
        if let t = link.title, !t.isEmpty { return t }
        if let url = URL(string: link.rawURL) {
            return url.host ?? link.rawURL
        }
        return link.rawURL
    }
}
