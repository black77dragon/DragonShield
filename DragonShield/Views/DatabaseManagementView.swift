import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DatabaseManagementView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var backupService = BackupService()

    @State private var processing = false
    @State private var showingFileImporter = false
    @State private var restoreURL: URL?
    @State private var showRestoreConfirm = false
    @State private var showingReferenceImporter = false
    @State private var restoreReferenceURL: URL?
    @State private var showReferenceRestoreConfirm = false
    @State private var showingTransactionImporter = false
    @State private var restoreTransactionURL: URL?
    @State private var showTransactionRestoreConfirm = false
    @State private var errorMessage: String?
    @State private var showLogDetails = false
    @State private var showReferenceInfo = false
    @State private var reportProcessing = false
    @State private var showTxnBackupSheet = false
    @State private var showTxnRestoreSheet = false
    @State private var backupTxnTables: Set<String> = []
    @State private var restoreTxnTables: Set<String> = []

    private let reportService = InstrumentReportService()

    // MARK: - Info Card
    private func infoRow(_ label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(mono ? .system(.body, design: .monospaced) : .system(size: 13))
                .multilineTextAlignment(.trailing)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Database Information")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.primaryAccent)

            infoRow("Database Path:", value: dbManager.dbFilePath, mono: true)
            infoRow("File Size:", value: fileSizeString, mono: true)
            infoRow("Schema Version:", value: dbManager.dbVersion)
            infoRow("Created:", value: formattedDate(dbManager.dbCreated))
            infoRow("Last Updated:", value: formattedDate(dbManager.dbModified))
            infoRow("Mode:", value: dbManager.dbMode.rawValue.uppercased())
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    // MARK: - Backup & Restore Actions
    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup & Restore")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.primaryAccent)

            VStack(alignment: .leading, spacing: 8) {
                Text("Full Database")
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 12) {
                    Button(action: backupNow) {
                        if processing { ProgressView() } else { Text("Backup Database") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(processing)

                    Button("Restore Database") { showingFileImporter = true }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(processing)
                        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType(filenameExtension: "db")!]) { result in
                            switch result {
                            case .success(let url):
                                restoreURL = url
                                showRestoreConfirm = true
                            case .failure(let error):
                                errorMessage = error.localizedDescription
                            }
                        }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Reference Data")
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .onHover { showReferenceInfo = $0 }
                        .popover(isPresented: $showReferenceInfo, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(backupService.referenceTables, id: \.self) { table in
                                    Text("\u{2022} \(table)")
                                }
                            }
                            .padding(8)
                            .onHover { showReferenceInfo = $0 }
                        }
                }
                HStack(spacing: 12) {
                    Button(action: backupReferenceNow) {
                        if processing { ProgressView() } else { Text("Backup Reference Data") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(processing)

                    Button("Restore Reference Data") { showingReferenceImporter = true }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(processing)
                        .fileImporter(isPresented: $showingReferenceImporter, allowedContentTypes: [UTType(filenameExtension: "sql")!]) { result in
                            switch result {
                            case .success(let url):
                                restoreReferenceURL = url
                                showReferenceRestoreConfirm = true
                            case .failure(let error):
                                errorMessage = error.localizedDescription
                            }
                        }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Data")
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 12) {
                    Button(action: backupTransactionNow) {
                        if processing { ProgressView() } else { Text("Backup Transaction Data") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(processing)

                    Button("Restore Transaction Data") { showingTransactionImporter = true }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(processing)
                        .fileImporter(isPresented: $showingTransactionImporter, allowedContentTypes: [UTType(filenameExtension: "sql")!]) { result in
                            switch result {
                            case .success(let url):
                                restoreTransactionURL = url
                                restoreTxnTables = Set(backupService.transactionTables)
                                showTxnRestoreSheet = true
                            case .failure(let error):
                                errorMessage = error.localizedDescription
                            }
                        }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reports")
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 12) {
                    Button(action: generateInstrumentReport) {
                        if reportProcessing { ProgressView() } else { Text("Generate Full Instrument Report") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(reportProcessing)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Environment")
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 12) {
                    Button("Switch to \(dbManager.dbMode == .production ? "Test" : "Production")") {
                        confirmSwitchMode()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(processing)
                }
            }
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    // MARK: - Log Card
    private var summaryTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Table Name").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                Text("Action").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                Text("Records Processed").font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
            }
            ForEach(Array(backupService.lastActionSummaries.enumerated()), id: \..offset) { index, entry in
                HStack {
                    Text(entry.table)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(entry.action)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(entry.count)")
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 2)
                .background(index % 2 == 0 ? Color.gray.opacity(0.05) : Color.clear)
            }
        }
    }

    private var logList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(backupService.logMessages.enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var validationList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(backupService.lastValidationMessages.enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup & Restore Log")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.primaryAccent)

            if !backupService.lastActionSummaries.isEmpty {
                summaryTable
            }
            if !backupService.lastValidationMessages.isEmpty {
                validationList
            }

            Button(showLogDetails ? "Hide Details" : "Show Details") {
                withAnimation { showLogDetails.toggle() }
            }
            .font(.system(size: 12, weight: .medium))

            if showLogDetails {
                ScrollView { logList }
                    .frame(minHeight: 200)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
        )
        .overlay(
            Rectangle()
                .fill(Theme.primaryAccent)
                .frame(height: 2), alignment: .top
        )
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    // MARK: - Layout
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoCard
                actionsCard
                logCard
            }
            .padding(32)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown Error")
        }
        .alert("Restore Database", isPresented: $showRestoreConfirm) {
            Button("Restore", role: .destructive) {
                if let url = restoreURL { restoreDatabase(url: url) }
            }
            Button("Cancel", role: .cancel) { restoreURL = nil }
        } message: {
            Text("Are you sure you want to replace your current database with '\(restoreURL?.lastPathComponent ?? "")'?\nThis action cannot be undone without another backup.")
        }
        .alert("Restore Reference", isPresented: $showReferenceRestoreConfirm) {
            Button("Restore", role: .destructive) {
                if let url = restoreReferenceURL { restoreReference(url: url) }
            }
            Button("Cancel", role: .cancel) { restoreReferenceURL = nil }
        } message: {
            Text("Import reference data from '\(restoreReferenceURL?.lastPathComponent ?? "")'? This will overwrite existing reference tables.")
        }
        .alert("Restore Transaction Data", isPresented: $showTransactionRestoreConfirm) {
            Button("Restore", role: .destructive) {
                if let url = restoreTransactionURL { restoreTransaction(url: url) }
            }
            Button("Cancel", role: .cancel) { restoreTransactionURL = nil }
        } message: {
            Text("Import transaction data from '\(restoreTransactionURL?.lastPathComponent ?? "")'? This will overwrite existing tables.")
        }
        .sheet(isPresented: $showTxnBackupSheet) {
            TableSelectionSheet(
                title: "Select Tables",
                tables: backupService.transactionTables,
                selection: $backupTxnTables,
                onConfirm: {
                    showTxnBackupSheet = false
                    performTransactionBackup()
                },
                onCancel: { showTxnBackupSheet = false }
            )
        }
        .sheet(isPresented: $showTxnRestoreSheet) {
            TableSelectionSheet(
                title: "Select Tables",
                tables: backupService.transactionTables,
                selection: $restoreTxnTables,
                onConfirm: {
                    showTxnRestoreSheet = false
                    showTransactionRestoreConfirm = true
                },
                onCancel: { showTxnRestoreSheet = false }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("PerformDatabaseBackup"))) { _ in
            backupNow()
        }
    }

    // MARK: - Actions
    private func backupNow() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        if #available(macOS 12.0, *) {
            if let dbType = UTType(filenameExtension: "db") {
                panel.allowedContentTypes = [dbType]
            }
        } else {
            panel.allowedFileTypes = ["db"]
        }
        let refDir = backupService.backupDirectory.appendingPathComponent("Reference", isDirectory: true)
        try? FileManager.default.createDirectory(at: refDir, withIntermediateDirectories: true)
        panel.directoryURL = refDir
        panel.nameFieldStringValue = BackupService.defaultFileName(
            mode: dbManager.dbMode,
            version: dbManager.dbVersion
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        processing = true
        DispatchQueue.global().async {
            do {
                try? backupService.updateBackupDirectory(to: url.deletingLastPathComponent())
                _ = try backupService.performBackup(dbManager: dbManager, dbPath: dbManager.dbFilePath, to: url, tables: backupService.fullTables, label: "Full")
                DispatchQueue.main.async { processing = false }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func backupReferenceNow() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        if #available(macOS 12.0, *) {
            if let sqlType = UTType(filenameExtension: "sql") {
                panel.allowedContentTypes = [sqlType]
            }
        } else {
            panel.allowedFileTypes = ["sql"]
        }
        panel.directoryURL = backupService.backupDirectory
        panel.nameFieldStringValue = BackupService.defaultReferenceFileName(
            mode: dbManager.dbMode,
            version: dbManager.dbVersion
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        processing = true
        DispatchQueue.global().async {
            do {
                try? backupService.updateBackupDirectory(to: url.deletingLastPathComponent())
                _ = try backupService.backupReferenceData(dbManager: dbManager, to: url)
                DispatchQueue.main.async { processing = false }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func backupTransactionNow() {
        backupTxnTables = Set(backupService.transactionTables)
        showTxnBackupSheet = true
    }

    private func performTransactionBackup() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        if #available(macOS 12.0, *) {
            if let sqlType = UTType(filenameExtension: "sql") {
                panel.allowedContentTypes = [sqlType]
            }
        } else {
            panel.allowedFileTypes = ["sql"]
        }
        panel.directoryURL = backupService.backupDirectory
        panel.nameFieldStringValue = BackupService.defaultTransactionFileName(
            mode: dbManager.dbMode,
            version: dbManager.dbVersion
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        processing = true
        DispatchQueue.global().async {
            do {
                try? backupService.updateBackupDirectory(to: url.deletingLastPathComponent())
                _ = try backupService.backupTransactionData(
                    dbManager: dbManager,
                    to: url,
                    tables: Array(backupTxnTables)
                )
                DispatchQueue.main.async { processing = false }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restoreDatabase(url: URL) {
        processing = true
        DispatchQueue.global().async {
            do {
                try backupService.performRestore(dbManager: dbManager, from: url, tables: backupService.fullTables, label: "Full")
                DispatchQueue.main.async { processing = false }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restoreReference(url: URL) {
        processing = true
        DispatchQueue.global().async {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            do {
                try backupService.restoreReferenceData(dbManager: dbManager, from: url)
                DispatchQueue.main.async { processing = false }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restoreTransaction(url: URL) {
        processing = true
        DispatchQueue.global().async {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            do {
                try backupService.restoreTransactionData(
                    dbManager: dbManager,
                    from: url,
                    tables: Array(restoreTxnTables)
                )
                DispatchQueue.main.async { processing = false }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func generateInstrumentReport() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        if #available(macOS 12.0, *) {
            if let xlsxType = UTType(filenameExtension: "xlsx") { panel.allowedContentTypes = [xlsxType] }
        } else {
            panel.allowedFileTypes = ["xlsx"]
        }
        panel.nameFieldStringValue = "instrument_report.xlsx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        reportProcessing = true
        appendReportLog("Generating full instrument report…")
        DispatchQueue.global().async {
            do {
                try reportService.generateReport(outputPath: url.path)
                DispatchQueue.main.async {
                    reportProcessing = false
                    appendReportLog("Report saved to \(url.path)")
                }
            } catch {
                DispatchQueue.main.async {
                    reportProcessing = false
                    appendReportLog("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func confirmSwitchMode() {
        let newMode = dbManager.dbMode == .production ? "TEST" : "PRODUCTION"
        let alert = NSAlert()
        alert.messageText = "Switch to \(newMode) mode? Unsaved data may be lost."
        alert.addButton(withTitle: "Switch")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            dbManager.switchMode()
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: dbManager.dbFileSize, countStyle: .file)
    }

    private func appendReportLog(_ message: String) {
        backupService.logMessages.insert(message, at: 0)
        if backupService.logMessages.count > 10 {
            backupService.logMessages = Array(backupService.logMessages.prefix(10))
        }
    }
}

struct DatabaseManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseManagementView()
            .environmentObject(DatabaseManager())
    }
}

struct TableSelectionSheet: View {
    let title: String
    let tables: [String]
    @Binding var selection: Set<String>
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(tables, id: \..self) { tbl in
                Toggle(tbl, isOn: Binding(
                    get: { selection.contains(tbl) },
                    set: { val in
                        if val { selection.insert(tbl) } else { selection.remove(tbl) }
                    }
                ))
            }
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("OK") { onConfirm() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
