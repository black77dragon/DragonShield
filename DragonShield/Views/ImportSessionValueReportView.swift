import SwiftUI

struct ImportSessionValueReportView: View {
    let items: [DatabaseManager.ImportSessionValueItem]
    let totalValue: Double
    let onClose: () -> Void

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CHF"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Value Report")
                .font(.headline)
            Table(items) { item in
                TableColumn("Instrument") { Text(item.instrument) }
                TableColumn("Currency") { Text(item.currency) }
                TableColumn("Value") { Text(String(format: "%.2f", item.valueOrig)) }
                TableColumn("Value CHF") { Text(String(format: "%.2f", item.valueChf)) }
            }
            Text(
                "Total Value CHF: " + (
                    Self.chfFormatter.string(from: NSNumber(value: totalValue)) ?? "0"
                )
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

