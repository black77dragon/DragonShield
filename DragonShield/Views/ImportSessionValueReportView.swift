import SwiftUI

struct ImportSessionValueReportView: View {
    let items: [DatabaseManager.ImportSessionValueItem]
    let totalValue: Double
    let onClose: () -> Void

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
            Text(
                "Total Value CHF: " + (ImportSessionHistoryView.chfFormatter.string(from: NSNumber(value: totalValue)) ?? "0")
            )
            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
    }
}
