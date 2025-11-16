import AppKit
import SwiftUI
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

            Table(filteredItems, sortOrder: $sortOrder) {
                TableColumn("Instrument", value: \.name) { Text($0.name).textSelection(.enabled) }
                TableColumn("Type", value: \.type) { Text($0.type).textSelection(.enabled) }
                TableColumn("Cur", value: \.currency) { Text($0.currency).textSelection(.enabled) }
                TableColumn("Last Activity", value: \.lastActivityString) { Text($0.lastActivityString).textSelection(.enabled) }
                TableColumn("Themes") { item in Text("\(item.themesCount)").textSelection(.enabled) }
                TableColumn("Refs") { item in Text("\(item.refsCount)").textSelection(.enabled) }
            }
            .textSelection(.enabled)

            Text("Totals: \(filteredItems.count) instruments")
                .textSelection(.enabled)

            HStack {
                Spacer()
                Button(role: .cancel) { onClose() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .accessibilityLabel("Close")
                .keyboardShortcut("w", modifiers: .command)
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

private extension UnusedInstrument {
    var lastActivityString: String {
        if let d = lastActivity {
            return DateFormatter.iso8601DateOnly.string(from: d)
        }
        return "—"
    }
}
