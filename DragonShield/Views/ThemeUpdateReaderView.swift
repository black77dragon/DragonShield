import SwiftUI
import AppKit

struct ThemeUpdateReaderView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var current: PortfolioThemeUpdate
    @State private var links: [Link] = []
    @State private var attachments: [Attachment] = []
    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    var onChanged: () -> Void = {}
    var onClose: () -> Void = {}

    init(update: PortfolioThemeUpdate, onChanged: @escaping () -> Void = {}, onClose: @escaping () -> Void = {}) {
        _current = State(initialValue: update)
        self.onChanged = onChanged
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(MarkdownRenderer.attributedString(from: current.bodyMarkdown))
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
                                Button("Reveal in Finder") { AttachmentService(dbManager: dbManager).revealInFinder(attachmentId: att.id) }
                            }
                        }
                    }
                }
            }
            actionBar
        }
        .padding(24)
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 360)
        .onAppear { load() }
        .sheet(isPresented: $showEditor) {
            ThemeUpdateEditorView(themeId: current.themeId, themeName: dbManager.getPortfolioTheme(id: current.themeId)?.name ?? "", existing: current, onSave: { updated in
                current = updated
                showEditor = false
                load()
                onChanged()
            }, onCancel: { showEditor = false })
            .environmentObject(dbManager)
        }
        .confirmationDialog("Delete this update? This action can't be undone.", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                DispatchQueue.global(qos: .userInitiated).async {
                    if dbManager.softDeleteThemeUpdate(id: current.id, actor: NSFullUserName(), source: "reader") {
                        DispatchQueue.main.async {
                            onChanged()
                            onClose()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Update — \(current.title) (\(ts(current.createdAt)))")
                .font(.headline)
            Spacer()
            Button("Close") { onClose() }
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Edit") { showEditor = true }
            Button(current.pinned ? "Unpin" : "Pin") { togglePin() }
            Button("Delete") { showDeleteConfirm = true }
            Spacer()
            Button("Close") { onClose() }
        }
    }

    // MARK: - Helpers

    private func load() {
        let linkRepo = ThemeUpdateLinkRepository(dbManager: dbManager)
        links = linkRepo.listLinks(updateId: current.id)
        let repo = ThemeUpdateRepository(dbManager: dbManager)
        attachments = repo.listAttachments(updateId: current.id)
    }

    private func togglePin() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let updated = dbManager.updateThemeUpdate(id: current.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !current.pinned, actor: NSFullUserName(), expectedUpdatedAt: current.updatedAt) {
                DispatchQueue.main.async {
                    current = updated
                    onChanged()
                }
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

    private func ts(_ date: Date) -> String {
        Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
