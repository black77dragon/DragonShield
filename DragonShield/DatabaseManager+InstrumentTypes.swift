// DragonShield/DatabaseManager+InstrumentTypes.swift
// MARK: - Version 1.0 (2025-05-30)
// MARK: - History
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

extension DatabaseManager {

    func fetchAssetClasses() -> [(id: Int, name: String)] {
        var classes: [(id: Int, name: String)] = []
        let query = "SELECT class_id, class_name FROM AssetClasses ORDER BY sort_order, class_name"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                if let namePtr = sqlite3_column_text(statement, 1) {
                    classes.append((id: id, name: String(cString: namePtr)))
                }
            }
        } else {
            print("❌ Failed to prepare fetchAssetClasses: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return classes
    }

    func fetchAssetTypes() -> [(id: Int, name: String)] { // This is used by AddInstrumentView
        var groups: [(id: Int, name: String)] = []
        let query = "SELECT sub_class_id, sub_class_name FROM AssetSubClasses"

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

        groups.sort { lhs, rhs in
            lhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) <
                rhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        return groups
    }

    func fetchInstrumentTypes() -> [(id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)] {
        var types: [(id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)] = []
        let query = """
            SELECT asc.sub_class_id, asc.class_id, ac.class_description,
                   asc.sub_class_code, asc.sub_class_name,
                   asc.sub_class_description, asc.sort_order, 1
            FROM AssetSubClasses asc
            JOIN AssetClasses ac ON asc.class_id = ac.class_id
            ORDER BY asc.sort_order, asc.sub_class_name
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let classId = Int(sqlite3_column_int(statement, 1))
                let classDesc = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                let code = String(cString: sqlite3_column_text(statement, 3))
                let name = String(cString: sqlite3_column_text(statement, 4))
                let description = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? ""
                let sortOrder = Int(sqlite3_column_int(statement, 6))
                let isActive = sqlite3_column_int(statement, 7) == 1

                types.append((id: id, classId: classId, classDescription: classDesc, code: code, name: name, description: description, sortOrder: sortOrder, isActive: isActive))
            }
        } else {
            print("❌ Failed to prepare fetchInstrumentTypes: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return types
    }
    
    func fetchInstrumentTypeDetails(id: Int) -> (id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)? {
        let query = """
            SELECT asc.sub_class_id, asc.class_id, ac.class_description,
                   asc.sub_class_code, asc.sub_class_name, asc.sub_class_description,
                   asc.sort_order, 1
            FROM AssetSubClasses asc
            JOIN AssetClasses ac ON asc.class_id = ac.class_id
            WHERE asc.sub_class_id = ?
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let typeId = Int(sqlite3_column_int(statement, 0))
                let classId = Int(sqlite3_column_int(statement, 1))
                let classDesc = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? ""
                let code = String(cString: sqlite3_column_text(statement, 3))
                let name = String(cString: sqlite3_column_text(statement, 4))
                let description = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? ""
                let sortOrder = Int(sqlite3_column_int(statement, 6))
                let isActive = sqlite3_column_int(statement, 7) == 1

                sqlite3_finalize(statement)
                return (id: typeId, classId: classId, classDescription: classDesc, code: code, name: name, description: description, sortOrder: sortOrder, isActive: isActive)
            } else {
                print("ℹ️ No instrument type details found for ID: \(id)")
            }
        } else {
            print("❌ Failed to prepare fetchInstrumentTypeDetails (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return nil
    }
    
    func addInstrumentType(classId: Int, code: String, name: String, description: String, sortOrder: Int, isActive: Bool) -> Bool {
        let query = """
            INSERT INTO AssetSubClasses (class_id, sub_class_code, sub_class_name, sub_class_description, sort_order)
            VALUES (?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addInstrumentType: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_int(statement, 1, Int32(classId))
        _ = code.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        if !description.isEmpty {
            _ = description.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_int(statement, 5, Int32(sortOrder))
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Inserted instrument type '\(name)' with ID: \(sqlite3_last_insert_rowid(db))")
        } else {
            print("❌ Insert instrument type '\(name)' failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
    
    func updateInstrumentType(id: Int, classId: Int, code: String, name: String, description: String, sortOrder: Int, isActive: Bool) -> Bool {
        let query = """
            UPDATE AssetSubClasses
            SET class_id = ?, sub_class_code = ?, sub_class_name = ?, sub_class_description = ?, sort_order = ?, updated_at = CURRENT_TIMESTAMP
            WHERE sub_class_id = ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateInstrumentType (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        sqlite3_bind_int(statement, 1, Int32(classId))
        _ = code.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        if !description.isEmpty {
            _ = description.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_int(statement, 5, Int32(sortOrder))
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
        let deleteQuery = "DELETE FROM AssetSubClasses WHERE sub_class_id = ?"
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

    func canDeleteInstrumentType(id: Int) -> (canDelete: Bool, instrumentCount: Int, allocationCount: Int) {
        var instrumentCount = 0
        var allocationCount = 0

        let instrumentQuery = "SELECT COUNT(*) FROM Instruments WHERE sub_class_id = ?"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, instrumentQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            if sqlite3_step(statement) == SQLITE_ROW {
                instrumentCount = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        } else {
            print("❌ Failed to prepare instrument usage check (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }

        let allocationQuery = "SELECT COUNT(*) FROM SubClassTargets WHERE asset_sub_class_id = ?"
        if sqlite3_prepare_v2(db, allocationQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            if sqlite3_step(statement) == SQLITE_ROW {
                allocationCount = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        } else {
            print("❌ Failed to prepare allocation usage check (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }

        return (canDelete: instrumentCount == 0 && allocationCount == 0,
                instrumentCount: instrumentCount,
                allocationCount: allocationCount)
    }

    func usageDetailsForInstrumentType(id: Int) -> [(table: String, field: String, count: Int)] {
        let info = canDeleteInstrumentType(id: id)
        var details: [(String, String, Int)] = []

        if info.instrumentCount > 0 {
            details.append(("Instruments", "sub_class_id", info.instrumentCount))
        }

        if info.allocationCount > 0 {
            details.append(("SubClassTargets", "asset_sub_class_id", info.allocationCount))
        }

        return details
    }
}
