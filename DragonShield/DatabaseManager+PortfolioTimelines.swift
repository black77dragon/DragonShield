import Foundation
import OSLog
import SQLite3

extension DatabaseManager {
    func listPortfolioTimelines(includeInactive: Bool = true) -> [PortfolioTimelineRow] {
        PortfolioTimelineRepository(connection: databaseConnection).listPortfolioTimelines(includeInactive: includeInactive)
    }

    func listActivePortfolioTimelines() -> [PortfolioTimelineRow] {
        PortfolioTimelineRepository(connection: databaseConnection).listActive()
    }

    func createPortfolioTimeline(description: String, timeIndication: String, sortOrder: Int, active: Bool) -> PortfolioTimelineRow? {
        PortfolioTimelineRepository(connection: databaseConnection).createPortfolioTimeline(
            description: description,
            timeIndication: timeIndication,
            sortOrder: sortOrder,
            active: active
        )
    }

    func updatePortfolioTimeline(id: Int, description: String?, timeIndication: String?, sortOrder: Int?, active: Bool?) -> Bool {
        PortfolioTimelineRepository(connection: databaseConnection).updatePortfolioTimeline(
            id: id,
            description: description,
            timeIndication: timeIndication,
            sortOrder: sortOrder,
            active: active
        )
    }

    func deletePortfolioTimeline(id: Int) -> Bool {
        PortfolioTimelineRepository(connection: databaseConnection).deletePortfolioTimeline(id: id)
    }

    func reorderPortfolioTimelines(idsInOrder: [Int]) -> Bool {
        PortfolioTimelineRepository(connection: databaseConnection).reorderPortfolioTimelines(idsInOrder: idsInOrder)
    }

    func ensurePortfolioTimelinesTable() {
        guard let db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS PortfolioTimelines (
            id INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            time_indication TEXT NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
        );
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensurePortfolioTimelinesTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return
        }
        seedPortfolioTimelinesIfNeeded()
        ensureDefaultTimelineRow()
    }

    func defaultPortfolioTimelineId() -> Int? {
        guard let db else { return nil }
        var stmt: OpaquePointer?
        var result: Int?
        if sqlite3_prepare_v2(db, "SELECT id FROM PortfolioTimelines WHERE is_active = 1 AND LOWER(description) = 'to be determined' ORDER BY sort_order, id LIMIT 1", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        if result != nil { return result }
        if sqlite3_prepare_v2(db, "SELECT id FROM PortfolioTimelines WHERE is_active = 1 ORDER BY sort_order, id LIMIT 1", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func seedPortfolioTimelinesIfNeeded() {
        guard let db else { return }
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM PortfolioTimelines", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        guard count == 0 else { return }
        let seed = """
        INSERT INTO PortfolioTimelines (id, description, time_indication, sort_order, is_active) VALUES
            (5, 'To be determined', 'TBD', 0, 1),
            (1, 'Short-Term', '0-12m', 1, 1),
            (2, 'Medium-Term', '1-3y', 2, 1),
            (3, 'Long-Term', '3-5y', 3, 1),
            (4, 'Strategic', '5y+', 4, 1);
        """
        if sqlite3_exec(db, seed, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("seedPortfolioTimelinesIfNeeded failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    private func ensureDefaultTimelineRow() {
        guard let db else { return }
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, "SELECT id FROM PortfolioTimelines WHERE LOWER(description) = 'to be determined' LIMIT 1", -1, &stmt, nil) == SQLITE_OK {
            exists = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        guard !exists else { return }

        var minOrder: Int?
        if sqlite3_prepare_v2(db, "SELECT MIN(sort_order) FROM PortfolioTimelines", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                minOrder = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        let order = (minOrder ?? 1) - 1
        let sql = "INSERT INTO PortfolioTimelines (description, time_indication, sort_order, is_active) VALUES ('To be determined', 'TBD', ?, 1)"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(order))
            if sqlite3_step(stmt) != SQLITE_DONE {
                LoggingService.shared.log("ensureDefaultTimelineRow insert failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        }
        sqlite3_finalize(stmt)
    }
}
