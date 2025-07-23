import SwiftUI

struct RestoreComparisonView: View {
    let items: [RestoreComparisonRow]
    let onClose: () -> Void

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Restore Comparison")
                .font(.headline)
            ScrollView {
                Table(items) {
                    TableColumn("Table Name") { item in
                        Text(item.table)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    TableColumn("Pre-Restore Count") { item in
                        Text(Self.intFormatter.string(from: NSNumber(value: item.preCount)) ?? "0")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("Post-Restore Count") { item in
                        Text(Self.intFormatter.string(from: NSNumber(value: item.postCount)) ?? "0")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    TableColumn("Delta") { item in
                        Text((item.delta >= 0 ? "+" : "") + (Self.intFormatter.string(from: NSNumber(value: abs(item.delta))) ?? "0"))
                            .foregroundColor(item.delta >= 0 ? Color.success : Color.error)
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
