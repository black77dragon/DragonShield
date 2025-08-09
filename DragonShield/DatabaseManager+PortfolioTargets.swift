import Foundation
import SwiftUI
import SQLite3

extension DatabaseManager {
    struct AllocationTarget: Identifiable, Hashable {
        let id: String
        var assetClassName: String
        var targetPercent: Double
        var currentPercent: Double
    }

    struct SubClassTarget: Identifiable, Hashable {
        let id: Int
        var name: String
        var targetPercent: Double
        var currentPercent: Double
    }

    struct ClassTarget: Identifiable, Hashable {
        let id: Int
        var name: String
        var targetPercent: Double
        var currentPercent: Double
        var subTargets: [SubClassTarget]
    }

    /// Returns current and target allocation percentages grouped by asset class.
    /// This uses sample data from `fetchAssetAllocationVariance()` for now.
    func fetchPortfolioTargets() -> [AllocationTarget] {
        let variance = fetchAssetAllocationVariance()
        return variance.items.map { item in
            AllocationTarget(id: item.id,
                              assetClassName: item.assetClassName,
                              targetPercent: item.targetPercent,
                              currentPercent: item.currentPercent)
        }
    }

    /// Persists updated target percentages. The demo implementation only logs
    /// the values but would update `PortfolioInstruments` in a full build.
    func savePortfolioTargets(_ targets: [AllocationTarget]) {
        for target in targets {
            LoggingService.shared.log(
                "Saving target for \(target.assetClassName): \(target.targetPercent)%",
                type: .info,
                logger: .database
            )
        }
        // Actual SQL update omitted in sample code base
    }

    /// Returns all asset classes with optional subclass targets. This sample
    /// implementation combines basic asset class data with placeholder
    /// subclass information.
    func fetchPortfolioClassTargets() -> [ClassTarget] {
        let classes = fetchAssetClassesDetailed()
        let varianceMap = Dictionary(uniqueKeysWithValues: fetchPortfolioTargets().map { ($0.assetClassName, $0) })

        return classes.map { cls in
            let base = varianceMap[cls.name]
            let subs = fetchSubClasses(for: cls.id).map { sub in
                SubClassTarget(id: sub.id,
                               name: sub.name,
                               targetPercent: 0,
                               currentPercent: 0)
            }
            return ClassTarget(id: cls.id,
                               name: cls.name,
                               targetPercent: base?.targetPercent ?? 0,
                               currentPercent: base?.currentPercent ?? 0,
                               subTargets: subs)
        }
    }

    /// Placeholder for saving class and subclass targets separately.
    func savePortfolioClassTargets(_ classes: [ClassTarget]) {
        for cls in classes {
            LoggingService.shared.log(
                "Saving class target for \(cls.name): \(cls.targetPercent)%",
                type: .info,
                logger: .database
            )
            for sub in cls.subTargets {
                LoggingService.shared.log(
                    "  Sub \(sub.name): \(sub.targetPercent)%",
                    type: .info,
                    logger: .database
                )
            }
        }
        // Actual SQL update omitted in sample code base
    }

    /// Returns all sub-classes for a given asset class.
    /// Target values default to 0 and should be bound by the caller.
    func subAssetClasses(for classId: Int) -> [SubClassTarget] {
        fetchSubClasses(for: classId).map { row in
            SubClassTarget(id: row.id,
                           name: row.name,
                           targetPercent: 0,
                           currentPercent: 0)
        }
    }

    private func fetchSubClasses(for classId: Int) -> [(id: Int, name: String)] {
        var subClasses: [(id: Int, name: String)] = []
        let query = "SELECT sub_class_id, sub_class_name FROM AssetSubClasses WHERE class_id = ? ORDER BY sort_order, sub_class_name"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(classId))
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                if let namePtr = sqlite3_column_text(statement, 1) {
                    subClasses.append((id: id, name: String(cString: namePtr)))
                }
            }
        } else {
            LoggingService.shared.log(
                "Failed to prepare fetchSubClasses: \(String(cString: sqlite3_errmsg(db)))",
                type: .error,
                logger: .database
            )
        }
        sqlite3_finalize(statement)
        return subClasses
    }

    // MARK: - New persistence helpers

    /// Fetch the class-level target for a given asset class.
    func fetchClassTarget(classId: Int) -> (
        percent: Double,
        amountCHF: Double,
        targetKind: String,
        tolerance: Double
    )? {
        LoggingService.shared.log("Fetching ClassTargets for id=\(classId)", type: .info, logger: .database)
        let query = "SELECT target_percent, target_amount_chf, target_kind, tolerance_percent FROM ClassTargets WHERE asset_class_id = ?;"
        var statement: OpaquePointer?
        var result: (Double, Double, String, Double)?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(classId))
            if sqlite3_step(statement) == SQLITE_ROW {
                let pct = sqlite3_column_double(statement, 0)
                let amt = sqlite3_column_double(statement, 1)
                let kind = String(cString: sqlite3_column_text(statement, 2))
                let tol = sqlite3_column_double(statement, 3)
                result = (pct, amt, kind, tol)
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchClassTarget: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
        return result.map { (percent: $0.0, amountCHF: $0.1, targetKind: $0.2, tolerance: $0.3) }
    }

    /// Fetch all sub-class targets for a given asset class.
    func fetchSubClassTargets(classId: Int) -> [(
        id: Int,
        name: String,
        percent: Double,
        amountCHF: Double,
        targetKind: String,
        tolerance: Double
    )] {
        LoggingService.shared.log("Fetching SubClassTargets for class id=\(classId)", type: .info, logger: .database)
        var results: [(
            id: Int,
            name: String,
            percent: Double,
            amountCHF: Double,
            targetKind: String,
            tolerance: Double
        )] = []
        let query = """
            SELECT asc.sub_class_id,
                   asc.sub_class_name,
                   COALESCE(s.target_percent,0),
                   COALESCE(s.target_amount_chf,0),
                   COALESCE(s.target_kind,'percent'),
                   COALESCE(s.tolerance_percent,0)
            FROM AssetSubClasses asc
            LEFT JOIN ClassTargets ct ON ct.asset_class_id = asc.class_id
            LEFT JOIN SubClassTargets s ON s.class_target_id = ct.id AND s.asset_sub_class_id = asc.sub_class_id
            WHERE asc.class_id = ?
            ORDER BY asc.sort_order, asc.sub_class_name;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(classId))
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let pct = sqlite3_column_double(statement, 2)
                let amt = sqlite3_column_double(statement, 3)
                let kind = String(cString: sqlite3_column_text(statement, 4))
                let tol = sqlite3_column_double(statement, 5)
                results.append((id: id, name: name, percent: pct, amountCHF: amt, targetKind: kind, tolerance: tol))
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchSubClassTargets: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
        return results
    }

    /// Returns stored target percentages aggregated by asset class or sub-class.
    func fetchPortfolioTargetRecords(portfolioId: Int) -> [(
        classId: Int?,
        subClassId: Int?,
        percent: Double,
        amountCHF: Double?,
        targetKind: String,
        tolerance: Double,
        validationStatus: String
    )] {
        var results: [(
            classId: Int?,
            subClassId: Int?,
            percent: Double,
            amountCHF: Double?,
            targetKind: String,
            tolerance: Double,
            validationStatus: String
        )] = []
        let query = """
            SELECT asset_class_id,
                   NULL AS sub_class_id,
                   target_percent,
                   target_amount_chf,
                   target_kind,
                   tolerance_percent,
                   validation_status
            FROM ClassTargets
            UNION ALL
            SELECT ct.asset_class_id,
                   s.asset_sub_class_id,
                   s.target_percent,
                   s.target_amount_chf,
                   s.target_kind,
                   s.tolerance_percent,
                   s.validation_status
            FROM SubClassTargets s
            JOIN ClassTargets ct ON s.class_target_id = ct.id;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let classId = Int(sqlite3_column_int(statement, 0))
                let subId = sqlite3_column_type(statement, 1) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 1))
                let pct = sqlite3_column_double(statement, 2)
                let amount = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 3)
                let kind = String(cString: sqlite3_column_text(statement, 4))
                let tolerance = sqlite3_column_double(statement, 5)
                let status = String(cString: sqlite3_column_text(statement, 6))
                results.append((classId: classId,
                                subClassId: subId,
                                percent: pct,
                                amountCHF: amount,
                                targetKind: kind,
                                tolerance: tolerance,
                                validationStatus: status))
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetch ClassTargets/SubClassTargets: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
        return results
    }

    /// Upsert a class-level target percentage.
    func upsertClassTarget(portfolioId: Int, classId: Int, percent: Double, amountChf: Double? = nil, kind: String = "percent", tolerance: Double) {
        LoggingService.shared.log("Upserting ClassTargets id=\(classId)", type: .info, logger: .database)
        let query = """
            INSERT INTO ClassTargets (asset_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at)
            VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(asset_class_id)
            DO UPDATE SET target_percent = excluded.target_percent,
                         target_amount_chf = excluded.target_amount_chf,
                         target_kind = excluded.target_kind,
                         tolerance_percent = excluded.tolerance_percent,
                         updated_at = CURRENT_TIMESTAMP;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_int(statement, 1, Int32(classId))
            sqlite3_bind_double(statement, 2, percent)
            if let amt = amountChf {
                sqlite3_bind_double(statement, 3, amt)
            } else {
                sqlite3_bind_null(statement, 3)
            }
            sqlite3_bind_text(statement, 4, kind, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 5, tolerance)
            if sqlite3_step(statement) != SQLITE_DONE {
                LoggingService.shared.log("Failed to upsert ClassTargets: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        } else {
            LoggingService.shared.log("Failed to prepare upsert ClassTargets: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
    }

    /// Upsert a sub-class-level target percentage.
    func upsertSubClassTarget(portfolioId: Int, subClassId: Int, percent: Double, amountChf: Double? = nil, kind: String = "percent", tolerance: Double) {
        LoggingService.shared.log("Upserting SubClassTargets id=\(subClassId)", type: .info, logger: .database)
        let query = """
            INSERT INTO SubClassTargets (class_target_id, asset_sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at)
            VALUES ((SELECT id FROM ClassTargets WHERE asset_class_id = (SELECT class_id FROM AssetSubClasses WHERE sub_class_id = ?)), ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(class_target_id, asset_sub_class_id)
            DO UPDATE SET target_percent = excluded.target_percent,
                         target_amount_chf = excluded.target_amount_chf,
                         target_kind = excluded.target_kind,
                         tolerance_percent = excluded.tolerance_percent,
                         updated_at = CURRENT_TIMESTAMP;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_int(statement, 1, Int32(subClassId))
            sqlite3_bind_int(statement, 2, Int32(subClassId))
            sqlite3_bind_double(statement, 3, percent)
            if let amt = amountChf {
                sqlite3_bind_double(statement, 4, amt)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_text(statement, 5, kind, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 6, tolerance)
            if sqlite3_step(statement) != SQLITE_DONE {
                LoggingService.shared.log("Failed to upsert SubClassTargets: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        } else {
            LoggingService.shared.log("Failed to prepare upsert SubClassTargets: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
    }

    /// Validates that class and sub-class target sums meet expected totals.
    /// Returns a list of warning messages but does not block saves.
    func validateTargetSums(portfolioId: Int, globalTolerance: Double = 0.1) -> [String] {
        var warnings: [String] = []
        let records = fetchPortfolioTargetRecords(portfolioId: portfolioId)

        // Parent-level percentage sum
        let parentPercents = records.filter { $0.subClassId == nil }.map { $0.percent }
        let parentSum = parentPercents.reduce(0, +)
        if abs(parentSum - 100) > globalTolerance {
            warnings.append(String(format: "asset-class %% sum=%.1f%% (expected 100%%)", parentSum))
        }

        // Child-level per class
        let classGroups = Dictionary(grouping: records, by: { $0.classId })
        for (classIdOpt, rows) in classGroups {
            guard let classId = classIdOpt,
                  let parent = rows.first(where: { $0.subClassId == nil }) else { continue }
            let subs = rows.filter { $0.subClassId != nil }
            let childSum = subs.map { $0.percent }.reduce(0, +)
            if abs(childSum - 100) > parent.tolerance {
                warnings.append(String(format: "class %d sub-class %% sum=%.1f%% (expected 100%%)", classId, childSum))
            }
        }
        return warnings
    }
}
