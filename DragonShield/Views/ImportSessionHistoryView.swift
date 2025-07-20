import SwiftUI

struct ImportSessionHistoryView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var vm = ImportSessionHistoryViewModel()
    @State private var selected = Set<Int>()
    @State private var detail: ImportSessionHistoryViewModel.SessionRow? = nil

    private let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Table(vm.sessions, selection: $selected) {
                TableColumn("Import Date") { row in
                    Text(row.data.createdAt, formatter: DateFormatter.iso8601DateTime)
                }
                TableColumn("Session Name") { row in
                    Text(row.data.sessionName)
                }
                TableColumn("Import Status") { row in
                    Text(row.data.importStatus)
                }
                TableColumn("Total Rows") { row in
                    Text(String(row.data.totalRows))
                }
                TableColumn("Successful Rows") { row in
                    Text(String(row.data.successfulRows))
                }
                TableColumn("Failed Rows") { row in
                    Text(String(row.data.failedRows))
                }
                TableColumn("Total Report Value") { row in
                    Text(chfFormatter.string(from: NSNumber(value: row.totalValue)) ?? "0")
                }
                TableColumn("Actions") { row in
                    Button("Details") { detail = row }
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .onAppear { vm.load(db: dbManager) }
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .sheet(item: $detail) { item in
            ImportSessionDetailView(session: item.data)
        }
    }
}

private struct ImportSessionDetailView: View {
    var session: DatabaseManager.ImportSessionData
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                detailRow("Session Name", session.sessionName)
                detailRow("File Name", session.fileName)
                if let path = session.filePath { detailRow("File Path", path) }
                detailRow("File Type", session.fileType)
                detailRow("File Size", String(session.fileSize))
                if let hash = session.fileHash { detailRow("File Hash", hash) }
                if let id = session.institutionId { detailRow("Institution ID", String(id)) }
                detailRow("Status", session.importStatus)
                detailRow("Total Rows", String(session.totalRows))
                detailRow("Successful Rows", String(session.successfulRows))
                detailRow("Failed Rows", String(session.failedRows))
                detailRow("Duplicate Rows", String(session.duplicateRows))
                if let log = session.errorLog { detailRow("Error Log", log) }
                if let notes = session.processingNotes { detailRow("Notes", notes) }
                detailRow("Created", DateFormatter.iso8601DateTime.string(from: session.createdAt))
                if let s = session.startedAt { detailRow("Started", DateFormatter.iso8601DateTime.string(from: s)) }
                if let c = session.completedAt { detailRow("Completed", DateFormatter.iso8601DateTime.string(from: c)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(width: 450, height: 500)
        .overlay(alignment: .topTrailing) {
            Button("Close") { dismiss() }
                .padding(8)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ImportSessionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ImportSessionHistoryView()
            .environmentObject(DatabaseManager())
    }
}
