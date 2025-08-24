import SwiftUI
import AppKit

struct ValueReportView: View {
    let items: [DatabaseManager.ImportSessionValueItem]
    let totalValue: Double
    let onClose: () -> Void

    @State private var columnWidths = ColumnWidths()

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
                    .width(min: columnWidths.instrument, ideal: columnWidths.instrument, max: columnWidths.instrument)
                TableColumn("Currency") { Text($0.currency) }
                    .width(min: columnWidths.currency, ideal: columnWidths.currency, max: columnWidths.currency)
                TableColumn("Value") { item in Text(String(format: "%.2f", item.valueOrig)) }
                    .width(min: columnWidths.value, ideal: columnWidths.value, max: columnWidths.value)
                TableColumn("Value CHF") { item in Text(String(format: "%.2f", item.valueChf)) }
                    .width(min: columnWidths.valueChf, ideal: columnWidths.valueChf, max: columnWidths.valueChf)
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
        .onAppear { updateColumnWidths() }
        .onChange(of: items) { _ in updateColumnWidths() }
    }

    private func updateColumnWidths() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]

        var instrumentWidth = ("Instrument" as NSString).size(withAttributes: attributes).width
        var currencyWidth = ("Currency" as NSString).size(withAttributes: attributes).width
        var valueWidth = ("Value" as NSString).size(withAttributes: attributes).width
        var valueChfWidth = ("Value CHF" as NSString).size(withAttributes: attributes).width

        for item in items {
            instrumentWidth = max(instrumentWidth, (item.instrument as NSString).size(withAttributes: attributes).width)
            currencyWidth = max(currencyWidth, (item.currency as NSString).size(withAttributes: attributes).width)
            let valueStr = String(format: "%.2f", item.valueOrig)
            valueWidth = max(valueWidth, (valueStr as NSString).size(withAttributes: attributes).width)
            let valueChfStr = String(format: "%.2f", item.valueChf)
            valueChfWidth = max(valueChfWidth, (valueChfStr as NSString).size(withAttributes: attributes).width)
        }

        columnWidths = ColumnWidths(
            instrument: instrumentWidth,
            currency: currencyWidth,
            value: valueWidth,
            valueChf: valueChfWidth
        )
    }

    private struct ColumnWidths {
        var instrument: CGFloat = 0
        var currency: CGFloat = 0
        var value: CGFloat = 0
        var valueChf: CGFloat = 0
    }
}
