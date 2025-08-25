// DragonShield/Views/UnusedInstrumentsView.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Initial unused instruments report view.

import SwiftUI

struct UnusedInstrumentsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var items: [UnusedInstrument] = []

    static func exportString(items: [UnusedInstrument], delimiter: String = ",") -> String {
        var lines = ["Instrument,Type,Currency,Last Activity,In Themes"]
        for item in items {
            let last = item.lastActivity.map { DateFormatter.iso8601DateOnly.string(from: $0) } ?? ""
            lines.append([item.name, item.type, item.currency, last, "\(item.themeCount)"].joined(separator: delimiter))
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unused Instruments")
                .font(.headline)
            Table(items) {
                TableColumn("Instrument") { Text($0.name).textSelection(.enabled) }
                TableColumn("Type") { Text($0.type).textSelection(.enabled) }
                TableColumn("Currency") { Text($0.currency).textSelection(.enabled) }
                TableColumn("Last Activity") { item in
                    Text(item.lastActivity.map { DateFormatter.iso8601DateOnly.string(from: $0) } ?? "—")
                        .textSelection(.enabled)
                }
                TableColumn("In Themes") { item in
                    Text("\(item.themeCount)").textSelection(.enabled)
                }
            }
            HStack {
                Button("Export CSV") { exportAll() }
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 560)
        .onAppear { items = dbManager.fetchUnusedInstruments() }
    }

    private func exportAll() {
        let string = Self.exportString(items: items)
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv", "txt"]
        panel.nameFieldStringValue = "Unused_Instruments.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? string.data(using: .utf8)?.write(to: url)
        }
    }
}
