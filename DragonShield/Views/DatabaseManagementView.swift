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
        }
    }

    private var actionsView: some View {
        HStack(spacing: 12) {
            Button(action: backupNow) {
                if processing { ProgressView() } else { Text("Backup Database") }
            }
            .keyboardShortcut("b", modifiers: [.command])
            .buttonStyle(PrimaryButtonStyle())
            .disabled(processing)
            .accessibilityLabel("Backup Database")
            .focusable()
            .help("Create a backup copy of the current database")

            Button("Restore from Backup") { showingFileImporter = true }
                .keyboardShortcut("r", modifiers: [.command])
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Restore from Backup")
                .focusable()

            Button("Switch Mode") { confirmSwitchMode() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Switch Mode")
                .focusable()

            Button("Migrate Database") { migrateDatabase() }
                .keyboardShortcut("m", modifiers: [.command])
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Migrate Database")
                .focusable()
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

            actionsView

            Text("Last Backup: \(formattedDate(backupService.lastBackup))")
                .font(.caption)
                .foregroundColor(.secondary)
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
            .onReceive(NotificationCenter.default.publisher(for: .init("PerformDatabaseBackup"))) { _ in
                backupNow()
            }
    }

    private func backupNow() {
        processing = true
        DispatchQueue.global().async {
            do {
                _ = try backupService.performBackup(dbPath: dbManager.dbFilePath)
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
