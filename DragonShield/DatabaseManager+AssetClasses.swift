// DragonShield/DatabaseManager+AssetClasses.swift
// MARK: - Version 1.0 (2025-06-30)
// MARK: - History
// - Initial creation: Provides CRUD operations for AssetClasses table.

import SQLite3
import Foundation
import OSLog

extension DatabaseManager {

    struct AssetClassData: Identifiable, Hashable {
        let id: Int
        var code: String
        var name: String
        var description: String?
        var sortOrder: Int
    }

    func fetchAssetClassesDetailed() -> [AssetClassData] {
        var classes: [AssetClassData] = []
        let query = "SELECT class_id, class_code, class_name, class_description, sort_order FROM AssetClasses ORDER BY sort_order, class_name"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let sortOrder = Int(sqlite3_column_int(statement, 4))
                classes.append(AssetClassData(id: id, code: code, name: name, description: description, sortOrder: sortOrder))
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchAssetClassesDetailed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
        return classes
    }

    func fetchAssetClassDetails(id: Int) -> AssetClassData? {
        let query = "SELECT class_id, class_code, class_name, class_description, sort_order FROM AssetClasses WHERE class_id = ?"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            if sqlite3_step(statement) == SQLITE_ROW {
                let cid = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let sortOrder = Int(sqlite3_column_int(statement, 4))
                sqlite3_finalize(statement)
                return AssetClassData(id: cid, code: code, name: name, description: description, sortOrder: sortOrder)
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchAssetClassDetails: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
        return nil
    }

    func addAssetClass(code: String, name: String, description: String?, sortOrder: Int) -> Bool {
        let query = "INSERT INTO AssetClasses (class_code, class_name, class_description, sort_order) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to prepare addAssetClass: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        if let desc = description, !desc.isEmpty {
            _ = desc.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(sortOrder))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        if result {
            LoggingService.shared.log("Inserted asset class \(name)", type: .info, logger: .database)
        } else {
            LoggingService.shared.log("Insert asset class failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        return result
    }

    func updateAssetClass(id: Int, code: String, name: String, description: String?, sortOrder: Int) -> Bool {
        let query = "UPDATE AssetClasses SET class_code = ?, class_name = ?, class_description = ?, sort_order = ?, updated_at = CURRENT_TIMESTAMP WHERE class_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to prepare updateAssetClass: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        if let desc = description, !desc.isEmpty {
            _ = desc.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(sortOrder))
        sqlite3_bind_int(statement, 5, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        if result {
            LoggingService.shared.log("Updated asset class ID \(id)", type: .info, logger: .database)
        } else {
            LoggingService.shared.log("Update asset class failed ID \(id): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        return result
    }

    func deleteAssetClass(id: Int) -> Bool {
        let query = "DELETE FROM AssetClasses WHERE class_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to prepare deleteAssetClass: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        if result {
            LoggingService.shared.log("Deleted asset class ID \(id)", type: .info, logger: .database)
        } else {
            LoggingService.shared.log("Delete asset class failed ID \(id): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        return result
    }

    /// Purges all data under the specified asset class.
    /// This removes position reports and instruments for each subclass and then deletes the subclasses themselves.
    func purgeAssetClass(id: Int) -> Bool {
        let subQuery = "SELECT sub_class_id FROM AssetSubClasses WHERE class_id = ?"
        var stmt: OpaquePointer?
        var subIds: [Int] = []
        guard sqlite3_prepare_v2(db, subQuery, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to fetch subclasses for purgeAssetClass: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        while sqlite3_step(stmt) == SQLITE_ROW {
            subIds.append(Int(sqlite3_column_int(stmt, 0)))
        }
        sqlite3_finalize(stmt)

        var success = true
        for sid in subIds {
            _ = purgePositionReports(subClassId: sid)
            var delStmt: OpaquePointer?
            let delInstr = "DELETE FROM Instruments WHERE sub_class_id = ?"
            if sqlite3_prepare_v2(db, delInstr, -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_int(delStmt, 1, Int32(sid))
                if sqlite3_step(delStmt) != SQLITE_DONE {
                    success = false
                    LoggingService.shared.log("Failed to delete instruments for subclass \(sid): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
                }
            } else {
                success = false
                LoggingService.shared.log("Failed to prepare instrument delete for subclass \(sid): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
            sqlite3_finalize(delStmt)
        }

        var subDel: OpaquePointer?
        let delSub = "DELETE FROM AssetSubClasses WHERE class_id = ?"
        if sqlite3_prepare_v2(db, delSub, -1, &subDel, nil) == SQLITE_OK {
            sqlite3_bind_int(subDel, 1, Int32(id))
            if sqlite3_step(subDel) != SQLITE_DONE {
                success = false
                LoggingService.shared.log("Failed to delete subclasses for class \(id): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        } else {
            success = false
            LoggingService.shared.log("Failed to prepare subclass delete for class \(id): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(subDel)
        return success
    }

    func canDeleteAssetClass(id: Int) -> (canDelete: Bool, subClassCount: Int, instrumentCount: Int, positionReportCount: Int) {
        var subClassCount = 0
        var instrumentCount = 0
        var positionCount = 0

        // Count subclasses
        var stmt: OpaquePointer?
        let subQuery = "SELECT COUNT(*) FROM AssetSubClasses WHERE class_id = ?"
        if sqlite3_prepare_v2(db, subQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                subClassCount = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        } else {
            LoggingService.shared.log("Failed to count subclasses: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }

        // Count instruments
        let instQuery = """
            SELECT COUNT(*) FROM Instruments
             WHERE sub_class_id IN (SELECT sub_class_id FROM AssetSubClasses WHERE class_id = ?)
        """
        if sqlite3_prepare_v2(db, instQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                instrumentCount = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        } else {
            LoggingService.shared.log("Failed to count instruments: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }

        // Count position reports
        let posQuery = """
            SELECT COUNT(*) FROM PositionReports
             WHERE instrument_id IN (
                 SELECT instrument_id FROM Instruments
                  WHERE sub_class_id IN (
                      SELECT sub_class_id FROM AssetSubClasses WHERE class_id = ?
                  )
             )
        """
        if sqlite3_prepare_v2(db, posQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                positionCount = Int(sqlite3_column_int(stmt, 0))
            }
            sqlite3_finalize(stmt)
        } else {
            LoggingService.shared.log("Failed to count position reports: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }

        let canDelete = subClassCount == 0 && instrumentCount == 0 && positionCount == 0
        return (canDelete, subClassCount, instrumentCount, positionCount)
    }
}

