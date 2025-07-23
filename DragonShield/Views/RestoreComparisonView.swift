import SwiftUI

struct RestoreComparisonView: View {
    let rows: [RestoreComparisonRow]
    let onClose: () -> Void

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.groupingSize = 3
        f.usesGroupingSeparator = true
        return f
    }()

    private func format(_ n: Int) -> String {
        Self.intFormatter.string(from: NSNumber(value: n)) ?? "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Restore Comparison")
                .font(.headline)
            ScrollView {
                Table(rows) {
                    TableColumn("Table Name") { Text($0.table) }
                    TableColumn("Pre-Restore Count") { row in
                        Text(format(row.preCount))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("Post-Restore Count") { row in
                        Text(format(row.postCount))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("Delta") { row in
                        Text((row.delta >= 0 ? "+" : "") + format(row.delta))
                            .foregroundColor(row.delta >= 0 ? .success : .error)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
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
