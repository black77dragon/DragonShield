import SwiftUI

struct AllNotesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    enum Kind: String, CaseIterable, Identifiable { case all, theme, instrument; var id: String { rawValue }; var label: String { rawValue.capitalized } }
    enum SortOrder: String, CaseIterable, Identifiable { case newest, oldest; var id: String { rawValue }; var label: String { self == .newest ? "Newest first" : "Oldest first" } }

    @State private var kind: Kind = .all
    @State private var search: String = ""
    @State private var pinnedFirst: Bool = true
    @State private var sortOrder: SortOrder = .newest
    @State private var newsTypes: [NewsTypeRow] = []
    @State private var selectedTypeId: Int? = nil
    @State private var themeNames: [Int: String] = [:]
    @State private var instrumentNames: [Int: String] = [:]
    @State private var themeUpdates: [PortfolioThemeUpdate] = []
    @State private var instrumentUpdates: [PortfolioThemeAssetUpdate] = []
    @State private var editingTheme: PortfolioThemeUpdate?
    @State private var editingInstrument: PortfolioThemeAssetUpdate?
    @State private var confirmDeleteThemeId: Int? = nil
    @State private var confirmDeleteInstrumentId: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            filters
            if isEmpty {
                Text("No notes match your filters.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if kind != .instrument {
                            ForEach(themeUpdates, id: \.id) { upd in updateCard(upd).id("t-\(upd.id)") }
                        }
                        if kind != .theme {
                            ForEach(instrumentUpdates, id: \.id) { upd in instrumentCard(upd).id("i-\(upd.id)") }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 900, idealWidth: 1100, minHeight: 560, idealHeight: 700)
        .onAppear(perform: initialLoad)
        .sheet(item: $editingTheme) { upd in
            ThemeUpdateEditorView(
                themeId: upd.themeId,
                themeName: themeNames[upd.themeId] ?? "",
                existing: upd,
                onSave: { _ in editingTheme = nil; reload() },
                onCancel: { editingTheme = nil; reload() }
            )
                .environmentObject(dbManager)
        }
        .sheet(item: $editingInstrument) { upd in
            InstrumentUpdateEditorView(
                themeId: upd.themeId,
                instrumentId: upd.instrumentId,
                instrumentName: instrumentNames[upd.instrumentId] ?? "#\(upd.instrumentId)",
                themeName: themeNames[upd.themeId] ?? "",
                existing: upd,
                onSave: { _ in editingInstrument = nil; reload() },
                onCancel: { editingInstrument = nil; reload() }
            )
                .environmentObject(dbManager)
        }
        .confirmationDialog(
            "Send this theme note to the shadow realm?",
            isPresented: Binding(get: { confirmDeleteThemeId != nil }, set: { if !$0 { confirmDeleteThemeId = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteThemeId {
                    _ = dbManager.softDeleteThemeUpdate(id: id, actor: NSFullUserName())
                    confirmDeleteThemeId = nil
                    reload()
                }
            }
            Button("Cancel", role: .cancel) { confirmDeleteThemeId = nil }
        } message: {
            Text("This note will haunt the recycle bin until emptied.")
        }
        .confirmationDialog(
            "Incinerate this instrument note?",
            isPresented: Binding(get: { confirmDeleteInstrumentId != nil }, set: { if !$0 { confirmDeleteInstrumentId = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = confirmDeleteInstrumentId {
                    _ = dbManager.deleteInstrumentUpdate(id: id, actor: NSFullUserName())
                    confirmDeleteInstrumentId = nil
                    reload()
                }
            }
            Button("Cancel", role: .cancel) { confirmDeleteInstrumentId = nil }
        } message: {
            Text("Poof! Gone forever. Choose wisely.")
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            Picker("Kind", selection: $kind) { ForEach(Kind.allCases) { Text($0.label).tag($0) } }
                .onChange(of: kind) { _, _ in reload() }
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .onSubmit { reload() }
            Picker("Type", selection: $selectedTypeId) {
                Text("All").tag(nil as Int?)
                ForEach(newsTypes, id: \.id) { nt in Text(nt.displayName).tag(Optional(nt.id)) }
            }
            .onChange(of: selectedTypeId) { _, _ in reload() }
            Toggle("Pinned first", isOn: $pinnedFirst)
                .toggleStyle(.checkbox)
                .onChange(of: pinnedFirst) { _, _ in reload() }
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { s in Text(s.label).tag(s) }
            }
            .onChange(of: sortOrder) { _, _ in reload() }
            Spacer()
            Button(role: .cancel) { dismiss() } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gray)
            .foregroundColor(.white)
            .keyboardShortcut("w", modifiers: .command)
        }
    }

    private var isEmpty: Bool { (kind != .instrument && themeUpdates.isEmpty) && (kind != .theme && instrumentUpdates.isEmpty) }

    private func initialLoad() {
        newsTypes = NewsTypeRepository(dbManager: dbManager).listActive()
        let themes = dbManager.fetchPortfolioThemes(includeArchived: true)
        themeNames = Dictionary(uniqueKeysWithValues: themes.map { ($0.id, $0.name) })
        instrumentNames = Dictionary(uniqueKeysWithValues: dbManager.fetchAssets().map { ($0.id, $0.name) })
        reload()
    }

    private func reload() {
        let q = search.isEmpty ? nil : search
        if kind != .instrument {
            var list = dbManager.listAllThemeUpdates(view: .active, typeId: selectedTypeId, searchQuery: q, pinnedFirst: pinnedFirst)
            if sortOrder == .oldest { list = list.sorted { $0.createdAt < $1.createdAt } }
            themeUpdates = list
        } else { themeUpdates = [] }
        if kind != .theme {
            var list = dbManager.listAllInstrumentUpdates(pinnedFirst: pinnedFirst, searchQuery: q, typeId: selectedTypeId)
            if sortOrder == .oldest { list = list.sorted { $0.createdAt < $1.createdAt } }
            instrumentUpdates = list
        } else { instrumentUpdates = [] }
    }

    private func updateCard(_ update: PortfolioThemeUpdate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(update.title).fontWeight(.semibold)
                Spacer()
                Button("Edit") { editingTheme = update }.buttonStyle(.link)
                Button("Delete", role: .destructive) { confirmDeleteThemeId = update.id }
                .buttonStyle(.link)
            }
            Text("Theme: \(themeNames[update.themeId] ?? "#\(update.themeId)") · \(DateFormatting.userFriendly(update.createdAt)) · \(update.author) · [\(update.typeDisplayName ?? update.typeCode)]")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown)).lineLimit(4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }

    private func instrumentCard(_ update: PortfolioThemeAssetUpdate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(update.title).fontWeight(.semibold)
                Spacer()
                Button("Edit") { editingInstrument = update }.buttonStyle(.link)
                Button("Delete", role: .destructive) { confirmDeleteInstrumentId = update.id }
                .buttonStyle(.link)
            }
            Text("Instrument: \(instrumentNames[update.instrumentId] ?? "#\(update.instrumentId)") · Theme: \(themeNames[update.themeId] ?? "#\(update.themeId)") · \(DateFormatting.userFriendly(update.createdAt)) · \(update.author) · [\(update.typeDisplayName ?? update.typeCode)]")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(MarkdownRenderer.attributedString(from: update.bodyMarkdown)).lineLimit(4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }
}
