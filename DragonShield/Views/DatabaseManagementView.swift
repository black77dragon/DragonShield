import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct ValidationStatusBanner {
    enum Level { case info, success, warning, error }
    let level: Level
    let title: String
    let detail: String
}

struct DatabaseManagementView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences
    @StateObject private var backupService = BackupService()

    @State private var processing = false
    @State private var showingFileImporter = false
    @State private var restoreURL: URL?
    @State private var showRestoreConfirm = false
    @State private var errorMessage: String?
    @State private var showLogDetails = true
    @State private var showReferenceInfo = false
    @State private var validationProcessing = false
    @State private var validationStatus: ValidationStatusBanner?
    @State private var backupStatus: ValidationStatusBanner?
    @State private var showRestoreComparison = false
    @State private var restoreDeltas: [RestoreDelta] = []

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
            infoRow("Schema Version:", value: preferences.dbVersion)
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
                if let status = backupStatus {
                    validationStatusBanner(status)
                }
                HStack(spacing: 12) {
                    Button(action: backupNow) {
                        if processing { ProgressView() } else { Text("Backup Database") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(processing)

                    Button("Restore Database") { showingFileImporter = true }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(processing)
                        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [UTType(filenameExtension: "sqlite")!, UTType(filenameExtension: "db")!]) { result in
                            switch result {
                            case let .success(url):
                                restoreURL = url
                                showRestoreConfirm = true
                            case let .failure(error):
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
                    Button("Backup Reference Data") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(true)
                        .opacity(0.5)

                    Button("Restore Reference Data") {}
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(true)
                        .opacity(0.5)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Data")
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 12) {
                    Button("Backup Transaction Data") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(true)
                        .opacity(0.5)

                    Button("Restore Transaction Data") {}
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(true)
                        .opacity(0.5)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reports")
                    .font(.system(size: 14, weight: .medium))
                HStack(spacing: 12) {
                    Button("Generate Full Instrument Report") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(true)
                        .opacity(0.5)
                        .help("Script needs to be fixed")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Validation")
                    .font(.system(size: 14, weight: .medium))
                Text("Run integrity checks on instrument data to catch duplicates, broken links, and invalid references before you back up or restore.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if let status = validationStatus {
                    validationStatusBanner(status)
                }
                HStack(spacing: 12) {
                    Button(action: validateInstruments) {
                        if validationProcessing { ProgressView() } else { Text("Validate Instruments") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(validationProcessing)
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

    private func validationStatusBanner(_ status: ValidationStatusBanner) -> some View {
        let style = validationStyle(for: status.level)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.icon)
                .foregroundColor(style.tint)
                .font(.system(size: 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(status.detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.background.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style.tint.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func validationStyle(for level: ValidationStatusBanner.Level) -> (tint: Color, background: Color, icon: String) {
        switch level {
        case .success:
            return (.green, .green, "checkmark.circle.fill")
        case .warning:
            return (.orange, .orange, "exclamationmark.triangle.fill")
        case .error:
            return (.red, .red, "xmark.octagon.fill")
        case .info:
            return (Theme.primaryAccent, Theme.primaryAccent, "info.circle.fill")
        }
    }

    // MARK: - Log Card

    private var summaryTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Table Name").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                Text("Action").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                Text("Records Processed").font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
            }
            ForEach(Array(backupService.lastActionSummaries.enumerated()), id: \.offset) { index, entry in
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

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup & Restore Log")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.primaryAccent)

            if !backupService.lastActionSummaries.isEmpty {
                summaryTable
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

        .sheet(isPresented: $showRestoreComparison) {
            RestoreComparisonView(rows: restoreDeltas) {
                showRestoreComparison = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("PerformDatabaseBackup"))) { _ in
            backupNow()
        }
    }

    // MARK: - Actions

    private func backupNow() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        if let dbType = UTType(filenameExtension: "db") {
            panel.allowedContentTypes = [dbType]
        }
        panel.directoryURL = backupService.backupDirectory
        panel.nameFieldStringValue = BackupService.defaultFileName(
            mode: dbManager.dbMode,
            version: preferences.dbVersion
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        processing = true
        backupStatus = ValidationStatusBanner(
            level: .info,
            title: "Running backup...",
            detail: "Saving the full database and validating the manifest."
        )

        // This is the block that was causing the "Trailing closure" error.
        // It's now fixed by calling the new, simpler `performBackup` function.
        DispatchQueue.global().async {
            do {
                try backupService.updateBackupDirectory(to: url.deletingLastPathComponent())
                // CHANGED: The function call is now much simpler.
                try backupService.performBackup(dbManager: dbManager, to: url)
                DispatchQueue.main.async {
                    processing = false
                    backupStatus = ValidationStatusBanner(
                        level: .success,
                        title: "Backup completed",
                        detail: "Saved \(url.lastPathComponent) — validation manifest created."
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                    backupStatus = ValidationStatusBanner(
                        level: .error,
                        title: "Backup failed",
                        detail: error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }
        }
    }

    private func restoreDatabase(url: URL) {
        processing = true
        DispatchQueue.global().async {
            do {
                // CHANGED: The function call is now simpler and matches the new BackupService.
                let result = try backupService.performRestore(dbManager: dbManager, from: url)
                DispatchQueue.main.async {
                    processing = false
                    restoreDeltas = result
                    showRestoreComparison = true
                }
            } catch {
                DispatchQueue.main.async {
                    processing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func validateInstruments() {
        validationProcessing = true
        validationStatus = ValidationStatusBanner(
            level: .info,
            title: "Running validation...",
            detail: "Checking instruments for duplicates and broken references. This may take a moment."
        )
        DispatchQueue.global().async {
            do {
                let result = try backupService.validateInstruments(dbManager: dbManager)
                DispatchQueue.main.async {
                    validationProcessing = false
                    let trimmedOutput = result.rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    backupService.logMessages.insert(trimmedOutput, at: 0)
                    validationStatus = buildValidationStatus(from: result)
                }
            } catch {
                DispatchQueue.main.async {
                    validationProcessing = false
                    let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    backupService.logMessages.insert("Error: \(message)", at: 0)
                    validationStatus = ValidationStatusBanner(
                        level: .error,
                        title: "Validation failed",
                        detail: message
                    )
                }
            }
        }
    }

    private func buildValidationStatus(from result: InstrumentValidationResult) -> ValidationStatusBanner {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        if let report = result.report {
            let totalChecked = report.summary?.totalRecords
            if report.hasCriticalIssues {
                let invalidCount = report.summary?.invalidRecords ?? report.totalIssues
                return ValidationStatusBanner(
                    level: .error,
                    title: "Validation found critical issues",
                    detail: "Detected \(invalidCount) invalid records. Review the log for details (\(timestamp))."
                )
            }

            if report.hasWarnings || report.totalIssues > 0 {
                return ValidationStatusBanner(
                    level: .warning,
                    title: "Validation completed with warnings",
                    detail: "\(report.totalIssues) issues flagged. Check the log for duplicates or missing links (\(timestamp))."
                )
            }

            if let totalChecked {
                return ValidationStatusBanner(
                    level: .success,
                    title: "Validation passed",
                    detail: "Checked \(totalChecked) instruments — no issues detected (\(timestamp))."
                )
            }

            return ValidationStatusBanner(
                level: .success,
                title: "Validation passed",
                detail: "No issues detected (\(timestamp))."
            )
        }

        if result.exitCode == 0 {
            return ValidationStatusBanner(
                level: .success,
                title: "Validation completed",
                detail: "Finished without structured report. See log for details (\(timestamp))."
            )
        }

        return ValidationStatusBanner(
            level: .error,
            title: "Validation failed",
            detail: "See log for details (\(timestamp))."
        )
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
}

struct DatabaseManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseManagementView()
            .environmentObject(DatabaseManager())
    }
}
