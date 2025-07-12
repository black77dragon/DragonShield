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
    @State private var errorMessage: String?

    private var metadataView: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                Text("Database Path:")
                Text(dbManager.dbFilePath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.caption)
            }
            GridRow {
                Text("File Size:")
                Text(fileSizeString)
            }
            GridRow {
                Text("Schema Version:")
                Text(dbManager.dbVersion)
            }
            GridRow {
                Text("Backup Directory:")
                HStack {
                    Text(backupService.backupDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                    Button("Change…") { chooseBackupDirectory() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var fullDatabaseGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Database")
                .font(.headline)
            HStack(spacing: 12) {
                Button(action: backupNow) {
                    if processing { ProgressView() } else { Text("Backup Database") }
                }
                .keyboardShortcut("b", modifiers: [.command])
                .buttonStyle(PrimaryButtonStyle())
                .disabled(processing)
                .help("Create a backup copy of the current database")

                Button("Restore Database") { showingFileImporter = true }
                    .keyboardShortcut("r", modifiers: [.command])
                    .buttonStyle(SecondaryButtonStyle())
                    .help("Replace current database with a backup file")
            }
            Text("Last Full Backup: \(formattedDate(backupService.lastBackup))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var referenceGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reference Data")
                .font(.headline)
            HStack(spacing: 12) {
                Button(action: backupReferenceNow) {
                    if processing { ProgressView() } else { Text("Backup Reference") }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(processing)
                .help("Export reference tables to a SQL file")

                Button("Restore Reference") { showingReferenceImporter = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .help("Apply a reference data backup to the current database")
            }
            Text("Last Reference Backup: \(formattedDate(backupService.lastReferenceBackup))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var transitionGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transition Data")
                .font(.headline)
            HStack(spacing: 12) {
                Button("Backup Transition") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
                Button("Restore Transition") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(true)
            }
        }
    }

    private var logList: some View {
        let entries = Array(backupService.logMessages.prefix(10))
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(entries, id: \.self) { entry in
                Text(entry)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var logView: some View {
        ScrollView {
            logList
        }
        .frame(maxHeight: 200)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.2))
        )
    }

    private var managementContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Database Management")
                .font(.system(size: 18, weight: .semibold))

            metadataView

            fullDatabaseGroup
            referenceGroup
            transitionGroup

            HStack(spacing: 12) {
                Button("Switch Mode") { confirmSwitchMode() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Migrate Database") { migrateDatabase() }
                    .buttonStyle(SecondaryButtonStyle())
            }

            logView
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .padding()
    }

    var body: some View {
        managementContent
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "db")!]
            ) { result in
                switch result {
                case .success(let url):
                    restoreURL = url
                    showRestoreConfirm = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showingReferenceImporter,
                allowedContentTypes: [UTType(filenameExtension: "sql")!]
            ) { result in
                switch result {
                case .success(let url):
                    restoreReferenceURL = url
                    showReferenceRestoreConfirm = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .init("PerformDatabaseBackup"))) { _ in
                backupNow()
            }
    }

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
                _ = try backupService.performBackup(dbPath: dbManager.dbFilePath, to: url)
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
                _ = try backupService.performReferenceBackup(dbPath: dbManager.dbFilePath, to: url)
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
                try backupService.performRestore(dbManager: dbManager, from: url)
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
            do {
                try backupService.performReferenceRestore(dbManager: dbManager, from: url)
                DispatchQueue.main.async { processing = false }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func chooseBackupDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = backupService.backupDirectory
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try backupService.updateBackupDirectory(to: url)
            } catch {
                errorMessage = error.localizedDescription
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

    private func migrateDatabase() {
        processing = true
        DispatchQueue.global().async {
            dbManager.runMigrations()
            DispatchQueue.main.async { processing = false }
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: dbManager.dbFileSize, countStyle: .file)
    }

}

struct DatabaseManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseManagementView()
            .environmentObject(DatabaseManager())
    }
}
