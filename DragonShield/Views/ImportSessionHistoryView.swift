import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImportSessionHistoryView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var sessions: [DatabaseManager.ImportSessionData] = []
    @State private var totalValues: [Int: Double] = [:]
    @State private var selected: DatabaseManager.ImportSessionData? = nil
    @State private var detailItem: DatabaseManager.ImportSessionData? = nil
    @State private var showReport = false
    @State private var reportItems: [DatabaseManager.ImportSessionValueItem] = []
    @State private var reportTotal: Double = 0

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
                            rowPadding: CGFloat(dbManager.tableRowPadding)
                        ) {
                            selected = session
                        }
                        .onTapGesture(count: 2) {
                            selected = session
                            detailItem = session
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
        .sheet(item: $detailItem) { item in
            ImportSessionDetailView(session: item, totalValue: totalValues[item.id] ?? 0) {
                detailItem = nil
            }
            .environmentObject(dbManager)
        }
        .sheet(isPresented: $showReport) {
            ImportSessionValueReportView(items: reportItems, totalValue: reportTotal) {
                showReport = false
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
                Button("Show Details") { detailItem = selected }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(selected == nil)
                Button("Show Report") {
                    if let s = selected {
                        let items = dbManager.fetchValueReport(forSession: s.id)
                        reportItems = items
                        reportTotal = items.reduce(0) { $0 + $1.valueChf }
                        showReport = true
                    }
                }
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
    let onClose: () -> Void

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
            }
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
        .frame(minWidth: 400, minHeight: 400)
    }
}

private struct ImportSessionValueReportView: View {
    let items: [DatabaseManager.ImportSessionValueItem]
    let totalValue: Double
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Value Report")
                .font(.headline)
            Table(items) {
                TableColumn("Instrument") { Text($0.instrument).textSelection(.enabled) }
                TableColumn("Currency") { Text($0.currency).textSelection(.enabled) }
                TableColumn("Value") { item in Text(String(format: "%.2f", item.valueOrig)).textSelection(.enabled) }
                TableColumn("Value CHF") { item in Text(String(format: "%.2f", item.valueChf)).textSelection(.enabled) }
            }
            Text(
                "Total Value CHF: " + (ImportSessionHistoryView.chfFormatter.string(from: NSNumber(value: totalValue)) ?? "0")
            )
            .textSelection(.enabled)
            HStack {
                Button("Copy All") { copyAll() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Copy All")
                Button("Export…") { exportAll() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Export")
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
        .frame(minWidth: 800, minHeight: 560)
    }

    private func copyAll() {
        let string = ValueReportView.exportString(items: items, totalValue: totalValue)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    private func exportAll() {
        let string = ValueReportView.exportString(items: items, totalValue: totalValue)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType.plainText]
        panel.nameFieldStringValue = "ValueReport.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? string.data(using: .utf8)?.write(to: url)
        }
    }
}

#Preview {
    ImportSessionHistoryView()
        .environmentObject(DatabaseManager())
}
