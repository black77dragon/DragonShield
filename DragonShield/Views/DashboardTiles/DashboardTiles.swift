import SwiftUI
import Foundation

extension Notification.Name {
    static let dashboardPriceUpdateCompleted = Notification.Name("DashboardPriceUpdateCompleted")
}

protocol DashboardTile: View {
    init()
    static var tileID: String { get }
    static var tileName: String { get }
    static var iconName: String { get }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let headerAccessory: AnyView?
    let content: Content
    private let titleFont: Font
    private let minHeight: CGFloat?
    private let cornerRadius: CGFloat = 12

    init(title: String, titleFont: Font = .headline, headerAccessory: AnyView? = nil, minHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.headerAccessory = headerAccessory
        self.content = content()
        self.titleFont = titleFont
        self.minHeight = minHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(titleFont)
                Spacer()
                if let accessory = headerAccessory {
                    accessory
                }
            }
            content
        }
        .padding(10)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .dashboardTileBackground(cornerRadius: cornerRadius)
    }
}

// Shared CHF whole-number formatter for large sums
private enum LargeSumFormatter {
    static let chfWhole: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    static func chf(_ v: Double) -> String {
        let s = chfWhole.string(from: NSNumber(value: v)) ?? String(format: "%.0f", v)
        return "CHF \(s)"
    }
}

struct TotalValueTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var total: Double = 0
    @State private var lastComputedTotal: Double?
    @State private var delta: Double?
    @State private var loading = false
    @State private var calculationToken = UUID()
    @State private var lastPriceUpdate: Date?

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        return f
    }()

    private static let stalenessFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        f.usesGroupingSeparator = false
        return f
    }()

    init() {}
    static let tileID = "total_value"
    static let tileName = "Total Asset Value (CHF)"
    static let iconName = "francsign.circle"

    var body: some View {
        DashboardCard(title: Self.tileName, minHeight: DashboardTileLayout.heroTileHeight) {
            VStack(alignment: .leading, spacing: 6) {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(formattedTotal(total))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.ds.accentMain)
                }
                if let updateText = priceUpdateText {
                    Text(updateText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                if let delta = delta {
                    HStack(spacing: 6) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : (delta < 0 ? "arrow.down.right" : "arrow.right"))
                            .font(.subheadline.weight(.bold))
                        Text(deltaText(for: delta))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(deltaColor(for: delta))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear { calculate() }
        .onReceive(NotificationCenter.default.publisher(for: .dashboardPriceUpdateCompleted)) { _ in
            calculate(showDelta: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func formattedTotal(_ value: Double) -> String {
        Self.formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func deltaText(for delta: Double) -> String {
        if delta == 0 { return "No change" }
        let absValue = abs(delta)
        let numberText = Self.formatter.string(from: NSNumber(value: absValue)) ?? String(format: "%.0f", absValue)
        let sign = delta > 0 ? "+" : "-"
        return "\(sign)CHF \(numberText)"
    }

    private func deltaColor(for delta: Double) -> Color {
        if delta > 0 { return .numberGreen }
        if delta < 0 { return .numberRed }
        return .secondary
    }

    private var priceUpdateText: String? {
        if loading { return nil }
        guard let lastPriceUpdate else { return "Updated n/a" }
        let hours = max(0, Date().timeIntervalSince(lastPriceUpdate) / 3600)
        let formatted = Self.stalenessFormatter.string(from: NSNumber(value: hours)) ?? String(format: "%.1f", hours)
        return "Updated \(formatted)h ago"
    }

    private func calculate(showDelta: Bool = false) {
        let baseline = showDelta ? lastComputedTotal : nil
        let token = UUID()
        calculationToken = token
        loading = true
        if showDelta { delta = nil }
        DispatchQueue.global(qos: .userInitiated).async {
            let sum = computeTotal()
            let priceUpdatedAt = dbManager.latestPriceUpdateTimestamp()
            DispatchQueue.main.async {
                guard calculationToken == token else { return }
                total = sum
                lastComputedTotal = sum
                lastPriceUpdate = priceUpdatedAt
                if showDelta, let baseline {
                    delta = sum - baseline
                } else {
                    delta = nil
                }
                loading = false
            }
        }
    }

    private func computeTotal() -> Double {
        let positions = dbManager.fetchPositionReports()
        var sum: Double = 0
        for p in positions {
            guard let iid = p.instrumentId, let lp = dbManager.getLatestPrice(instrumentId: iid) else { continue }
            var value = p.quantity * lp.price
            if p.instrumentCurrency.uppercased() != "CHF" {
                let rates = dbManager.fetchExchangeRates(currencyCode: p.instrumentCurrency, upTo: nil)
                guard let rate = rates.first?.rateToChf else { continue }
                value *= rate
            }
            sum += value
        }
        _ = dbManager.recordDailyPortfolioValue(valueChf: sum)
        return sum
    }
}

struct TopPositionsTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = PositionsViewModel()
    @State private var isConsolidated = true

    init() {}
    static let tileID = "top_positions"
    static let tileName = "Top Positions"
    static let iconName = "list.number"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(Self.tileName)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Toggle(isOn: $isConsolidated) {
                    Text("Consolidate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .toggleStyle(SwitchToggleStyle())
            }
            if viewModel.calculating {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(Array(viewModel.topPositions.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top) {
                                Text(item.instrument)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(LargeSumFormatter.chf(item.valueCHF))
                                        .font(.system(.body, design: .monospaced).bold())
                                    Text(item.currency)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(height: DashboardTileLayout.rowHeight)
                            if index != viewModel.topPositions.count - 1 {
                                Divider().foregroundColor(Theme.tileBorder)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 16)
        .onChange(of: isConsolidated) { _, newValue in
            viewModel.setConsolidation(enabled: newValue)
        }
        .onAppear { viewModel.calculateTopPositions(db: dbManager, consolidated: isConsolidated) }
        .accessibilityElement(children: .combine)
    }
}

struct TextTile: DashboardTile {
    init() {}
    static let tileID = "text"
    static let tileName = "Text Tile"
    static let iconName = "text.alignleft"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla ut nulla sit amet massa volutpat accumsan.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Themes Overview Tile

struct ThemesOverviewTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.openWindow) private var openWindow
    @State private var rows: [Row] = []
    @State private var loading = false
    @State private var openThemeId: Int? = nil

    init() {}
    static let tileID = "themes_overview"
    static let tileName = "Portfolio Themes"
    static let iconName = "square.grid.2x2"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                HStack(spacing: 8) {
                    DashboardCategoryPill(category: .allocation)
                        .fixedSize()
                    if loading == false && !rows.isEmpty {
                        Text("\(rows.count)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Theme.primaryAccent)
                    }
                }
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if rows.isEmpty {
                Text("No themes found").foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: DashboardTileLayout.rowSpacing) {
                        header
                        ForEach(rows) { r in
                            HStack {
                                Button(r.name) { openWindow(id: "themeWorkspace", value: r.id) }
                                    .buttonStyle(.link)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(r.instrumentCount)")
                                    .frame(width: 80, alignment: .trailing)
                                Text(LargeSumFormatter.chf(r.countedValue))
                                    .frame(width: 140, alignment: .trailing)
                            }
                            .font(.system(size: 13))
                            .frame(height: DashboardTileLayout.rowHeight)
                        }
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 16)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            Text("Theme").frame(maxWidth: .infinity, alignment: .leading)
            Text("Instruments").frame(width: 80, alignment: .trailing)
            Text("Counted Value").frame(width: 140, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func load() {
        loading = true
        DispatchQueue.global().async {
            let themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false)
            var result: [Row] = []
            let fx = FXConversionService(dbManager: dbManager)
            let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
            for t in themes {
                let snap = service.snapshot(themeId: t.id)
                // Counted total: sum of OK rows where User % > 0
                let counted = snap.rows.reduce(0.0) { acc, r in
                    (r.userTargetPct > 0 && r.status == .ok) ? acc + r.currentValueBase : acc
                }
                result.append(Row(id: t.id, name: t.name, instrumentCount: t.instrumentCount, countedValue: counted))
            }
            result.sort { $0.countedValue > $1.countedValue }
            DispatchQueue.main.async { rows = result; loading = false }
        }
    }

    private struct Ident: Identifiable { let value: Int; var id: Int { value } }

    // No longer used; replaced by LargeSumFormatter.chf

    private struct Row: Identifiable {
        let id: Int
        let name: String
        let instrumentCount: Int
        let countedValue: Double
    }
}

// MARK: - All Notes Tile

struct AllNotesTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var totalCount: Int = 0
    @State private var recent: [Row] = []
    @State private var loading = false
    @State private var openAll = false
    @State private var search: String = ""
    @State private var pinnedFirst: Bool = true
    @State private var suggestions: [String] = []
    @State private var selectedSuggestionId: String? = nil
    @State private var showNotePicker = false
    @State private var editingTheme: PortfolioThemeUpdate?
    @State private var editingInstrument: PortfolioThemeAssetUpdate?
    @State private var themeNames: [Int: String] = [:]
    @State private var instrumentNames: [Int: String] = [:]

    init() {}
    static let tileID = "all_notes"
    static let tileName = "All Notes"
    static let iconName = "note.text"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                HStack(spacing: 10) {
                    Button("Open All") { openAll = true }
                        .buttonStyle(.link)
                    DashboardCategoryPill(category: DashboardTileCategories.category(for: Self.tileID))
                        .fixedSize()
                    Text(loading ? "—" : String(totalCount))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.primaryAccent)
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose Note")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text(selectedNoteDisplay)
                            .foregroundColor(search.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Choose Note…") {
                            showNotePicker = true
                            loadSuggestions()
                        }
                    }
                    .frame(minWidth: 260, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Pinned first", isOn: $pinnedFirst)
                    .toggleStyle(.checkbox)
                    .onChange(of: pinnedFirst) { _, _ in load() }
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                if recent.isEmpty {
                    Text("No recent notes")
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(recent) { r in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text(r.title)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .help(r.title)
                                    Spacer()
                                    Text(r.when)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Text(r.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .help(r.subtitle)
                                    Spacer()
                                    Text(r.type)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { openEditor(r) }
                            Divider()
                        }
                    }
                    .zIndex(0)
                }
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 16)
        .onAppear { load(); loadSuggestions() }
        .onChange(of: search) { _, newValue in
            loadSuggestions()
            if newValue.isEmpty { selectedSuggestionId = nil }
        }
        .sheet(isPresented: $openAll) {
            AllNotesView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showNotePicker) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Note")
                    .font(.headline)
                FloatingSearchPicker(
                    title: "Choose Note",
                    placeholder: "Search notes",
                    items: notePickerItems,
                    selectedId: notePickerBinding,
                    showsClearButton: true,
                    emptyStateText: "No suggestions",
                    query: $search,
                    onSelection: { _ in
                        showNotePicker = false
                    },
                    onClear: {
                        notePickerBinding.wrappedValue = nil
                    },
                    onSubmit: { _ in load() },
                    selectsFirstOnSubmit: false
                )
                .frame(minWidth: 360)
                HStack {
                    Spacer()
                    Button("Close") {
                        showNotePicker = false
                    }
                }
            }
            .padding(16)
            .frame(width: 480)
            .onAppear { loadSuggestions() }
        }
        .sheet(item: $editingTheme) { upd in
            ThemeUpdateEditorView(themeId: upd.themeId, themeName: themeNames[upd.themeId] ?? "", existing: upd, onSave: { _ in editingTheme = nil; load() }, onCancel: { editingTheme = nil })
                .environmentObject(dbManager)
        }
        .sheet(item: $editingInstrument) { upd in
            if let themeId = upd.themeId {
                InstrumentUpdateEditorView(themeId: themeId, instrumentId: upd.instrumentId, instrumentName: instrumentNames[upd.instrumentId] ?? "#\(upd.instrumentId)", themeName: themeNames[themeId] ?? "", existing: upd, onSave: { _ in editingInstrument = nil; load() }, onCancel: { editingInstrument = nil })
                    .environmentObject(dbManager)
            } else {
                InstrumentNoteEditorView(instrumentId: upd.instrumentId, instrumentName: instrumentNames[upd.instrumentId] ?? "#\(upd.instrumentId)", existing: upd, onSave: { _ in editingInstrument = nil; load() }, onCancel: { editingInstrument = nil })
                    .environmentObject(dbManager)
            }
        }
    }

    private func load() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let q = search.isEmpty ? nil : search
            let theme = dbManager.listAllThemeUpdates(view: .active, typeId: nil, searchQuery: q, pinnedFirst: pinnedFirst)
            let instr = dbManager.listAllInstrumentUpdates(pinnedFirst: pinnedFirst, searchQuery: q, typeId: nil)
            let themes = dbManager.fetchPortfolioThemes(includeArchived: true)
            let themeNameMap = Dictionary(uniqueKeysWithValues: themes.map { ($0.id, $0.name) })
            let instrumentNameMap = Dictionary(uniqueKeysWithValues: dbManager.fetchAssets().map { ($0.id, $0.name) })
            let combined: [Row] = Array(theme.prefix(3)).map { t in
                Row(id: "t-\(t.id)", title: t.title, subtitle: "Theme: \(themeNameMap[t.themeId] ?? "#\(t.themeId)")", type: t.typeDisplayName ?? t.typeCode, when: DateFormatting.userFriendly(t.createdAt))
            } + Array(instr.prefix(3)).map { u in
                let themeLabel: String
                if let tid = u.themeId {
                    themeLabel = themeNameMap[tid] ?? "#\(tid)"
                } else {
                    themeLabel = "General"
                }
                return Row(id: "i-\(u.id)", title: u.title, subtitle: "Instr: \(instrumentNameMap[u.instrumentId] ?? "#\(u.instrumentId)") · Theme: \(themeLabel)", type: u.typeDisplayName ?? u.typeCode, when: DateFormatting.userFriendly(u.createdAt))
            }
            DispatchQueue.main.async {
                self.totalCount = theme.count + instr.count
                self.recent = combined
                self.loading = false
            }
        }
    }

    private func loadSuggestions() {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.global(qos: .userInitiated).async {
            let theme = dbManager.listAllThemeUpdates(view: .active, typeId: nil, searchQuery: q.isEmpty ? nil : q, pinnedFirst: pinnedFirst)
            let instr = dbManager.listAllInstrumentUpdates(pinnedFirst: pinnedFirst, searchQuery: q.isEmpty ? nil : q, typeId: nil)
            // Build a set of titles as suggestions, keep order by recency
            var seen = Set<String>()
            var sugg: [String] = []
            for t in theme.prefix(30) {
                if !t.title.isEmpty, !seen.contains(t.title) { seen.insert(t.title); sugg.append(t.title) }
            }
            for u in instr.prefix(30) {
                if !u.title.isEmpty, !seen.contains(u.title) { seen.insert(u.title); sugg.append(u.title) }
            }
            DispatchQueue.main.async { self.suggestions = sugg }
        }
    }

    private func openEditor(_ row: Row) {
        if row.id.hasPrefix("t-") {
            if let id = Int(row.id.dropFirst(2)), let upd = dbManager.getThemeUpdate(id: id) {
                editingTheme = upd
            }
        } else if row.id.hasPrefix("i-") {
            if let id = Int(row.id.dropFirst(2)), let upd = dbManager.getInstrumentUpdate(id: id) {
                editingInstrument = upd
            }
        }
    }

    private var suggestionItems: [NoteSuggestion] {
        suggestions.map { NoteSuggestion(value: $0) }
    }

    private var notePickerItems: [FloatingSearchPicker.Item] {
        suggestionItems.map { suggestion in
            FloatingSearchPicker.Item(
                id: AnyHashable(suggestion.value),
                title: suggestion.value,
                subtitle: nil,
                searchText: suggestion.value
            )
        }
    }

    private var notePickerBinding: Binding<AnyHashable?> {
        Binding<AnyHashable?>(
            get: { selectedSuggestionId.map { AnyHashable($0) } },
            set: { newValue in
                if let value = newValue as? String {
                    selectedSuggestionId = value
                    search = value
                    load()
                } else {
                    selectedSuggestionId = nil
                    search = ""
                    load()
                    loadSuggestions()
                }
            }
        )
    }

    private var selectedNoteDisplay: String {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No note selected" : trimmed
    }

    private struct Row: Identifiable { let id: String; let title: String; let subtitle: String; let type: String; let when: String }
}

private struct NoteSuggestion: Identifiable {
    let value: String
    var id: String { value }
}

struct MissingPricesTile: DashboardTile {
    init() {}
    static let tileID = "missing_prices"
    static let tileName = "Missing Prices"
    static let iconName = "exclamationmark.triangle"

    @EnvironmentObject var dbManager: DatabaseManager
    struct MissingPriceItem: Identifiable { let id: Int; let name: String; let currency: String }
    @State private var items: [MissingPriceItem] = []
    @State private var loading = false
    @State private var editingInstrumentId: Int? = nil

    // Split out complex bits to help type-checker
    private func rowView(_ item: MissingPriceItem) -> some View {
        HStack {
            Text(item.name)
                .foregroundColor(Theme.primaryAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture(count: 2) { editingInstrumentId = item.id }
                .help("Open instrument maintenance (double‑click)")
            Text(item.currency)
                .foregroundColor(.secondary)
            Button("Edit Price") { editingInstrumentId = item.id }
                .buttonStyle(.link)
        }
        .font(.system(size: 13))
        .frame(height: DashboardTileLayout.rowHeight)
    }

    private var editBinding: Binding<Ident?> {
        Binding<Ident?>(
            get: { editingInstrumentId.map { Ident(value: $0) } },
            set: { newVal in editingInstrumentId = newVal?.value }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(items.isEmpty ? "—" : String(items.count))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if items.isEmpty {
                Text("All instruments have a latest price.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(items, content: rowView)
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: items.count > 6 ? 200 : .infinity)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .dashboardTileBackground(cornerRadius: 16)
        .overlay(alignment: .leading) { Rectangle().fill(Color.numberRed).frame(width: 4).cornerRadius(2) }
        .onAppear(perform: load)
        .sheet(item: editBinding) { ident in
            InstrumentEditView(
                instrumentId: ident.value,
                isPresented: Binding(
                    get: { editingInstrumentId != nil },
                    set: { if !$0 { editingInstrumentId = nil } }
                )
            )
            .environmentObject(dbManager)
        }
    }

    private func load() {
        loading = true
        DispatchQueue.global().async {
            var res: [MissingPriceItem] = []
            let assets = dbManager.fetchAssets()
            for a in assets {
                if dbManager.getLatestPrice(instrumentId: a.id) == nil {
                    res.append(MissingPriceItem(id: a.id, name: a.name, currency: a.currency))
                }
            }
            DispatchQueue.main.async {
                self.items = res
                self.loading = false
            }
        }
    }

    private struct Ident: Identifiable { let value: Int; var id: Int { value } }
}

struct TileInfo {
    let id: String
    let name: String
    let icon: String
    let viewBuilder: () -> AnyView
}

enum TileRegistry {
    static let all: [TileInfo] = [
        TileInfo(id: TotalValueTile.tileID, name: TotalValueTile.tileName, icon: TotalValueTile.iconName) { AnyView(TotalValueTile()) },
        TileInfo(id: TopPositionsTile.tileID, name: TopPositionsTile.tileName, icon: TopPositionsTile.iconName) { AnyView(TopPositionsTile()) },
        TileInfo(id: CryptoTop5Tile.tileID, name: CryptoTop5Tile.tileName, icon: CryptoTop5Tile.iconName) { AnyView(CryptoTop5Tile()) },
        TileInfo(id: InstitutionsAUMTile.tileID, name: InstitutionsAUMTile.tileName, icon: InstitutionsAUMTile.iconName) { AnyView(InstitutionsAUMTile()) },
        TileInfo(id: UnusedInstrumentsTile.tileID, name: UnusedInstrumentsTile.tileName, icon: UnusedInstrumentsTile.iconName) { AnyView(UnusedInstrumentsTile()) },
        TileInfo(id: UnthemedInstrumentsTile.tileID, name: UnthemedInstrumentsTile.tileName, icon: UnthemedInstrumentsTile.iconName) { AnyView(UnthemedInstrumentsTile()) },
        TileInfo(id: ThemesOverviewTile.tileID, name: ThemesOverviewTile.tileName, icon: ThemesOverviewTile.iconName) { AnyView(ThemesOverviewTile()) },

        TileInfo(id: CurrencyExposureTile.tileID, name: CurrencyExposureTile.tileName, icon: CurrencyExposureTile.iconName) { AnyView(CurrencyExposureTile()) },
        TileInfo(id: RiskScoreTile.tileID, name: RiskScoreTile.tileName, icon: RiskScoreTile.iconName) { AnyView(RiskScoreTile()) },
        TileInfo(id: RiskSRIDonutTile.tileID, name: RiskSRIDonutTile.tileName, icon: RiskSRIDonutTile.iconName) { AnyView(RiskSRIDonutTile()) },
        TileInfo(id: RiskLiquidityDonutTile.tileID, name: RiskLiquidityDonutTile.tileName, icon: RiskLiquidityDonutTile.iconName) { AnyView(RiskLiquidityDonutTile()) },
        TileInfo(id: RiskOverridesTile.tileID, name: RiskOverridesTile.tileName, icon: RiskOverridesTile.iconName) { AnyView(RiskOverridesTile()) },
        TileInfo(id: RiskBucketsTile.tileID, name: RiskBucketsTile.tileName, icon: RiskBucketsTile.iconName) { AnyView(RiskBucketsTile()) },
        TileInfo(id: TextTile.tileID, name: TextTile.tileName, icon: TextTile.iconName) { AnyView(TextTile()) },
        TileInfo(id: AccountsNeedingUpdateTile.tileID, name: AccountsNeedingUpdateTile.tileName, icon: AccountsNeedingUpdateTile.iconName) { AnyView(AccountsNeedingUpdateTile()) },
        TileInfo(id: MissingPricesTile.tileID, name: MissingPricesTile.tileName, icon: MissingPricesTile.iconName) { AnyView(MissingPricesTile()) },
        TileInfo(id: AllNotesTile.tileID, name: AllNotesTile.tileName, icon: AllNotesTile.iconName) { AnyView(AllNotesTile()) },
        TileInfo(id: InstrumentDashboardTile.tileID, name: InstrumentDashboardTile.tileName, icon: InstrumentDashboardTile.iconName) { AnyView(InstrumentDashboardTile()) },
        TileInfo(id: WeeklyChecklistTile.tileID, name: WeeklyChecklistTile.tileName, icon: WeeklyChecklistTile.iconName) { AnyView(WeeklyChecklistTile()) },
        TileInfo(id: TodoDashboardTile.tileID, name: TodoDashboardTile.tileName, icon: TodoDashboardTile.iconName) { AnyView(TodoDashboardTile()) },
        TileInfo(id: UpcomingAlertsTile.tileID, name: UpcomingAlertsTile.tileName, icon: UpcomingAlertsTile.iconName) { AnyView(UpcomingAlertsTile()) },
    ]

    static func view(for id: String) -> AnyView? {
        all.first(where: { $0.id == id })?.viewBuilder()
    }

    static func info(for id: String) -> (name: String, icon: String) {
        if let tile = all.first(where: { $0.id == id }) {
            return (tile.name, tile.icon)
        }
        return ("", "")
    }
}
