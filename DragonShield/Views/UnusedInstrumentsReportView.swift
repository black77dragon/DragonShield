import SwiftUI
import AppKit

struct UnusedInstrumentsReportView: View {
    let items: [UnusedInstrument]
    let onClose: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func exportString(items: [UnusedInstrument], delimiter: String = ",") -> String {
        var lines: [String] = [["Instrument", "Type", "Currency", "Last Activity", "Themes", "Refs"].joined(separator: delimiter)]
        for item in items {
            let last = item.lastActivity.map { dateFormatter.string(from: $0) } ?? ""
            lines.append([
                item.name,
                item.type,
                item.currency,
                last,
                String(item.themesCount),
                String(item.refsCount)
            ].joined(separator: delimiter))
        }
        lines.append(["Totals: \(items.count) instruments"].joined(separator: delimiter))
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Unused Instruments (strict)")
                    .font(.headline)
                Spacer()
                Button("Export CSV") { exportAll() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Export Unused Instruments CSV")
                Button("Close") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            Table(items) {
                TableColumn("Instrument") { Text($0.name).textSelection(.enabled) }
                TableColumn("Type") { Text($0.type).textSelection(.enabled) }
                TableColumn("Currency") { Text($0.currency).textSelection(.enabled) }
                TableColumn("Last Activity") { item in
                    Text(item.lastActivity.map { Self.dateFormatter.string(from: $0) } ?? "—").textSelection(.enabled)
                }
                TableColumn("Themes") { item in Text("\(item.themesCount)").textSelection(.enabled) }
                TableColumn("Refs") { item in Text("\(item.refsCount)").textSelection(.enabled) }
            }
            Text("Totals: \(items.count) instruments")
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 560)
    }

    private func exportAll() {
        let csv = Self.exportString(items: items)
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv", "txt"]
        panel.nameFieldStringValue = "UnusedInstruments.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.data(using: .utf8)?.write(to: url)
        }
    }
}
