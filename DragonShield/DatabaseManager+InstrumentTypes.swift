// DragonShield/DatabaseManager+InstrumentTypes.swift
// MARK: - Version 1.0 (2025-05-30)
// MARK: - History
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

extension DatabaseManager {

    func fetchAssetTypes() -> [(id: Int, name: String)] { // This is used by AddInstrumentView
        var groups: [(id: Int, name: String)] = []
        let query = "SELECT group_id, group_name FROM InstrumentGroups WHERE is_active = 1 ORDER BY sort_order, group_id"
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                if let namePtr = sqlite3_column_text(statement, 1) {
                    let name = String(cString: namePtr)
                    groups.append((id: id, name: name))
                }
            }
        } else {
            print("❌ Failed to prepare fetchAssetTypes: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return groups
    }

    func fetchInstrumentTypes() -> [(id: Int, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)] {
        var types: [(id: Int, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)] = []
        let query = """
            SELECT group_id, group_code, group_name, group_description, sort_order, is_active
            FROM InstrumentGroups
            ORDER BY sort_order, group_name
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                let sortOrder = Int(sqlite3_column_int(statement, 4))
                let isActive = sqlite3_column_int(statement, 5) == 1
                
                types.append((id: id, code: code, name: name, description: description, sortOrder: sortOrder, isActive: isActive))
            }
        } else {
            print("❌ Failed to prepare fetchInstrumentTypes: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return types
    }
    
    func fetchInstrumentTypeDetails(id: Int) -> (id: Int, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)? {
        let query = """
            SELECT group_id, group_code, group_name, group_description, sort_order, is_active
            FROM InstrumentGroups
            WHERE group_id = ?
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let typeId = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                let sortOrder = Int(sqlite3_column_int(statement, 4))
                let isActive = sqlite3_column_int(statement, 5) == 1
                
                sqlite3_finalize(statement)
                return (id: typeId, code: code, name: name, description: description, sortOrder: sortOrder, isActive: isActive)
            } else {
                print("ℹ️ No instrument type details found for ID: \(id)")
            }
        } else {
            print("❌ Failed to prepare fetchInstrumentTypeDetails (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return nil
    }
    
    func addInstrumentType(code: String, name: String, description: String, sortOrder: Int, isActive: Bool) -> Bool {
        let query = """
            INSERT INTO InstrumentGroups (group_code, group_name, group_description, sort_order, is_active)
            VALUES (?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addInstrumentType: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        if !description.isEmpty {
            _ = description.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(sortOrder))
        sqlite3_bind_int(statement, 5, isActive ? 1 : 0)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Inserted instrument type '\(name)' with ID: \(sqlite3_last_insert_rowid(db))")
        } else {
            print("❌ Insert instrument type '\(name)' failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
    
    func updateInstrumentType(id: Int, code: String, name: String, description: String, sortOrder: Int, isActive: Bool) -> Bool {
        let query = """
            UPDATE InstrumentGroups
            SET group_code = ?, group_name = ?, group_description = ?, sort_order = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
            WHERE group_id = ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateInstrumentType (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        if !description.isEmpty {
            _ = description.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, Int32(sortOrder))
        sqlite3_bind_int(statement, 5, isActive ? 1 : 0)
        sqlite3_bind_int(statement, 6, Int32(id))
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Updated instrument type (ID: \(id))")
        } else {
            print("❌ Update instrument type failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
    
    func deleteInstrumentType(id: Int) -> Bool { // Hard delete
        let deleteQuery = "DELETE FROM InstrumentGroups WHERE group_id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteInstrumentType (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Deleted instrument type (ID: \(id))")
        } else {
            print("❌ Delete instrument type failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    func canDeleteInstrumentType(id: Int) -> (canDelete: Bool, instrumentCount: Int) {
        let checkQuery = "SELECT COUNT(*) FROM Instruments WHERE group_id = ?"
        var checkStatement: OpaquePointer?
        var count: Int = 0
        
        if sqlite3_prepare_v2(db, checkQuery, -1, &checkStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStatement, 1, Int32(id))
            if sqlite3_step(checkStatement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(checkStatement, 0))
            }
            sqlite3_finalize(checkStatement)
        } else {
            print("❌ Failed to prepare canDeleteInstrumentType check (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return (canDelete: count == 0, instrumentCount: count)
    }
}
