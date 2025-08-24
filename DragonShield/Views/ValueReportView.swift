import SwiftUI
import AppKit

struct ValueReportView: View {
    let items: [DatabaseManager.ImportSessionValueItem]
    let totalValue: Double
    let onClose: () -> Void

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CHF"
        return f
    }()

    static func exportString(
        items: [DatabaseManager.ImportSessionValueItem],
        totalValue: Double,
        delimiter: String = ","
    ) -> String {
        var lines: [String] = [
            ["Instrument", "Currency", "Value", "Value CHF"].joined(separator: delimiter)
        ]
        for item in items {
            let value = String(format: "%.2f", item.valueOrig)
            let chf = String(format: "%.2f", item.valueChf)
            lines.append(
                [item.instrument, item.currency, value, chf].joined(separator: delimiter)
            )
        }
        let total = String(format: "%.2f", totalValue)
        lines.append(
            ["Total Value CHF", "", "", total].joined(separator: delimiter)
        )
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Value Report")
                .font(.headline)
            Table(items) {
                TableColumn("Instrument") { Text($0.instrument) }
                TableColumn("Currency") { Text($0.currency) }
                TableColumn("Value") { item in Text(String(format: "%.2f", item.valueOrig)) }
                TableColumn("Value CHF") { item in Text(String(format: "%.2f", item.valueChf)) }
            }
            Text("Total Value CHF: " + (Self.chfFormatter.string(from: NSNumber(value: totalValue)) ?? "0"))
            HStack {
                Button("Copy All") { copyAll() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Copy All")
                Button("Export…") { exportAll() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Export")
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
    }

    private func copyAll() {
        let string = Self.exportString(items: items, totalValue: totalValue)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    private func exportAll() {
        let string = Self.exportString(items: items, totalValue: totalValue)
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv", "txt"]
        panel.nameFieldStringValue = "ValueReport.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? string.data(using: .utf8)?.write(to: url)
        }
    }
}
