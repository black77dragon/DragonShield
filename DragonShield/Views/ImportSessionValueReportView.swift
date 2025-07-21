import SwiftUI

struct ImportSessionValueReportView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let session: DatabaseManager.ImportSessionData
    @State private var values: [DatabaseManager.ImportSessionValueData] = []

    private static let valueFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Value Report – \(session.sessionName)")
                .font(.headline)
            Table(values) {
                TableColumn("Instrument") { item in
                    Text(item.instrument)
                }
                TableColumn("Currency") { item in
                    Text(item.currency)
                }
                TableColumn("Value") { item in
                    Text(ImportSessionValueReportView.valueFormatter.string(from: NSNumber(value: item.valueOrig)) ?? "0")
                        .monospacedDigit()
                }
                TableColumn("Value CHF") { item in
                    Text(ImportSessionValueReportView.valueFormatter.string(from: NSNumber(value: item.valueChf)) ?? "0")
                        .monospacedDigit()
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 400)
        .onAppear { values = dbManager.fetchImportSessionValues(session.id) }
    }
}

#Preview {
    ImportSessionValueReportView(session: DatabaseManager.ImportSessionData(
        id: 1,
        sessionName: "Demo",
        fileName: "file.csv",
        fileType: "CSV",
        fileSize: 0,
        fileHash: "",
        institutionId: nil,
        importStatus: "COMPLETED",
        totalRows: 0,
        successfulRows: 0,
        failedRows: 0,
        duplicateRows: 0,
        errorLog: nil,
        processingNotes: nil,
        createdAt: Date(),
        startedAt: nil,
        completedAt: nil
    ))
    .environmentObject(DatabaseManager())
}
