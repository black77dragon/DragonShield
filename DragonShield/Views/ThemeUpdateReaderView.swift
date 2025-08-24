import SwiftUI
import AppKit

struct ThemeUpdateReaderView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let update: PortfolioThemeUpdate
    let links: [Link]
    let attachments: [Attachment]
    var onEdit: (PortfolioThemeUpdate) -> Void
    var onPin: (PortfolioThemeUpdate) -> Void
    var onDelete: (PortfolioThemeUpdate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Update — \(update.title.isEmpty ? "(No title)" : update.title) (\(DateFormatting.userFriendly(update.createdAt)))")
                .font(.headline)
            Text("Author: \(update.author)  •  Type: \(update.type.rawValue)\(update.pinned ? "  •  ★Pinned" : "")")
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if linksEnabled && !links.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Links (\(links.count))").font(.subheadline)
                            ForEach(links, id: \.id) { link in
                                HStack {
                                    Text(displayTitle(link))
                                    Spacer()
                                    Button("Open") { openLink(link) }.buttonStyle(.link)
                                    Button("Copy") { copyLink(link) }.buttonStyle(.link)
                                }
                            }
                        }
                    }
                    if attachmentsEnabled && !attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Files (\(attachments.count))").font(.subheadline)
                            ForEach(attachments, id: \.id) { att in
                                HStack {
                                    Text(att.originalFilename)
                                    Spacer()
                                    Button("Quick Look") { quickLook(att) }.buttonStyle(.link)
                                    Button("Reveal") { reveal(att) }.buttonStyle(.link)
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("Edit") { onEdit(update) }
                Button(update.pinned ? "Unpin" : "Pin") { onPin(update) }
                Button("Delete", role: .destructive) { onDelete(update) }
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 360)
    }

    var linksEnabled: Bool { FeatureFlags.portfolioLinksEnabled() }
    var attachmentsEnabled: Bool { FeatureFlags.portfolioAttachmentsEnabled() }

    private func displayTitle(_ link: Link) -> String {
        if let t = link.title, !t.isEmpty { return t }
        if let url = URL(string: link.rawURL) { return url.host ?? link.rawURL }
        return link.rawURL
    }

    private func openLink(_ link: Link) {
        if let url = URL(string: link.rawURL) {
            if !NSWorkspace.shared.open(url) {
                LoggingService.shared.log("Could not open link \(link.rawURL)", type: .error, logger: .ui)
            }
        }
    }

    private func copyLink(_ link: Link) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(link.rawURL, forType: .string)
    }

    private func quickLook(_ att: Attachment) {
        AttachmentService(dbManager: dbManager).quickLook(attachmentId: att.id)
    }

    private func reveal(_ att: Attachment) {
        AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id)
    }
}

