import SwiftUI

struct ImportSessionHistoryView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var sessions: [DatabaseManager.ImportSessionData] = []
    @State private var totalValues: [Int: Double] = [:]
    @State private var selected: DatabaseManager.ImportSessionData? = nil
    @State private var showDetails = false

    static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CHF"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
            ScrollView {
                LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                    ForEach(sessions) { session in
                        ImportSessionRowView(
                            session: session,
                            totalValue: totalValues[session.id] ?? 0,
                            isSelected: selected?.id == session.id,
                            rowPadding: CGFloat(dbManager.tableRowPadding)) {
                                selected = session
                            }
                            .onTapGesture(count: 2) {
                                selected = session
                                showDetails = true
                            }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

            actionBar
        }
        .padding()
        .onAppear { loadSessions() }
        .sheet(isPresented: $showDetails) {
            if let s = selected {
                ImportSessionDetailView(session: s, totalValue: totalValues[s.id] ?? 0)
                    .environmentObject(dbManager)
            }
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("Import Date").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 120, alignment: .leading)
            Text("Session Name").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .leading)
            Text("Total").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 60, alignment: .trailing)
            Text("Success").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 60, alignment: .trailing)
            Text("Failed").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 60, alignment: .trailing)
            Text("Value CHF").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        .padding(.bottom, 1)
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
            HStack {
                Button("Show Details") { showDetails = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(selected == nil)
                Spacer()
                if let s = selected {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                        Text("Selected: \(s.sessionName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
    }

    private func loadSessions() {
        DispatchQueue.global().async {
            let list = dbManager.fetchImportSessions()
            var values: [Int: Double] = [:]
            for s in list {
                values[s.id] = dbManager.totalReportValueForSession(s.id)
            }
            DispatchQueue.main.async {
                self.sessions = list
                self.totalValues = values
            }
        }
    }
}

private struct ImportSessionRowView: View {
    let session: DatabaseManager.ImportSessionData
    let totalValue: Double
    let isSelected: Bool
    let rowPadding: CGFloat
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(session.createdAt, style: .date)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 120, alignment: .leading)
            Text(session.sessionName)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(session.importStatus)
                .font(.system(size: 13))
                .frame(width: 80, alignment: .leading)
            Text("\(session.totalRows)")
                .font(.system(size: 13))
                .frame(width: 60, alignment: .trailing)
            Text("\(session.successfulRows)")
                .font(.system(size: 13))
                .frame(width: 60, alignment: .trailing)
            Text("\(session.failedRows)")
                .font(.system(size: 13))
                .frame(width: 60, alignment: .trailing)
            Text(ImportSessionHistoryView.chfFormatter.string(from: NSNumber(value: totalValue)) ?? "0")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

private struct ImportSessionDetailView: View {
    let session: DatabaseManager.ImportSessionData
    let totalValue: Double
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) var dismiss
    @State private var valueItems: [DatabaseManager.SessionValueItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Details")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ID: \(session.id)")
                    Text("Name: \(session.sessionName)")
                    Text("File: \(session.fileName)")
                    Text("Type: \(session.fileType)")
                    Text("Size: \(session.fileSize)")
                    Text("Hash: \(session.fileHash)")
                    Text("Institution ID: \(session.institutionId.map { String($0) } ?? "-")")
                    Text("Status: \(session.importStatus)")
                    Text("Total Rows: \(session.totalRows)")
                    Text("Successful Rows: \(session.successfulRows)")
                    Text("Failed Rows: \(session.failedRows)")
                    Text("Duplicate Rows: \(session.duplicateRows)")
                    if let err = session.errorLog { Text("Error: \(err)") }
                    if let note = session.processingNotes { Text("Notes: \(note)") }
                    Text("Created: \(session.createdAt.formatted())")
                    if let s = session.startedAt { Text("Started: \(s.formatted())") }
                    if let c = session.completedAt { Text("Completed: \(c.formatted())") }
                    Text("Total Value CHF: " + (ImportSessionHistoryView.chfFormatter.string(from: NSNumber(value: totalValue)) ?? "0"))
                }
                if !valueItems.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Value Report")
                            .font(.subheadline)
                            .padding(.bottom, 2)
                        ForEach(valueItems) { item in
                            Text(String(format: "%@ - %.2f %@ -> %.2f CHF", item.instrumentName, item.valueOrig, item.currency, item.valueChf))
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 400)
        .onAppear { valueItems = dbManager.fetchSessionValues(sessionId: session.id) }
    }
}

#Preview {
    ImportSessionHistoryView()
        .environmentObject(DatabaseManager())
}
