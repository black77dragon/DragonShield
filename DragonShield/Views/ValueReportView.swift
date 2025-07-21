import SwiftUI

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
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
    }
}
