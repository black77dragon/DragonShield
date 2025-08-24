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
                    SelectableLabel(text: "Total Rows: \(summary.totalRows)")
                    SelectableLabel(text: "Parsed Rows: \(summary.parsedRows)")
                    SelectableLabel(text: "Cash Accounts: \(summary.cashAccounts)")
                    SelectableLabel(text: "Securities: \(summary.securityRecords)")
                    if summary.unmatchedInstruments > 0 {
                        SelectableLabel(text: "Unmatched Instruments: \(summary.unmatchedInstruments)")
                    }
                    if summary.percentValuationRecords > 0 {
                        SelectableLabel(text: "% Valuation Processed: \(summary.percentValuationRecords)")
                    }
                }
                if !logs.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { _, msg in
                            SelectableLabel(text: msg)
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
