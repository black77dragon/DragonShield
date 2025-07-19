import SwiftUI

struct ImportSummaryPanel: View {
    let summary: PositionImportSummary
    let logs: [String]
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView(.vertical) {
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
                    if summary.percentValuations > 0 {
                        Text("% Valuation Rows: \(summary.percentValuations)")
                    }
                    if summary.unmatchedInstruments > 0 {
                        Text("Unmatched Instruments: \(summary.unmatchedInstruments)")
                    }
                }
                if !logs.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { _, msg in
                            Text(msg)
                                .font(.caption2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
        .padding()
    }
}
