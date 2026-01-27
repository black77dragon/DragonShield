import Foundation
import SQLite3

extension DatabaseManager {
    struct RiskMappingItem: Identifiable, Equatable {
        let id: Int
        let code: String
        let name: String
        let defaultSRI: Int
        let defaultLiquidityTier: Int
        let rationale: String
        let mappingVersion: String
    }

    struct RiskConfigDefaults {
        var fallbackSRI: Int
        var fallbackLiquidityTier: Int
        var mappingVersion: String
    }

    struct RiskProfileRow {
        let instrumentId: Int
        let computedSRI: Int
        let computedLiquidityTier: Int
        let manualOverride: Bool
        let overrideSRI: Int?
        let overrideLiquidityTier: Int?
        let overrideReason: String?
        let overrideBy: String?
        let overrideExpiresAt: Date?
        let calcMethod: String?
        let mappingVersion: String?
        let calcInputsJSON: String?
        let calculatedAt: Date?
        let updatedAt: Date?
        var effectiveSRI: Int { manualOverride ? (overrideSRI ?? computedSRI) : computedSRI }
        var effectiveLiquidityTier: Int { manualOverride ? (overrideLiquidityTier ?? computedLiquidityTier) : computedLiquidityTier }
    }

    struct RiskOverrideRow: Identifiable {
        let id: Int
        let instrumentName: String
        let instrumentCode: String
        let computedSRI: Int
        let overrideSRI: Int?
        let computedLiquidityTier: Int
        let overrideLiquidityTier: Int?
        let overrideReason: String?
        let overrideBy: String?
        let overrideExpiresAt: Date?
        let mappingVersion: String?
    }

    /// Loads the current fallback configuration and mapping version.
    func fetchRiskConfigDefaults() -> RiskConfigDefaults {
        let sri = riskConfigInt(key: "risk_default_sri", fallback: 5, min: 1, max: 7)
        let tier = riskConfigInt(key: "risk_default_liquidity_tier", fallback: 1, min: 0, max: 2)
        let version = configurationValue(for: "risk_mapping_version") ?? "risk_map_v1"
        return RiskConfigDefaults(fallbackSRI: sri, fallbackLiquidityTier: tier, mappingVersion: version)
    }

    /// Persists fallback defaults for unmapped instrument types and the mapping version tag.
    @discardableResult
    func updateRiskConfigDefaults(fallbackSRI: Int, fallbackLiquidityTier: Int, mappingVersion: String) -> Bool {
        guard let db else { return false }
        let statements = [
            ("risk_default_sri", fallbackSRI, "Default SRI applied when an instrument type has no mapping"),
            ("risk_default_liquidity_tier", fallbackLiquidityTier, "Default liquidity tier (0=Liquid,1=Restricted,2=Illiquid) for unmapped types")
        ]
        var ok = true
        for (key, value, desc) in statements {
            let sql = """
                INSERT INTO Configuration (key, value, data_type, description, updated_at)
                VALUES (?, ?, 'number', ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
                ON CONFLICT(key) DO UPDATE SET
                  value = excluded.value,
                  data_type = excluded.data_type,
                  description = COALESCE(excluded.description, Configuration.description),
                  updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now');
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { ok = false; continue }
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            _ = key.withCString { sqlite3_bind_text(stmt, 1, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_bind_int(stmt, 2, Int32(value))
            _ = desc.withCString { sqlite3_bind_text(stmt, 3, $0, -1, SQLITE_TRANSIENT) }
            ok = ok && sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
        }

        let versionSql = """
            INSERT INTO Configuration (key, value, data_type, description, updated_at)
            VALUES ('risk_mapping_version', ?, 'string', 'Version tag for instrument risk type mapping defaults', STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
            ON CONFLICT(key) DO UPDATE SET
              value = excluded.value,
              data_type = excluded.data_type,
              description = COALESCE(excluded.description, Configuration.description),
              updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now');
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, versionSql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            _ = mappingVersion.withCString { sqlite3_bind_text(stmt, 1, $0, -1, SQLITE_TRANSIENT) }
            ok = ok && sqlite3_step(stmt) == SQLITE_DONE
        } else {
            ok = false
        }
        sqlite3_finalize(stmt)
        return ok
    }

    /// Returns the current risk profile for an instrument, seeding it if missing.
    func fetchRiskProfile(instrumentId: Int) -> RiskProfileRow? {
        guard let db else { return nil }
        guard tableExists("InstrumentRiskProfile") else { return nil }

        let sql = """
            SELECT instrument_id, computed_sri, computed_liquidity_tier, manual_override,
                   override_sri, override_liquidity_tier, override_reason, override_by, override_expires_at,
                   calc_method, mapping_version, calc_inputs_json, calculated_at, updated_at
              FROM InstrumentRiskProfile
             WHERE instrument_id = ?
             LIMIT 1
        """

        var stmt: OpaquePointer?
        var row: RiskProfileRow?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let computedSRI = Int(sqlite3_column_int(stmt, 1))
                let computedLiq = Int(sqlite3_column_int(stmt, 2))
                let manual = sqlite3_column_int(stmt, 3) == 1
                let overrideSRI = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
                let overrideLiq = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
                let overrideReason = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let overrideBy = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let overrideExpires = sqlite3_column_text(stmt, 8).flatMap { iso.date(from: String(cString: $0)) }
                let calcMethod = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
                let mappingVersion = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                let calcInputs = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
                let calculatedAt = sqlite3_column_text(stmt, 12).flatMap { iso.date(from: String(cString: $0)) }
                let updatedAt = sqlite3_column_text(stmt, 13).flatMap { iso.date(from: String(cString: $0)) }

                row = RiskProfileRow(
                    instrumentId: instrumentId,
                    computedSRI: computedSRI,
                    computedLiquidityTier: computedLiq,
                    manualOverride: manual,
                    overrideSRI: overrideSRI,
                    overrideLiquidityTier: overrideLiq,
                    overrideReason: overrideReason,
                    overrideBy: overrideBy,
                    overrideExpiresAt: overrideExpires,
                    calcMethod: calcMethod,
                    mappingVersion: mappingVersion,
                    calcInputsJSON: calcInputs,
                    calculatedAt: calculatedAt,
                    updatedAt: updatedAt
                )
            }
        }
        sqlite3_finalize(stmt)
        return row
    }

    /// Recalculate or seed the risk profile for the instrument using its current sub-class.
    @discardableResult
    func recalcRiskProfileForInstrument(instrumentId: Int) -> Bool {
        guard let db else { return false }
        let sql = "SELECT sub_class_id FROM Instruments WHERE instrument_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var subClassId: Int?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                subClassId = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        guard let scId = subClassId else { return false }
        return upsertRiskProfileForInstrument(instrumentId: instrumentId, subClassId: scId)
    }

    /// Update manual override fields and optionally clear overrides to resume computed values.
    @discardableResult
    func updateRiskProfileOverride(
        instrumentId: Int,
        subClassId: Int?,
        manualOverride: Bool,
        overrideSRI: Int?,
        overrideLiquidityTier: Int?,
        overrideReason: String?,
        overrideBy: String?,
        overrideExpiresAt: Date?
    ) -> Bool {
        guard let db else { return false }
        guard tableExists("InstrumentRiskProfile") else { return false }

        // Ensure a profile row exists
        let effectiveSubClass: Int? = subClassId ?? {
            var sc: Int?
            let sql = "SELECT sub_class_id FROM Instruments WHERE instrument_id = ? LIMIT 1"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(instrumentId))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    sc = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
            return sc
        }()
        if let scId = effectiveSubClass {
            _ = upsertRiskProfileForInstrument(instrumentId: instrumentId, subClassId: scId)
        } else {
            return false
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiresString = overrideExpiresAt.map { iso.string(from: $0) }

        let sql = """
            UPDATE InstrumentRiskProfile
               SET manual_override = ?,
                   override_sri = ?,
                   override_liquidity_tier = ?,
                   override_reason = ?,
                   override_by = ?,
                   override_expires_at = ?,
                   updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
             WHERE instrument_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, manualOverride ? 1 : 0)
        if manualOverride {
            sqlite3_bind_int(stmt, 2, Int32(coerceSRI(overrideSRI ?? 1)))
            sqlite3_bind_int(stmt, 3, Int32(coerceLiquidityTier(overrideLiquidityTier ?? 0)))
            if let reason = overrideReason, !reason.isEmpty {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                _ = reason.withCString { sqlite3_bind_text(stmt, 4, $0, -1, SQLITE_TRANSIENT) }
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            if let by = overrideBy, !by.isEmpty {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                _ = by.withCString { sqlite3_bind_text(stmt, 5, $0, -1, SQLITE_TRANSIENT) }
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            if let exp = expiresString {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                _ = exp.withCString { sqlite3_bind_text(stmt, 6, $0, -1, SQLITE_TRANSIENT) }
            } else {
                sqlite3_bind_null(stmt, 6)
            }
        } else {
            sqlite3_bind_null(stmt, 2)
            sqlite3_bind_null(stmt, 3)
            sqlite3_bind_null(stmt, 4)
            sqlite3_bind_null(stmt, 5)
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_int(stmt, 7, Int32(instrumentId))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)

        if !manualOverride {
            _ = recalcRiskProfileForInstrument(instrumentId: instrumentId)
        }
        return ok
    }

    /// Returns all mapped instrument types with their defaults.
    func fetchRiskMappings() -> [RiskMappingItem] {
        guard let db, tableExists("InstrumentRiskMapping") else { return [] }
        var rows: [RiskMappingItem] = []
        let sql = """
            SELECT asc.sub_class_id,
                   asc.sub_class_code,
                   asc.sub_class_name,
                   m.default_sri,
                   m.default_liquidity_tier,
                   COALESCE(m.rationale, ''),
                   m.mapping_version
              FROM InstrumentRiskMapping m
              JOIN AssetSubClasses asc ON asc.sub_class_id = m.sub_class_id
             ORDER BY LOWER(asc.sub_class_name)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "code"
                let name = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "name"
                let sri = Int(sqlite3_column_int(stmt, 3))
                let liq = Int(sqlite3_column_int(stmt, 4))
                let rationale = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let version = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? "risk_map_v1"
                rows.append(RiskMappingItem(id: id, code: code, name: name, defaultSRI: sri, defaultLiquidityTier: liq, rationale: rationale, mappingVersion: version))
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    struct SubClassOption: Identifiable, Equatable {
        let id: Int
        let code: String
        let name: String
    }

    /// Returns instrument sub-classes without a mapping row.
    func fetchUnmappedSubClasses() -> [SubClassOption] {
        guard let db else { return [] }
        let hasMappingTable = tableExists("InstrumentRiskMapping")
        var rows: [SubClassOption] = []
        let sql = """
            SELECT asc.sub_class_id, asc.sub_class_code, asc.sub_class_name
              FROM AssetSubClasses asc
              \(hasMappingTable ? "LEFT JOIN InstrumentRiskMapping m ON m.sub_class_id = asc.sub_class_id" : "")
             WHERE \(hasMappingTable ? "m.sub_class_id IS NULL" : "1=1")
             ORDER BY LOWER(asc.sub_class_name)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "code"
                let name = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "name"
                rows.append(SubClassOption(id: id, code: code, name: name))
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    /// Insert or update a mapping and refresh risk profiles for instruments in the subclass.
    @discardableResult
    func upsertRiskMapping(subClassId: Int, defaultSRI: Int, defaultLiquidityTier: Int, rationale: String?, mappingVersion: String) -> Bool {
        guard let db else { return false }
        guard tableExists("InstrumentRiskMapping") else { return false }

        let sql = """
            INSERT INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale, mapping_version, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT(sub_class_id) DO UPDATE SET
                default_sri = excluded.default_sri,
                default_liquidity_tier = excluded.default_liquidity_tier,
                rationale = excluded.rationale,
                mapping_version = excluded.mapping_version,
                updated_at = CURRENT_TIMESTAMP
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(subClassId))
        sqlite3_bind_int(stmt, 2, Int32(coerceSRI(defaultSRI)))
        sqlite3_bind_int(stmt, 3, Int32(coerceLiquidityTier(defaultLiquidityTier)))
        if let rationale, !rationale.isEmpty {
            _ = rationale.withCString { sqlite3_bind_text(stmt, 4, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        _ = mappingVersion.withCString { sqlite3_bind_text(stmt, 5, $0, -1, SQLITE_TRANSIENT) }
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)

        if ok {
            refreshRiskProfilesForSubClass(subClassId: subClassId)
        }
        return ok
    }

    /// Deletes a mapping; leaves existing instrument profiles untouched (they will fall back to defaults on next recalc).
    @discardableResult
    func deleteRiskMapping(subClassId: Int) -> Bool {
        guard let db, tableExists("InstrumentRiskMapping") else { return false }
        let sql = "DELETE FROM InstrumentRiskMapping WHERE sub_class_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(subClassId))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        if ok {
            refreshRiskProfilesForSubClass(subClassId: subClassId)
        }
        return ok
    }

    /// Refreshes or seeds InstrumentRiskProfile rows for all instruments in the given sub-class.
    @discardableResult
    func refreshRiskProfilesForSubClass(subClassId: Int) -> Bool {
        guard let db else { return false }
        guard tableExists("InstrumentRiskProfile") else { return true }

        let sql = "SELECT instrument_id FROM Instruments WHERE sub_class_id = ?"
        var stmt: OpaquePointer?
        var ok = true
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(subClassId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let iid = Int(sqlite3_column_int(stmt, 0))
                ok = ok && upsertRiskProfileForInstrument(instrumentId: iid, subClassId: subClassId)
            }
        } else {
            ok = false
        }
        sqlite3_finalize(stmt)
        return ok
    }

    /// Returns all instruments with manual overrides and their details.
    func listRiskOverrides() -> [RiskOverrideRow] {
        guard let db, tableExists("InstrumentRiskProfile") else { return [] }
        var rows: [RiskOverrideRow] = []
        let sql = """
            SELECT irp.instrument_id,
                   i.instrument_name,
                   COALESCE(i.ticker_symbol, i.instrument_name) as code,
                   irp.computed_sri,
                   irp.override_sri,
                   irp.computed_liquidity_tier,
                   irp.override_liquidity_tier,
                   irp.override_reason,
                   irp.override_by,
                   irp.override_expires_at,
                   irp.mapping_version
              FROM InstrumentRiskProfile irp
              JOIN Instruments i ON i.instrument_id = irp.instrument_id
             WHERE irp.manual_override = 1
               AND i.is_deleted = 0
             ORDER BY i.instrument_name COLLATE NOCASE
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "Instrument #\(id)"
                let code = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? name
                let computedSRI = Int(sqlite3_column_int(stmt, 3))
                let overrideSRI = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
                let computedLiq = Int(sqlite3_column_int(stmt, 5))
                let overrideLiq = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
                let reason = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let by = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let expires = sqlite3_column_text(stmt, 9).flatMap { iso.date(from: String(cString: $0)) }
                let mapVer = sqlite3_column_text(stmt, 10).map { String(cString: $0) }

                rows.append(
                    RiskOverrideRow(
                        id: id,
                        instrumentName: name,
                        instrumentCode: code,
                        computedSRI: computedSRI,
                        overrideSRI: overrideSRI,
                        computedLiquidityTier: computedLiq,
                        overrideLiquidityTier: overrideLiq,
                        overrideReason: reason,
                        overrideBy: by,
                        overrideExpiresAt: expires,
                        mappingVersion: mapVer
                    )
                )
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }
}
