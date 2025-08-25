// DragonShield/Views/UnusedInstrumentsReportView.swift
// MARK: - Version 1.0
// Modal listing instruments with no positions, themes, or active references.

import SwiftUI
import AppKit

struct UnusedInstrumentsReportView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var instruments: [UnusedInstrument] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Unused Instruments (strict)")
                    .font(.headline)
                Spacer()
                Button("Export CSV") { exportCSV() }
                Button("Close") { dismiss() }
            }
            .padding()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .padding()
            } else {
                Table(instruments) {
                    TableColumn("Instrument") { item in
                        Text(item.name)
                    }
                    TableColumn("Type") { item in
                        Text(item.type)
                    }
                    TableColumn("Cur") { item in
                        Text(item.currency)
                    }
                    TableColumn("Last Activity") { item in
                        Text(item.lastActivity.map { DateFormatting.userFriendly($0) } ?? "—")
                    }
                    TableColumn("Themes") { item in
                        Text("\(item.themesCount)")
                    }
                    TableColumn("Refs") { item in
                        Text("\(item.refsCount)")
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 560)
        .onAppear(perform: load)
    }

    private func load() {
        do {
            let repo = InstrumentUsageRepository(dbManager: dbManager)
            instruments = try repo.unusedStrict()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "unused_instruments.csv"
        if panel.runModal() == .OK, let url = panel.url {
            let header = "Instrument,Type,Currency,Last Activity,Themes,Refs\n"
            let formatter = DateFormatter.iso8601DateOnly
            let rows = instruments.map { item in
                [
                    item.name,
                    item.type,
                    item.currency,
                    item.lastActivity.map { formatter.string(from: $0) } ?? "",
                    String(item.themesCount),
                    String(item.refsCount)
                ].map { $0.replacingOccurrences(of: ",", with: " ") }.joined(separator: ",")
            }.joined(separator: "\n")
            try? (header + rows).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
