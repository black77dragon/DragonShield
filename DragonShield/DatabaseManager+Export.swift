import Foundation
import OSLog
import SQLite3
#if os(macOS)
    import AppKit
    import UniformTypeIdentifiers
#endif

extension DatabaseManager {
    /// Creates a consistent, single-file snapshot of the current database using sqlite3_backup.
    /// - Parameter url: Destination file URL (will be overwritten if exists).
    /// - Throws: Error if backup fails at any step.
    func exportSnapshot(to url: URL) throws {
        guard let src = db else { throw NSError(domain: "DragonShield", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not open"]) }

        // Remove any existing file at destination
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        var dst: OpaquePointer? = nil
        // Open a brand-new destination database file
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &dst, flags, nil) != SQLITE_OK {
            let msg = dst != nil ? String(cString: sqlite3_errmsg(dst)) : "unknown"
            if let d = dst { sqlite3_close_v2(d) }
            throw NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open destination: \(msg)"])
        }
        defer { if let d = dst { sqlite3_close_v2(d) } }

        // Do the backup from the main database
        guard let backup = sqlite3_backup_init(dst, "main", src, "main") else {
            let msg = String(cString: sqlite3_errmsg(dst))
            throw NSError(domain: "SQLite", code: 3, userInfo: [NSLocalizedDescriptionKey: "backup_init failed: \(msg)"])
        }
        defer { sqlite3_backup_finish(backup) }

        // Copy all pages (-1 = all)
        let stepRc = sqlite3_backup_step(backup, -1)
        if stepRc != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(dst))
            throw NSError(domain: "SQLite", code: 4, userInfo: [NSLocalizedDescriptionKey: "backup_step failed rc=\(stepRc): \(msg)"])
        }

        // Ensure destination DB is fully written to disk
        sqlite3_exec(dst, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
    }

    #if os(macOS)
        /// Convenience UI to export a snapshot using NSSavePanel with sane defaults
        func presentExportSnapshotPanel() {
            let panel = NSSavePanel()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmm"
            let ts = formatter.string(from: Date())
            panel.nameFieldStringValue = "DragonShield_\(ts).sqlite"
            if #available(macOS 12.0, *) {
                panel.allowedContentTypes = [UTType(filenameExtension: "sqlite") ?? .data]
            } else {
                panel.allowedFileTypes = ["sqlite"]
            }
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.level = .modalPanel
            panel.message = "Choose where to save a read-only snapshot for the iOS app."
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try exportSnapshot(to: url)
                    LoggingService.shared.log("Exported snapshot to \(url.path)", logger: .ui)
                } catch {
                    LoggingService.shared.log("Export snapshot failed: \(error.localizedDescription)", type: .error, logger: .ui)
                }
            }
        }
    #endif
}

#if os(macOS)
    extension DatabaseManager {
        /// Store the destination folder path and capture a security-scoped bookmark for later use.
        @discardableResult
        func setIOSSnapshotTargetFolder(_ url: URL) -> Bool {
            let path = url.path
            preferences.iosSnapshotTargetPath = path
            _ = configurationStore.upsertConfiguration(key: "ios_snapshot_target_path", value: path, dataType: "string", description: "Destination folder for iOS snapshot export")
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                preferences.iosSnapshotTargetBookmark = bookmark
                let encoded = bookmark.base64EncodedString()
                _ = configurationStore.upsertConfiguration(key: "ios_snapshot_target_bookmark", value: encoded, dataType: "data", description: "Security-scoped bookmark for iOS snapshot export folder")
                return true
            } catch {
                preferences.iosSnapshotTargetBookmark = nil
                _ = configurationStore.upsertConfiguration(key: "ios_snapshot_target_bookmark", value: "", dataType: "data", description: "Security-scoped bookmark for iOS snapshot export folder")
                print("⚠️ [iOS Snapshot] Failed to create bookmark: \(error.localizedDescription)")
                return false
            }
        }

        /// Resolve the stored bookmark into a URL, refreshing the bookmark if needed.
        func resolveIOSSnapshotBookmarkURL() -> URL? {
            guard let data = preferences.iosSnapshotTargetBookmark else { return nil }
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
                if stale {
                    do {
                        let refreshed = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        preferences.iosSnapshotTargetBookmark = refreshed
                        let encoded = refreshed.base64EncodedString()
                        _ = configurationStore.upsertConfiguration(key: "ios_snapshot_target_bookmark", value: encoded, dataType: "data", description: "Security-scoped bookmark for iOS snapshot export folder")
                    } catch {
                        print("⚠️ [iOS Snapshot] Failed to refresh stale bookmark: \(error.localizedDescription)")
                    }
                }
                return url
            } catch {
                print("⚠️ [iOS Snapshot] Failed to resolve bookmark: \(error.localizedDescription)")
                return nil
            }
        }

        /// Begin security-scoped access to the bookmarked destination directory if available.
        func beginIOSSnapshotTargetAccess() -> (url: URL, needsStop: Bool)? {
            guard let url = resolveIOSSnapshotBookmarkURL() else { return nil }
            let granted = url.startAccessingSecurityScopedResource()
            if !granted {
                print("⚠️ [iOS Snapshot] startAccessingSecurityScopedResource returned false for \(url.path)")
            }
            return (url, granted)
        }

        /// Clear any cached bookmark when the user manually edits the destination path.
        func clearIOSSnapshotBookmark() {
            preferences.iosSnapshotTargetBookmark = nil
            _ = configurationStore.upsertConfiguration(key: "ios_snapshot_target_bookmark", value: "", dataType: "data", description: "Security-scoped bookmark for iOS snapshot export folder")
        }
    }
#endif
