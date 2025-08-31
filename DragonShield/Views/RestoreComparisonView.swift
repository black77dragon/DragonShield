import SwiftUI

struct RestoreComparisonView: View {
    let rows: [RestoreDelta]
    var onClose: () -> Void

    private static let numFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 0
        return f
    }()

    private func fmt(_ value: Int) -> String {
        Self.numFormatter.string(from: NSNumber(value: value)) ?? "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Restore Comparison")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.primaryAccent)
            Table(rows) {
                TableColumn("Table Name") { row in
                    Text(row.table)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                TableColumn("Pre-Restore Count") { row in
                    Text(fmt(row.preCount))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                TableColumn("Post-Restore Count") { row in
                    Text(fmt(row.postCount))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                TableColumn("Delta") { row in
                    let d = row.delta
                    Text((d >= 0 ? "+" : "-") + fmt(abs(d)))
                        .foregroundColor(d >= 0 ? .green : .red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(minHeight: 300)
            HStack {
                Spacer()
                Button(role: .cancel) { onClose() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
            }
        }
        .padding(24)
        // Ensure all table columns are visible without horizontal scrolling
        .frame(minWidth: 700, minHeight: 400)
    }
}
