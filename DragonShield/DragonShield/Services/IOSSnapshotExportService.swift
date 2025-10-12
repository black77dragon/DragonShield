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
        #if os(macOS)
        if let bookmarked = db.resolveIOSSnapshotBookmarkURL() {
            return bookmarked
        }
        #endif
        let path = db.iosSnapshotTargetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty { return defaultTargetFolder() }
        if path.hasPrefix("~/") {
            var p = path; p.removeFirst(2)
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(p)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func targetFileURL(for date: Date = Date(), in folder: URL? = nil) -> URL {
        // Always export to a consistent filename for easy iOS import
        let targetFolder = folder ?? resolvedTargetFolder()
        return targetFolder.appendingPathComponent("DragonShield_snapshot.sqlite")
    }

    private func resolvedTargetFolderWithSecurityScope() -> (url: URL, cleanup: (() -> Void)?) {
        #if os(macOS)
        if let access = db.beginIOSSnapshotTargetAccess() {
            let cleanup = {
                if access.needsStop { access.url.stopAccessingSecurityScopedResource() }
            }
            return (access.url, cleanup)
        }
        #endif
        let folder = resolvedTargetFolder()
        return (folder, nil)
    }

    func lastExportDate() -> Date? {
        let access = resolvedTargetFolderWithSecurityScope()
        defer { access.cleanup?() }
        let url = targetFileURL(in: access.url)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date { return modified }
        return nil
    }

    private func ensureFolderExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @discardableResult
    func exportNow(trigger: String = "manual") throws -> URL {
        let startedAt = Date()
        #if os(macOS)
        writeKanbanSnapshotIntoConfiguration()
        #endif
        let access = resolvedTargetFolderWithSecurityScope()
        defer { access.cleanup?() }
        let destFolder = access.url
        let fileURL = targetFileURL(in: destFolder)
        do {
            try ensureFolderExists(destFolder)
            try db.exportSnapshot(to: fileURL)
            let finishedAt = Date()
            let durationMs = max(Int(finishedAt.timeIntervalSince(startedAt) * 1000), 0)
            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let byteCount = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            let sizeString = byteCount > 0 ? formatter.string(fromByteCount: byteCount) : nil
            let messageBase = "Exported \(fileURL.lastPathComponent)" + (sizeString != nil ? " (\(sizeString!))" : "")
            let message = messageBase + " via \(trigger)"
            var metadata: [String: Any] = [
                "targetPath": destFolder.path,
                "filename": fileURL.lastPathComponent,
                "trigger": trigger
            ]
            if byteCount > 0 { metadata["bytes"] = byteCount }
            _ = db.recordSystemJobRun(jobKey: .iosSnapshotExport,
                                      status: .success,
                                      message: message,
                                      metadata: metadata,
                                      startedAt: startedAt,
                                      finishedAt: finishedAt,
                                      durationMs: durationMs)
            return fileURL
        } catch {
            #if os(macOS)
            let nsError = error as NSError
            let adjustedError: Error
            if nsError.domain == NSCocoaErrorDomain,
               nsError.code == NSFileWriteNoPermissionError,
               db.iosSnapshotTargetBookmark == nil {
                let advice = "macOS sandbox blocked access to \(destFolder.path). Use Select Path to authorise the folder and try again."
                adjustedError = NSError(domain: nsError.domain,
                                        code: nsError.code,
                                        userInfo: [NSLocalizedDescriptionKey: advice])
            } else {
                adjustedError = error
            }
            #else
            let adjustedError = error
            #endif
            let finishedAt = Date()
            let durationMs = max(Int(finishedAt.timeIntervalSince(startedAt) * 1000), 0)
            let metadata: [String: Any] = [
                "targetPath": destFolder.path,
                "filename": fileURL.lastPathComponent,
                "trigger": trigger
            ]
            let message = "Export failed: \(adjustedError.localizedDescription) via \(trigger)"
            _ = db.recordSystemJobRun(jobKey: .iosSnapshotExport,
                                      status: .failed,
                                      message: message,
                                      metadata: metadata,
                                      startedAt: startedAt,
                                      finishedAt: finishedAt,
                                      durationMs: durationMs)
            throw adjustedError
        }
    }

    #if os(macOS)
    private func writeKanbanSnapshotIntoConfiguration() {
        let defaults = UserDefaults.standard
        let todos: [KanbanTodo]
        if let data = defaults.data(forKey: UserDefaultsKeys.kanbanTodos),
           let decoded = KanbanSnapshotCodec.decode(data: data) {
            todos = decoded
        } else {
            todos = []
        }
        let json = KanbanSnapshotCodec.encodeJSON(todos) ?? "[]"
        print("[iOS Snapshot] Preparing to persist \(todos.count) to-dos into snapshot configuration")
        _ = db.upsertConfiguration(key: KanbanSnapshotConfigurationKey,
                                   value: json,
                                   dataType: "string",
                                   description: "Kanban to-dos snapshot for iOS app")
    }
    #endif

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
                let url = try exportNow(trigger: "auto")
                LoggingService.shared.log("[iOS Snapshot] Exported to \(url.path)")
            } catch {
                LoggingService.shared.log("[iOS Snapshot] Export failed: \(error.localizedDescription)", type: .error)
            }
        } else {
            LoggingService.shared.log("[iOS Snapshot] Up to date; no export required today")
        }
    }
}
