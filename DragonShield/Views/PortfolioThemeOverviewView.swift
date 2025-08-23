import SwiftUI
import AppKit

/// Overview tab for Portfolio Theme details with latest updates and quick metrics.
struct PortfolioThemeOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let themeName: String
    let totalValueChf: Double
    let instrumentCount: Int
    var onMaintenance: () -> Void = {}

    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var attachmentCounts: [Int: Int] = [:]
    @State private var linkCounts: [Int: Int] = [:]
    @State private var searchText: String = ""
    @State private var selectedType: PortfolioThemeUpdate.UpdateType? = nil
    @State private var pinnedFirst: Bool = true
    @State private var dateRange: DateRange = .last90
    @State private var viewingUpdate: PortfolioThemeUpdate?
    @State private var editingUpdate: PortfolioThemeUpdate?

    enum DateRange: String, CaseIterable {
        case last7 = "Last 7d"
        case last30 = "Last 30d"
        case last90 = "Last 90d"
        case all = "All"

        var days: Int? {
            switch self {
            case .last7: return 7
            case .last30: return 30
            case .last90: return 90
            case .all: return nil
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Value CHF \(formatted(totalValueChf))  •  Instruments \(instrumentCount)  •  Last Update \(lastUpdateString())")
                .font(.subheadline)
            HStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: searchText) { _, _ in load() }
                Picker("Type", selection: $selectedType) {
                    Text("All").tag(nil as PortfolioThemeUpdate.UpdateType?)
                    ForEach(PortfolioThemeUpdate.UpdateType.allCases, id: \.self) {
                        Text($0.rawValue).tag(Optional($0))
                    }
                }
                .onChange(of: selectedType) { _, _ in load() }
                Toggle("Pinned first", isOn: $pinnedFirst)
                    .onChange(of: pinnedFirst) { _, _ in load() }
                Picker("Date", selection: $dateRange) {
                    ForEach(DateRange.allCases, id: \.self) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                .onChange(of: dateRange) { _, _ in load() }
                Spacer()
                Button("Maintenance") { onMaintenance() }
            }
            List {
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(DateFormatting.userFriendly(update.createdAt)) • \(update.author) • \(update.type.rawValue)" + (update.pinned ? " • ★Pinned" : "") + " • Links \(linkCounts[update.id] ?? 0) • Files \(attachmentCounts[update.id] ?? 0)")
                            .font(.subheadline)
                        Text("Title: \(update.title)")
                            .fontWeight(.semibold)
                        Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown))
                            .lineLimit(2)
                        HStack {
                            Button("View") { viewingUpdate = update }
                            Button("Edit") { editingUpdate = update }
                            Button(update.pinned ? "Unpin" : "Pin") { togglePin(update) }
                            Button("Delete", role: .destructive) { delete(update) }
                        }
                    }
                }
            }
        }
        .onAppear { load() }
        .sheet(item: $viewingUpdate) { upd in
            ThemeUpdateReaderView(update: upd)
                .environmentObject(dbManager)
        }
        .sheet(item: $editingUpdate) { upd in
            ThemeUpdateEditorView(themeId: themeId, themeName: themeName, existing: upd, onSave: { _ in
                editingUpdate = nil
                load()
            }, onCancel: { editingUpdate = nil })
                .environmentObject(dbManager)
        }
    }

    private func load() {
        var items = dbManager.listThemeUpdates(themeId: themeId, view: .active, type: selectedType, searchQuery: searchText.isEmpty ? nil : searchText, pinnedFirst: pinnedFirst)
        if let days = dateRange.days {
            let cutoff = Date().addingTimeInterval(Double(-days) * 86400)
            let fmt = ISO8601DateFormatter()
            items = items.filter {
                if let d = fmt.date(from: $0.createdAt) {
                    return d >= cutoff
                }
                return true
            }
        }
        updates = items
        let ids = items.map { $0.id }
        attachmentCounts = dbManager.getAttachmentCounts(for: ids)
        linkCounts = dbManager.getLinkCounts(for: ids)
    }

    private func togglePin(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.updateThemeUpdate(id: update.id, title: nil, bodyMarkdown: nil, type: nil, pinned: !update.pinned, actor: NSFullUserName(), expectedUpdatedAt: update.updatedAt)
            DispatchQueue.main.async { load() }
        }
    }

    private func delete(_ update: PortfolioThemeUpdate) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = dbManager.softDeleteThemeUpdate(id: update.id, actor: NSFullUserName())
            DispatchQueue.main.async { load() }
        }
    }

    private func lastUpdateString() -> String {
        if let first = updates.first {
            return DateFormatting.userFriendly(first.createdAt)
        }
        return "—"
    }

    private func formatted(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "0"
    }
}
