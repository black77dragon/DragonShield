import SwiftUI
import AppKit

struct ThemeUpdateReaderView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let update: PortfolioThemeUpdate
    let themeId: Int
    let isArchived: Bool
    var onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var attachments: [Attachment] = []
    @State private var links: [Link] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Update — \(update.title) (\(DateFormatting.userFriendly(update.createdAt)))")
                .font(.headline)
            Text("Author: \(update.author)  •  Type: \(update.type.rawValue)\(update.pinned ? "  •  ★Pinned" : "")")
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Text").font(.subheadline)
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                    if linksEnabled && !links.isEmpty {
                        Divider()
                        Text("Links (\(links.count))").font(.subheadline)
                        ForEach(links, id: \.id) { link in
                            HStack {
                                Text(linkTitle(link))
                                    .lineLimit(1)
                                Spacer()
                                Button("Open") { openLink(link) }
                                Button("Copy") { copyLink(link) }
                            }
                        }
                    }
                    if attachmentsEnabled && !attachments.isEmpty {
                        Divider()
                        Text("Files (\(attachments.count))").font(.subheadline)
                        ForEach(attachments, id: \.id) { att in
                            HStack {
                                Text("\(att.originalFilename)  \(ByteCountFormatter.string(fromByteCount: Int64(att.byteSize), countStyle: .file))")
                                    .lineLimit(1)
                                Spacer()
                                Button("Quick Look") { AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id) }
                                Button("Reveal in Finder") { AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Edit") { onEdit(); dismiss() }.disabled(isArchived)
                Button(update.pinned ? "Unpin" : "Pin") { togglePin() }.disabled(isArchived)
                Button("Delete", role: .destructive) { deleteUpdate() }.disabled(isArchived)
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { loadData() }
    }

    private var attachmentsEnabled: Bool { FeatureFlags.portfolioAttachmentsEnabled() }
    private var linksEnabled: Bool { FeatureFlags.portfolioLinksEnabled() }

    private func loadData() {
        if attachmentsEnabled {
            attachments = ThemeUpdateRepository(dbManager: dbManager).listAttachments(updateId: update.id)
        }
        if linksEnabled {
            links = ThemeUpdateLinkRepository(dbManager: dbManager).listLinks(updateId: update.id)
        }
    }

    private func linkTitle(_ link: Link) -> String {
        if let title = link.title, !title.isEmpty { return title }
        return URL(string: link.normalizedURL)?.host ?? link.normalizedURL
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyLink(_ link: Link) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.rawURL, forType: .string)
    }

    private func togglePin() {
        _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
        dismiss()
    }

    private func deleteUpdate() {
        _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
        dismiss()
    }
}

