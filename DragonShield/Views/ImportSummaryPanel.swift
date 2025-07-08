import SwiftUI

struct ImportSummaryPanel: View {
    let summary: PositionImportSummary
    let logs: [String]
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Import Summary")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Rows: \(summary.totalRows)")
                Text("Parsed Rows: \(summary.parsedRows)")
                Text("Cash Accounts: \(summary.cashAccounts)")
                Text("Securities: \(summary.securityRecords)")
            }
            if !logs.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(logs, id: \.self) { msg in
                            Text(msg)
                                .font(.caption2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}
