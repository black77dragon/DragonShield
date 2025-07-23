import SwiftUI

struct RestoreDelta: Identifiable {
    let id = UUID()
    let table: String
    let preCount: Int
    let postCount: Int
    var delta: Int { postCount - preCount }
}

struct RestoreComparisonView: View {
    let deltas: [RestoreDelta]
    var onClose: () -> Void

    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    private func fmt(_ n: Int) -> String {
        formatter.string(from: NSNumber(value: n)) ?? "0"
    }

    private func deltaString(_ n: Int) -> String {
        let sign = n >= 0 ? "+" : ""
        return sign + fmt(n)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore Comparison")
                .font(.headline)

            HStack {
                Text("Table Name")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Pre-Restore Count")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("Post-Restore Count")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("Delta")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(deltas.enumerated()), id: \..offset) { idx, item in
                        HStack {
                            Text(item.table)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(fmt(item.preCount))
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(fmt(item.postCount))
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(deltaString(item.delta))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(item.delta >= 0 ? .green : .red)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                        .background(idx % 2 == 0 ? Color.gray.opacity(0.05) : Color.clear)
                    }
                }
            }
            .frame(maxHeight: 300)

            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}
