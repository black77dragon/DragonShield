import Foundation

final class IOSSnapshotExportService {
    private let db: DatabaseManager

    init(dbManager: DatabaseManager) { self.db = dbManager }

    /// Hard default requested by user for robust persistence
    static let defaultAbsolutePath = "/Users/renekeller/Library/Mobile Documents/com~apple~CloudDocs/003 ➡️ transfer/000 DragonShield iphone app"

    func defaultTargetFolder() -> URL {
        // Use explicit absolute default as requested
        return URL(fileURLWithPath: Self.defaultAbsolutePath, isDirectory: true)
    }

    func resolvedTargetFolder() -> URL {
        let path = db.iosSnapshotTargetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty {
            // Persist robust default immediately when no config exists
            let def = defaultTargetFolder()
            _ = db.upsertConfiguration(key: "ios_snapshot_target_path", value: def.path, dataType: "string", description: "Destination folder for iOS snapshot export")
            return def
        }
        if path.hasPrefix("~/") {
            var p = path; p.removeFirst(2)
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(p)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func targetFileURL(for date: Date = Date()) -> URL {
        // Always export to a consistent filename for easy iOS import
        let folder = resolvedTargetFolder()
        return folder.appendingPathComponent("DragonShield_snapshot.sqlite")
    }

    /// Returns the last export date recorded (Configuration),
    /// falls back to file modification date if config is missing.
    func lastExportDate() -> Date? {
        if let s = db.fetchConfigurationValue(key: "ios_snapshot_last_export_at"),
           let d = DateFormatter.iso8601DateTime.date(from: s) {
            return d
        }
        let url = targetFileURL()
        if FileManager.default.fileExists(atPath: url.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date { return modified }
        return nil
    }

    private func recordLastExport(now: Date = Date()) {
        let ts = DateFormatter.iso8601DateTime.string(from: now)
        _ = db.upsertConfiguration(key: "ios_snapshot_last_export_at", value: ts, dataType: "date", description: "Last iOS snapshot export timestamp (UTC)")
    }

    private func ensureFolderExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @discardableResult
    func exportNow() throws -> URL {
        let destFolder = resolvedTargetFolder()
        try ensureFolderExists(destFolder)
        let fileURL = targetFileURL()
        try db.exportSnapshot(to: fileURL)
        recordLastExport()
        // Persist the resolved destination path so it survives restarts
        _ = db.upsertConfiguration(key: "ios_snapshot_target_path", value: destFolder.path, dataType: "string", description: "Destination folder for iOS snapshot export")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("IOSSnapshotExported"), object: nil, userInfo: [
                "path": fileURL.path,
                "at": Date()
            ])
        }
        return fileURL
    }

    func isDueToday(frequency: String) -> Bool {
        let freq = frequency.lowercased()
        let cal = Calendar.current
        if let last = lastExportDate() {
            if freq == "weekly" {
                // Due if last < start of this week
                let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                return last < startOfWeek
            }
            // daily: due if last not on the same day as today
            return !cal.isDate(last, inSameDayAs: Date())
        }
        return true
    }

    func autoExportOnLaunchIfDue() {
        guard db.iosSnapshotAutoEnabled else { return }
        // Ensure destination path is persisted even if not exporting this run
        let pathToPersist = resolvedTargetFolder().path
        _ = db.upsertConfiguration(key: "ios_snapshot_target_path", value: pathToPersist, dataType: "string", description: "Destination folder for iOS snapshot export")
        if isDueToday(frequency: db.iosSnapshotFrequency) {
            do {
                let url = try exportNow()
                LoggingService.shared.log("[iOS Snapshot] Exported to \(url.path)")
            } catch {
                LoggingService.shared.log("[iOS Snapshot] Export failed: \(error.localizedDescription)", type: .error)
            }
        } else {
            LoggingService.shared.log("[iOS Snapshot] Up to date; no export required today")
        }
    }
}
