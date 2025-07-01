// DragonShield/DatabaseManager+AssetClasses.swift
// MARK: - Version 1.0 (2025-06-30)
// MARK: - History
// - Initial creation: Provides CRUD operations for AssetClasses table.

import SQLite3
import Foundation

extension DatabaseManager {

    struct AssetClassData: Identifiable, Equatable {
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
            print("❌ Failed to prepare fetchAssetClassesDetailed: \(String(cString: sqlite3_errmsg(db)))")
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
            print("❌ Failed to prepare fetchAssetClassDetails: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return nil
    }

    func addAssetClass(code: String, name: String, description: String?, sortOrder: Int) -> Bool {
        let query = "INSERT INTO AssetClasses (class_code, class_name, class_description, sort_order) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addAssetClass: \(String(cString: sqlite3_errmsg(db)))")
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
        if result { print("✅ Inserted asset class '\(name)'") } else { print("❌ Insert asset class failed: \(String(cString: sqlite3_errmsg(db)))") }
        return result
    }

    func updateAssetClass(id: Int, code: String, name: String, description: String?, sortOrder: Int) -> Bool {
        let query = "UPDATE AssetClasses SET class_code = ?, class_name = ?, class_description = ?, sort_order = ?, updated_at = CURRENT_TIMESTAMP WHERE class_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateAssetClass: \(String(cString: sqlite3_errmsg(db)))")
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
        if result { print("✅ Updated asset class (ID: \(id))") } else { print("❌ Update asset class failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))") }
        return result
    }

    func deleteAssetClass(id: Int) -> Bool {
        let query = "DELETE FROM AssetClasses WHERE class_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteAssetClass: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        if result { print("✅ Deleted asset class (ID: \(id))") } else { print("❌ Delete asset class failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))") }
        return result
    }

    func canDeleteAssetClass(id: Int) -> (canDelete: Bool, subClassCount: Int) {
        let query = "SELECT COUNT(*) FROM AssetSubClasses WHERE class_id = ?"
        var statement: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        } else {
            print("❌ Failed to prepare canDeleteAssetClass check: \(String(cString: sqlite3_errmsg(db)))")
        }
        return (canDelete: count == 0, subClassCount: count)
    }
}

