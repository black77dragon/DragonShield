// DragonShield/Repositories/InstrumentPriceSourceRepository.swift

import Foundation
import SQLite3

struct InstrumentPriceSource: Identifiable {
    var id: Int
    var instrumentId: Int
    var providerCode: String
    var externalId: String
    var enabled: Bool
    var priority: Int
    var lastStatus: String?
    var lastCheckedAt: String?
}

final class InstrumentPriceSourceRepository {
    private let connection: DatabaseConnection
    private var db: OpaquePointer? { connection.db }

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    convenience init(dbManager: DatabaseManager) {
        self.init(connection: dbManager.databaseConnection)
    }

    func enabledPriceSourceRecords(activeInstruments: [Int: String]) -> [PriceSourceRecord] {
        var records: [PriceSourceRecord] = []
        let sql = """
            SELECT instrument_id,
                   provider_code,
                   external_id,
                   priority,
                   updated_at
              FROM InstrumentPriceSource
             WHERE enabled = 1
               AND LENGTH(TRIM(provider_code)) > 0
               AND LENGTH(TRIM(external_id)) > 0
             ORDER BY instrument_id ASC, priority ASC, updated_at DESC
        """
        var stmt: OpaquePointer?
        guard let db, sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var seen: Set<Int> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let instrumentId = Int(sqlite3_column_int(stmt, 0))
            if seen.contains(instrumentId) { continue }
            guard let currency = activeInstruments[instrumentId] else { continue }
            guard let providerPtr = sqlite3_column_text(stmt, 1), let externalPtr = sqlite3_column_text(stmt, 2) else { continue }
            let provider = String(cString: providerPtr).trimmingCharacters(in: .whitespacesAndNewlines)
            let external = String(cString: externalPtr).trimmingCharacters(in: .whitespacesAndNewlines)
            if provider.isEmpty || external.isEmpty { continue }
            records.append(PriceSourceRecord(instrumentId: instrumentId, providerCode: provider, externalId: external, expectedCurrency: currency))
            seen.insert(instrumentId)
        }
        return records
    }

    /// Returns the latest price source per instrument id using the same ordering as `getPriceSource`.
    func getPriceSources(instrumentIds: [Int]) -> [Int: InstrumentPriceSource] {
        guard !instrumentIds.isEmpty else { return [:] }
        let placeholders = instrumentIds.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT id, instrument_id, provider_code, external_id, enabled, priority, last_status, last_checked_at
              FROM InstrumentPriceSource
             WHERE instrument_id IN (\(placeholders))
             ORDER BY instrument_id ASC, enabled DESC, priority ASC, updated_at DESC
        """
        var stmt: OpaquePointer?
        guard let db, sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        for (idx, id) in instrumentIds.enumerated() {
            sqlite3_bind_int(stmt, Int32(idx + 1), Int32(id))
        }
        var map: [Int: InstrumentPriceSource] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let instId = Int(sqlite3_column_int(stmt, 1))
            // Only keep the first row per instrument due to ordering.
            if map[instId] != nil { continue }
            let id = Int(sqlite3_column_int(stmt, 0))
            let provider = String(cString: sqlite3_column_text(stmt, 2))
            let extId = String(cString: sqlite3_column_text(stmt, 3))
            let enabled = sqlite3_column_int(stmt, 4) != 0
            let priority = Int(sqlite3_column_int(stmt, 5))
            let lastStatus = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let lastChecked = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            map[instId] = InstrumentPriceSource(
                id: id,
                instrumentId: instId,
                providerCode: provider,
                externalId: extId,
                enabled: enabled,
                priority: priority,
                lastStatus: lastStatus,
                lastCheckedAt: lastChecked
            )
        }
        return map
    }

    func getPriceSource(instrumentId: Int) -> InstrumentPriceSource? {
        let sql = """
            SELECT id, instrument_id, provider_code, external_id, enabled, priority, last_status, last_checked_at
              FROM InstrumentPriceSource
             WHERE instrument_id = ?
             ORDER BY enabled DESC, priority ASC, updated_at DESC
             LIMIT 1
        """
        var stmt: OpaquePointer?
        guard let db, sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        if sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let instId = Int(sqlite3_column_int(stmt, 1))
            let provider = String(cString: sqlite3_column_text(stmt, 2))
            let extId = String(cString: sqlite3_column_text(stmt, 3))
            let enabled = sqlite3_column_int(stmt, 4) != 0
            let priority = Int(sqlite3_column_int(stmt, 5))
            let lastStatus = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let lastChecked = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            return InstrumentPriceSource(id: id, instrumentId: instId, providerCode: provider, externalId: extId, enabled: enabled, priority: priority, lastStatus: lastStatus, lastCheckedAt: lastChecked)
        }
        return nil
    }

    @discardableResult
    func upsertPriceSource(instrumentId: Int, providerCode: String, externalId: String, enabled: Bool, priority: Int = 1) -> Bool {
        let sql = """
            INSERT INTO InstrumentPriceSource (instrument_id, provider_code, external_id, enabled, priority)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(instrument_id, provider_code) DO UPDATE SET
              external_id = excluded.external_id,
              enabled = excluded.enabled,
              priority = excluded.priority,
              updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
        """
        var stmt: OpaquePointer?
        guard let db else { return false }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            LoggingService.shared.log("upsertPriceSource prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        sqlite3_bind_text(stmt, 2, providerCode, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, externalId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, enabled ? 1 : 0)
        sqlite3_bind_int(stmt, 5, Int32(priority))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        if !ok {
            LoggingService.shared.log("upsertPriceSource step failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        return ok
    }

    @discardableResult
    func updatePriceSourceStatus(instrumentId: Int, providerCode: String, status: String?) -> Bool {
        let sql = """
            UPDATE InstrumentPriceSource
               SET last_status = ?, last_checked_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
             WHERE instrument_id = ? AND provider_code = ?
        """
        var stmt: OpaquePointer?
        guard let db, sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let s = status { sqlite3_bind_text(stmt, 1, s, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 1) }
        sqlite3_bind_int(stmt, 2, Int32(instrumentId))
        sqlite3_bind_text(stmt, 3, providerCode, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_DONE
    }
}
