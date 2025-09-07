import Foundation

final class IOSSnapshotExportService {
    private let db: DatabaseManager

    init(dbManager: DatabaseManager) { self.db = dbManager }

    func defaultTargetFolder() -> URL {
        // ~/Library/Mobile Documents/com~apple~CloudDocs/003 ➡️ transfer/000 DragonShield iphone app
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            .appendingPathComponent("003 ➡️ transfer/000 DragonShield iphone app")
    }

    func resolvedTargetFolder() -> URL {
        let path = db.iosSnapshotTargetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty { return defaultTargetFolder() }
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

    func lastExportDate() -> Date? {
        let url = targetFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date { return modified }
        return nil
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
