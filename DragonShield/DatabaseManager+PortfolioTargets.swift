import Foundation
import SwiftUI

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

    /// Returns stored target percentages aggregated by asset class or sub-class.
    func fetchPortfolioTargetRecords(portfolioId: Int) -> [(classId: Int?, subClassId: Int?, percent: Double)] {
        var results: [(classId: Int?, subClassId: Int?, percent: Double)] = []
        let query = """
            SELECT ac.class_id, asc.sub_class_id, pi.target_allocation_percent
              FROM PortfolioInstruments pi
              JOIN Instruments i  ON pi.instrument_id = i.instrument_id
              JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
              JOIN AssetClasses ac ON asc.class_id = ac.class_id
             WHERE pi.portfolio_id = ?
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(portfolioId))
            while sqlite3_step(statement) == SQLITE_ROW {
                let classId = Int(sqlite3_column_int(statement, 0))
                let subId = Int(sqlite3_column_int(statement, 1))
                let pct = sqlite3_column_double(statement, 2)
                results.append((classId: classId, subClassId: subId, percent: pct))
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchPortfolioTargetRecords: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
        return results
    }

    /// Upsert a class-level target percentage.
    func upsertClassTarget(portfolioId: Int, classId: Int, percent: Double) {
        let query = """
            UPDATE PortfolioInstruments
               SET target_allocation_percent = ?
             WHERE portfolio_id = ?
               AND instrument_id IN (
                     SELECT instrument_id FROM Instruments i
                      JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
                      WHERE asc.class_id = ?
               );
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, percent)
            sqlite3_bind_int(statement, 2, Int32(portfolioId))
            sqlite3_bind_int(statement, 3, Int32(classId))
            if sqlite3_step(statement) != SQLITE_DONE {
                LoggingService.shared.log("Failed to upsert class target: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        } else {
            LoggingService.shared.log("Failed to prepare upsertClassTarget: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
    }

    /// Upsert a sub-class-level target percentage.
    func upsertSubClassTarget(portfolioId: Int, subClassId: Int, percent: Double) {
        let query = """
            UPDATE PortfolioInstruments
               SET target_allocation_percent = ?
             WHERE portfolio_id = ?
               AND instrument_id IN (
                     SELECT instrument_id FROM Instruments WHERE sub_class_id = ?
               );
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, percent)
            sqlite3_bind_int(statement, 2, Int32(portfolioId))
            sqlite3_bind_int(statement, 3, Int32(subClassId))
            if sqlite3_step(statement) != SQLITE_DONE {
                LoggingService.shared.log("Failed to upsert sub-class target: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
        } else {
            LoggingService.shared.log("Failed to prepare upsertSubClassTarget: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(statement)
    }
}
