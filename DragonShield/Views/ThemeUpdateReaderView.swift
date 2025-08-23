import SwiftUI
import AppKit

struct ThemeUpdateReaderView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var update: PortfolioThemeUpdate
    var onEdit: (PortfolioThemeUpdate) -> Void
    var onRefresh: () -> Void

    @State private var links: [Link] = []
    @State private var attachments: [Attachment] = []

    init(update: PortfolioThemeUpdate, onEdit: @escaping (PortfolioThemeUpdate) -> Void = { _ in }, onRefresh: @escaping () -> Void = {}) {
        _update = State(initialValue: update)
        self.onEdit = onEdit
        self.onRefresh = onRefresh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Update — \(update.title) (\(DateFormatting.userFriendly(update.createdAt)))")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                    if !links.isEmpty {
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
                    if !attachments.isEmpty {
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
                Button("Edit") { onEdit(update); dismiss() }
                Button(update.pinned ? "Unpin" : "Pin") { togglePin() }
                Button("Delete", role: .destructive) { deleteUpdate() }
                Spacer()
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { load() }
    }

    private func load() {
        let linkRepo = ThemeUpdateLinkRepository(dbManager: dbManager)
        links = linkRepo.listLinks(updateId: update.id)
        let repo = ThemeUpdateRepository(dbManager: dbManager)
        attachments = repo.listAttachments(updateId: update.id)
    }

    private func togglePin() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
            DispatchQueue.main.async {
                update.pinned.toggle()
                onRefresh()
            }
        }
    }

    private func deleteUpdate() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
            DispatchQueue.main.async {
                onRefresh()
                dismiss()
            }
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

