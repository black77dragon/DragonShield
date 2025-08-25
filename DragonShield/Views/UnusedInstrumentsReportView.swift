import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct UnusedInstrumentsReportView: View {
    @State private var items: [UnusedInstrument] = []
    @State private var typeFilter: String = "Any"
    @State private var currencyFilter: String = "Any"
    @State private var excludeCash: Bool = true
    @State private var sortOrder: [KeyPathComparator<UnusedInstrument>] = [KeyPathComparator(\UnusedInstrument.name)]
    @State private var errorMessage: String? = nil
    let onClose: () -> Void

    private var filteredItems: [UnusedInstrument] {
        items.filter { (typeFilter == "Any" || $0.type == typeFilter) && (currencyFilter == "Any" || $0.currency == currencyFilter) }
    }

    private var typeOptions: [String] {
        ["Any"] + Array(Set(items.map { $0.type })).sorted()
    }

    private var currencyOptions: [String] {
        ["Any"] + Array(Set(items.map { $0.currency })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unused Instruments (strict)").font(.headline)
                Spacer()
                Button("Export CSV") { export() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Export CSV")
            }

            HStack {
                Picker("Type", selection: $typeFilter) {
                    ForEach(typeOptions, id: \.self) { Text($0) }
                }
                Picker("Currency", selection: $currencyFilter) {
                    ForEach(currencyOptions, id: \.self) { Text($0) }
                }
                Toggle("Exclude Cash", isOn: $excludeCash)
                    .onChange(of: excludeCash) { _, _ in load() }
                    .accessibilityLabel("Exclude Cash")
                Spacer()
            }

            if let msg = errorMessage {
                Text(msg).foregroundColor(.red)
            }

            PersistentUnusedInstrumentsTable(items: filteredItems, sortOrder: $sortOrder)

            Text("Totals: \(filteredItems.count) instruments")
                .textSelection(.enabled)

            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("Close")
            }
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 560)
        .onAppear(perform: load)
    }

    private func load() {
        let db = DatabaseManager()
        let repo = InstrumentUsageRepository(dbManager: db)
        do {
            items = try repo.unusedStrict(excludeCash: excludeCash)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }

    static func exportString(items: [UnusedInstrument], delimiter: String = ",") -> String {
        let formatter = DateFormatter.iso8601DateOnly
        var lines = ["Instrument,Type,Currency,Last Activity,Themes,Refs"]
        for i in items {
            let date = i.lastActivity.map { formatter.string(from: $0) } ?? "—"
            lines.append([i.name, i.type, i.currency, date, String(i.themesCount), String(i.refsCount)].joined(separator: delimiter))
        }
        return lines.joined(separator: "\n")
    }

    private func export() {
        let string = Self.exportString(items: filteredItems)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType.plainText]
        panel.nameFieldStringValue = "UnusedInstruments.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? string.data(using: .utf8)?.write(to: url)
        }
    }
}

@MainActor
struct PersistentUnusedInstrumentsTable: NSViewRepresentable {
    var items: [UnusedInstrument]
    @Binding var sortOrder: [KeyPathComparator<UnusedInstrument>]

    @AppStorage("unusedInstrumentInstrumentWidth") var instrumentWidth: Double = 150
    @AppStorage("unusedInstrumentTypeWidth") var typeWidth: Double = 100
    @AppStorage("unusedInstrumentCurrencyWidth") var currencyWidth: Double = 80
    @AppStorage("unusedInstrumentLastActivityWidth") var lastActivityWidth: Double = 120
    @AppStorage("unusedInstrumentThemesWidth") var themesWidth: Double = 60
    @AppStorage("unusedInstrumentRefsWidth") var refsWidth: Double = 60

    func makeNSView(context: Context) -> NSHostingView<TableView> {
        let hosting = NSHostingView(rootView: table)
        if let tableView = findTableView(in: hosting) {
            applyWidths(tableView)
            context.coordinator.tableView = tableView
            NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.columnDidResize(_:)), name: NSTableView.columnDidResizeNotification, object: tableView)
        }
        return hosting
    }

    func updateNSView(_ nsView: NSHostingView<TableView>, context: Context) {
        nsView.rootView = table
        if let tableView = context.coordinator.tableView {
            applyWidths(tableView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private var table: TableView {
        TableView(items: items, sortOrder: $sortOrder)
    }

    private func applyWidths(_ tableView: NSTableView) {
        for column in tableView.tableColumns {
            switch column.identifier.rawValue {
            case "Instrument":
                column.width = instrumentWidth
            case "Type":
                column.width = typeWidth
            case "Cur":
                column.width = currencyWidth
            case "Last Activity":
                column.width = lastActivityWidth
            case "Themes":
                column.width = themesWidth
            case "Refs":
                column.width = refsWidth
            default:
                break
            }
        }
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for sub in view.subviews {
            if let t = findTableView(in: sub) { return t }
        }
        return nil
    }

    struct TableView: View {
        var items: [UnusedInstrument]
        @Binding var sortOrder: [KeyPathComparator<UnusedInstrument>]
        var body: some View {
            Table(items, sortOrder: $sortOrder) {
                TableColumn("Instrument", value: \.name) { Text($0.name).textSelection(.enabled) }
                TableColumn("Type", value: \.type) { Text($0.type).textSelection(.enabled) }
                TableColumn("Cur", value: \.currency) { Text($0.currency).textSelection(.enabled) }
                TableColumn("Last Activity", value: \.lastActivityString) { Text($0.lastActivityString).textSelection(.enabled) }
                TableColumn("Themes") { item in Text("\(item.themesCount)").textSelection(.enabled) }
                TableColumn("Refs") { item in Text("\(item.refsCount)").textSelection(.enabled) }
            }
            .textSelection(.enabled)
        }
    }

    class Coordinator: NSObject {
        var parent: PersistentUnusedInstrumentsTable
        weak var tableView: NSTableView?

        init(_ parent: PersistentUnusedInstrumentsTable) {
            self.parent = parent
        }

        @objc func columnDidResize(_ notification: Notification) {
            guard let column = notification.userInfo?["NSTableViewColumn"] as? NSTableColumn else { return }
            DispatchQueue.main.async {
                switch column.identifier.rawValue {
                case "Instrument":
                    self.parent.instrumentWidth = Double(column.width)
                case "Type":
                    self.parent.typeWidth = Double(column.width)
                case "Cur":
                    self.parent.currencyWidth = Double(column.width)
                case "Last Activity":
                    self.parent.lastActivityWidth = Double(column.width)
                case "Themes":
                    self.parent.themesWidth = Double(column.width)
                case "Refs":
                    self.parent.refsWidth = Double(column.width)
                default:
                    break
                }
            }
        }

        deinit {
            if let tableView = tableView {
                NotificationCenter.default.removeObserver(self, name: NSTableView.columnDidResizeNotification, object: tableView)
            }
        }
    }
}

private extension UnusedInstrument {
    var lastActivityString: String {
        if let d = lastActivity {
            return DateFormatter.iso8601DateOnly.string(from: d)
        }
        return "—"
    }
}
