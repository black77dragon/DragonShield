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
                TableColumn("Instrument") { Text($0.instrument).textSelection(.enabled) }
                TableColumn("Currency") { Text($0.currency).textSelection(.enabled) }
                TableColumn("Value") { item in Text(String(format: "%.2f", item.valueOrig)).textSelection(.enabled) }
                TableColumn("Value CHF") { item in Text(String(format: "%.2f", item.valueChf)).textSelection(.enabled) }
            }
            Text("Total Value CHF: " + (Self.chfFormatter.string(from: NSNumber(value: totalValue)) ?? "0"))
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(minWidth: 800, minHeight: 560)
    }
}
