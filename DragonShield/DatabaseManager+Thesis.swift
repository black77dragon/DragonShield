import Foundation
import SQLite3

extension DatabaseManager {
    struct PortfolioThesisLinkDetail: Identifiable, Hashable {
        let link: PortfolioThesisLink
        let thesisName: String
        let thesisSummary: String?
        var id: Int { link.id }
    }

    struct ThesisExposureSnapshot {
        let portfolioThesisId: Int
        let totalPct: Double
        let sleeveActualPct: [Int: Double]
    }

    // MARK: - Thesis Definitions

    func listThesisDefinitions() -> [ThesisDefinition] {
        guard let db, tableExists("ThesisDefinition") else { return [] }
        let sql = "SELECT thesis_def_id, name, summary_core_thesis, default_scoring_rules, created_at, updated_at FROM ThesisDefinition ORDER BY name"
        var stmt: OpaquePointer?
        var items: [ThesisDefinition] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readThesisDefinitionRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func fetchThesisDefinition(id: Int) -> ThesisDefinition? {
        guard let db, tableExists("ThesisDefinition") else { return nil }
        let sql = "SELECT thesis_def_id, name, summary_core_thesis, default_scoring_rules, created_at, updated_at FROM ThesisDefinition WHERE thesis_def_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: ThesisDefinition?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readThesisDefinitionRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    func createThesisDefinition(name: String, summary: String?, scoringRules: String?) -> ThesisDefinition? {
        guard let db, tableExists("ThesisDefinition") else { return nil }
        guard ThesisDefinition.isValidName(name) else { return nil }
        let sql = "INSERT INTO ThesisDefinition (name, summary_core_thesis, default_scoring_rules) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 2, value: summary)
        bindOptionalText(stmt, index: 3, value: scoringRules)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let newId = Int(sqlite3_last_insert_rowid(db))
        return fetchThesisDefinition(id: newId)
    }

    @discardableResult
    func updateThesisDefinition(id: Int, name: String, summary: String?, scoringRules: String?) -> Bool {
        guard let db, tableExists("ThesisDefinition") else { return false }
        guard ThesisDefinition.isValidName(name) else { return false }
        let sql = "UPDATE ThesisDefinition SET name = ?, summary_core_thesis = ?, default_scoring_rules = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE thesis_def_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 2, value: summary)
        bindOptionalText(stmt, index: 3, value: scoringRules)
        sqlite3_bind_int(stmt, 4, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    @discardableResult
    func deleteThesisDefinition(id: Int) -> Bool {
        guard let db, tableExists("ThesisDefinition") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM ThesisDefinition WHERE thesis_def_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    // MARK: - Sections & Bullets

    func listThesisSections(thesisDefId: Int) -> [ThesisSection] {
        guard let db, tableExists("ThesisSection") else { return [] }
        let sql = "SELECT section_id, thesis_def_id, sort_order, headline, description, rag_default, score_default FROM ThesisSection WHERE thesis_def_id = ? ORDER BY sort_order, section_id"
        var stmt: OpaquePointer?
        var items: [ThesisSection] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(thesisDefId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readThesisSectionRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func upsertThesisSection(_ section: ThesisSection) -> ThesisSection? {
        guard let db, tableExists("ThesisSection") else { return nil }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if section.id == 0 {
            let sql = "INSERT INTO ThesisSection (thesis_def_id, sort_order, headline, description, rag_default, score_default) VALUES (?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_int(stmt, 1, Int32(section.thesisDefId))
            sqlite3_bind_int(stmt, 2, Int32(section.sortOrder))
            sqlite3_bind_text(stmt, 3, section.headline, -1, SQLITE_TRANSIENT)
            bindOptionalText(stmt, index: 4, value: section.description)
            bindOptionalText(stmt, index: 5, value: section.ragDefault?.rawValue)
            bindOptionalInt(stmt, index: 6, value: section.scoreDefault)
            let ok = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            guard ok else { return nil }
            let newId = Int(sqlite3_last_insert_rowid(db))
            return fetchThesisSection(id: newId)
        }

        let sql = "UPDATE ThesisSection SET sort_order = ?, headline = ?, description = ?, rag_default = ?, score_default = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE section_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_int(stmt, 1, Int32(section.sortOrder))
        sqlite3_bind_text(stmt, 2, section.headline, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 3, value: section.description)
        bindOptionalText(stmt, index: 4, value: section.ragDefault?.rawValue)
        bindOptionalInt(stmt, index: 5, value: section.scoreDefault)
        sqlite3_bind_int(stmt, 6, Int32(section.id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok ? fetchThesisSection(id: section.id) : nil
    }

    @discardableResult
    func deleteThesisSection(id: Int) -> Bool {
        guard let db, tableExists("ThesisSection") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM ThesisSection WHERE section_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    private func fetchThesisSection(id: Int) -> ThesisSection? {
        guard let db, tableExists("ThesisSection") else { return nil }
        let sql = "SELECT section_id, thesis_def_id, sort_order, headline, description, rag_default, score_default FROM ThesisSection WHERE section_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: ThesisSection?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readThesisSectionRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    func listThesisBullets(sectionId: Int) -> [ThesisBullet] {
        guard let db, tableExists("ThesisBullet") else { return [] }
        let sql = "SELECT bullet_id, section_id, sort_order, text, type, linked_metrics_json, linked_evidence_json FROM ThesisBullet WHERE section_id = ? ORDER BY sort_order, bullet_id"
        var stmt: OpaquePointer?
        var items: [ThesisBullet] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(sectionId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readThesisBulletRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func upsertThesisBullet(_ bullet: ThesisBullet) -> ThesisBullet? {
        guard let db, tableExists("ThesisBullet") else { return nil }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if bullet.id == 0 {
            let sql = "INSERT INTO ThesisBullet (section_id, sort_order, text, type, linked_metrics_json, linked_evidence_json) VALUES (?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_int(stmt, 1, Int32(bullet.sectionId))
            sqlite3_bind_int(stmt, 2, Int32(bullet.sortOrder))
            sqlite3_bind_text(stmt, 3, bullet.text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, bullet.type.rawValue, -1, SQLITE_TRANSIENT)
            bindOptionalText(stmt, index: 5, value: encodeJSONStringArray(bullet.linkedMetrics))
            bindOptionalText(stmt, index: 6, value: encodeJSONStringArray(bullet.linkedEvidence))
            let ok = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            guard ok else { return nil }
            let newId = Int(sqlite3_last_insert_rowid(db))
            return fetchThesisBullet(id: newId)
        }

        let sql = "UPDATE ThesisBullet SET sort_order = ?, text = ?, type = ?, linked_metrics_json = ?, linked_evidence_json = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE bullet_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_int(stmt, 1, Int32(bullet.sortOrder))
        sqlite3_bind_text(stmt, 2, bullet.text, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, bullet.type.rawValue, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 4, value: encodeJSONStringArray(bullet.linkedMetrics))
        bindOptionalText(stmt, index: 5, value: encodeJSONStringArray(bullet.linkedEvidence))
        sqlite3_bind_int(stmt, 6, Int32(bullet.id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok ? fetchThesisBullet(id: bullet.id) : nil
    }

    @discardableResult
    func deleteThesisBullet(id: Int) -> Bool {
        guard let db, tableExists("ThesisBullet") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM ThesisBullet WHERE bullet_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    @discardableResult
    func deleteThesisBullets(sectionId: Int) -> Bool {
        guard let db, tableExists("ThesisBullet") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM ThesisBullet WHERE section_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(sectionId))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    private func fetchThesisBullet(id: Int) -> ThesisBullet? {
        guard let db, tableExists("ThesisBullet") else { return nil }
        let sql = "SELECT bullet_id, section_id, sort_order, text, type, linked_metrics_json, linked_evidence_json FROM ThesisBullet WHERE bullet_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: ThesisBullet?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readThesisBulletRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    // MARK: - Drivers & Risks

    func listThesisDrivers(thesisDefId: Int) -> [ThesisDriverDefinition] {
        guard let db, tableExists("ThesisDriverDefinition") else { return [] }
        let sql = "SELECT driver_def_id, thesis_def_id, code, name, definition, review_question, weight, sort_order FROM ThesisDriverDefinition WHERE thesis_def_id = ? ORDER BY sort_order, driver_def_id"
        var stmt: OpaquePointer?
        var items: [ThesisDriverDefinition] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(thesisDefId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readThesisDriverRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func upsertThesisDriver(_ driver: ThesisDriverDefinition) -> ThesisDriverDefinition? {
        guard let db, tableExists("ThesisDriverDefinition") else { return nil }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if driver.id == 0 {
            let sql = "INSERT INTO ThesisDriverDefinition (thesis_def_id, code, name, definition, review_question, weight, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_int(stmt, 1, Int32(driver.thesisDefId))
            sqlite3_bind_text(stmt, 2, driver.code, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, driver.name, -1, SQLITE_TRANSIENT)
            bindOptionalText(stmt, index: 4, value: driver.definition)
            bindOptionalText(stmt, index: 5, value: driver.reviewQuestion)
            bindOptionalDouble(stmt, index: 6, value: driver.weight)
            sqlite3_bind_int(stmt, 7, Int32(driver.sortOrder))
            let ok = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            guard ok else { return nil }
            let newId = Int(sqlite3_last_insert_rowid(db))
            return fetchThesisDriver(id: newId)
        }

        let sql = "UPDATE ThesisDriverDefinition SET code = ?, name = ?, definition = ?, review_question = ?, weight = ?, sort_order = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE driver_def_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, driver.code, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, driver.name, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 3, value: driver.definition)
        bindOptionalText(stmt, index: 4, value: driver.reviewQuestion)
        bindOptionalDouble(stmt, index: 5, value: driver.weight)
        sqlite3_bind_int(stmt, 6, Int32(driver.sortOrder))
        sqlite3_bind_int(stmt, 7, Int32(driver.id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok ? fetchThesisDriver(id: driver.id) : nil
    }

    @discardableResult
    func deleteThesisDriver(id: Int) -> Bool {
        guard let db, tableExists("ThesisDriverDefinition") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM ThesisDriverDefinition WHERE driver_def_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    private func fetchThesisDriver(id: Int) -> ThesisDriverDefinition? {
        guard let db, tableExists("ThesisDriverDefinition") else { return nil }
        let sql = "SELECT driver_def_id, thesis_def_id, code, name, definition, review_question, weight, sort_order FROM ThesisDriverDefinition WHERE driver_def_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: ThesisDriverDefinition?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readThesisDriverRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    func listThesisRisks(thesisDefId: Int) -> [ThesisRiskDefinition] {
        guard let db, tableExists("ThesisRiskDefinition") else { return [] }
        let sql = "SELECT risk_def_id, thesis_def_id, name, category, what_worsens, what_improves, mitigations, weight, sort_order FROM ThesisRiskDefinition WHERE thesis_def_id = ? ORDER BY sort_order, risk_def_id"
        var stmt: OpaquePointer?
        var items: [ThesisRiskDefinition] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(thesisDefId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readThesisRiskRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func upsertThesisRisk(_ risk: ThesisRiskDefinition) -> ThesisRiskDefinition? {
        guard let db, tableExists("ThesisRiskDefinition") else { return nil }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if risk.id == 0 {
            let sql = "INSERT INTO ThesisRiskDefinition (thesis_def_id, name, category, what_worsens, what_improves, mitigations, weight, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_int(stmt, 1, Int32(risk.thesisDefId))
            sqlite3_bind_text(stmt, 2, risk.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, risk.category, -1, SQLITE_TRANSIENT)
            bindOptionalText(stmt, index: 4, value: risk.whatWorsens)
            bindOptionalText(stmt, index: 5, value: risk.whatImproves)
            bindOptionalText(stmt, index: 6, value: risk.mitigations)
            bindOptionalDouble(stmt, index: 7, value: risk.weight)
            sqlite3_bind_int(stmt, 8, Int32(risk.sortOrder))
            let ok = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            guard ok else { return nil }
            let newId = Int(sqlite3_last_insert_rowid(db))
            return fetchThesisRisk(id: newId)
        }

        let sql = "UPDATE ThesisRiskDefinition SET name = ?, category = ?, what_worsens = ?, what_improves = ?, mitigations = ?, weight = ?, sort_order = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE risk_def_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, risk.name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, risk.category, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 3, value: risk.whatWorsens)
        bindOptionalText(stmt, index: 4, value: risk.whatImproves)
        bindOptionalText(stmt, index: 5, value: risk.mitigations)
        bindOptionalDouble(stmt, index: 6, value: risk.weight)
        sqlite3_bind_int(stmt, 7, Int32(risk.sortOrder))
        sqlite3_bind_int(stmt, 8, Int32(risk.id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok ? fetchThesisRisk(id: risk.id) : nil
    }

    @discardableResult
    func deleteThesisRisk(id: Int) -> Bool {
        guard let db, tableExists("ThesisRiskDefinition") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM ThesisRiskDefinition WHERE risk_def_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    private func fetchThesisRisk(id: Int) -> ThesisRiskDefinition? {
        guard let db, tableExists("ThesisRiskDefinition") else { return nil }
        let sql = "SELECT risk_def_id, thesis_def_id, name, category, what_worsens, what_improves, mitigations, weight, sort_order FROM ThesisRiskDefinition WHERE risk_def_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: ThesisRiskDefinition?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readThesisRiskRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    // MARK: - Portfolio Thesis Links

    func listPortfolioThesisLinks(themeId: Int) -> [PortfolioThesisLink] {
        guard let db, tableExists("PortfolioThesisLink") else { return [] }
        let sql = "SELECT portfolio_thesis_id, theme_id, thesis_def_id, status, is_primary, review_frequency, notes, created_at, updated_at FROM PortfolioThesisLink WHERE theme_id = ? ORDER BY is_primary DESC, portfolio_thesis_id"
        var stmt: OpaquePointer?
        var items: [PortfolioThesisLink] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readPortfolioThesisLinkRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func listPortfolioThesisLinkDetails(themeId: Int) -> [PortfolioThesisLinkDetail] {
        guard let db, tableExists("PortfolioThesisLink"), tableExists("ThesisDefinition") else { return [] }
        let sql = """
            SELECT l.portfolio_thesis_id, l.theme_id, l.thesis_def_id, l.status, l.is_primary, l.review_frequency, l.notes, l.created_at, l.updated_at,
                   d.name, d.summary_core_thesis
              FROM PortfolioThesisLink l
              JOIN ThesisDefinition d ON d.thesis_def_id = l.thesis_def_id
             WHERE l.theme_id = ?
             ORDER BY l.is_primary DESC, l.portfolio_thesis_id
        """
        var stmt: OpaquePointer?
        var items: [PortfolioThesisLinkDetail] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let link = readPortfolioThesisLinkRow(stmt)
                let name = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? ""
                let summary = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                items.append(PortfolioThesisLinkDetail(link: link, thesisName: name, thesisSummary: summary))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func createPortfolioThesisLink(themeId: Int, thesisDefId: Int, status: ThesisLinkStatus = .active, isPrimary: Bool = false, reviewFrequency: String = "weekly", notes: String? = nil) -> PortfolioThesisLink? {
        guard let db, tableExists("PortfolioThesisLink") else { return nil }
        let sql = "INSERT INTO PortfolioThesisLink (theme_id, thesis_def_id, status, is_primary, review_frequency, notes) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        sqlite3_bind_int(stmt, 2, Int32(thesisDefId))
        sqlite3_bind_text(stmt, 3, status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, isPrimary ? 1 : 0)
        sqlite3_bind_text(stmt, 5, reviewFrequency, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 6, value: notes)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let newId = Int(sqlite3_last_insert_rowid(db))
        return fetchPortfolioThesisLink(id: newId)
    }

    @discardableResult
    func updatePortfolioThesisLink(_ link: PortfolioThesisLink) -> Bool {
        guard let db, tableExists("PortfolioThesisLink") else { return false }
        let sql = "UPDATE PortfolioThesisLink SET status = ?, is_primary = ?, review_frequency = ?, notes = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE portfolio_thesis_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, link.status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, link.isPrimary ? 1 : 0)
        sqlite3_bind_text(stmt, 3, link.reviewFrequency, -1, SQLITE_TRANSIENT)
        bindOptionalText(stmt, index: 4, value: link.notes)
        sqlite3_bind_int(stmt, 5, Int32(link.id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    @discardableResult
    func deletePortfolioThesisLink(id: Int) -> Bool {
        guard let db, tableExists("PortfolioThesisLink") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM PortfolioThesisLink WHERE portfolio_thesis_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    private func fetchPortfolioThesisLink(id: Int) -> PortfolioThesisLink? {
        guard let db, tableExists("PortfolioThesisLink") else { return nil }
        let sql = "SELECT portfolio_thesis_id, theme_id, thesis_def_id, status, is_primary, review_frequency, notes, created_at, updated_at FROM PortfolioThesisLink WHERE portfolio_thesis_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: PortfolioThesisLink?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readPortfolioThesisLinkRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    // MARK: - Sleeves & Exposure Rules

    func listPortfolioThesisSleeves(portfolioThesisId: Int) -> [PortfolioThesisSleeve] {
        guard let db, tableExists("PortfolioThesisSleeve") else { return [] }
        let sql = "SELECT sleeve_id, portfolio_thesis_id, name, target_min_pct, target_max_pct, max_pct, rule_text, sort_order FROM PortfolioThesisSleeve WHERE portfolio_thesis_id = ? ORDER BY sort_order, sleeve_id"
        var stmt: OpaquePointer?
        var items: [PortfolioThesisSleeve] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(portfolioThesisId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readPortfolioThesisSleeveRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func upsertPortfolioThesisSleeve(_ sleeve: PortfolioThesisSleeve) -> PortfolioThesisSleeve? {
        guard let db, tableExists("PortfolioThesisSleeve") else { return nil }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if sleeve.id == 0 {
            let sql = "INSERT INTO PortfolioThesisSleeve (portfolio_thesis_id, name, target_min_pct, target_max_pct, max_pct, rule_text, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_int(stmt, 1, Int32(sleeve.portfolioThesisId))
            sqlite3_bind_text(stmt, 2, sleeve.name, -1, SQLITE_TRANSIENT)
            bindOptionalDouble(stmt, index: 3, value: sleeve.targetMinPct)
            bindOptionalDouble(stmt, index: 4, value: sleeve.targetMaxPct)
            bindOptionalDouble(stmt, index: 5, value: sleeve.maxPct)
            bindOptionalText(stmt, index: 6, value: sleeve.ruleText)
            sqlite3_bind_int(stmt, 7, Int32(sleeve.sortOrder))
            let ok = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            guard ok else { return nil }
            let newId = Int(sqlite3_last_insert_rowid(db))
            return fetchPortfolioThesisSleeve(id: newId)
        }

        let sql = "UPDATE PortfolioThesisSleeve SET name = ?, target_min_pct = ?, target_max_pct = ?, max_pct = ?, rule_text = ?, sort_order = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE sleeve_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, sleeve.name, -1, SQLITE_TRANSIENT)
        bindOptionalDouble(stmt, index: 2, value: sleeve.targetMinPct)
        bindOptionalDouble(stmt, index: 3, value: sleeve.targetMaxPct)
        bindOptionalDouble(stmt, index: 4, value: sleeve.maxPct)
        bindOptionalText(stmt, index: 5, value: sleeve.ruleText)
        sqlite3_bind_int(stmt, 6, Int32(sleeve.sortOrder))
        sqlite3_bind_int(stmt, 7, Int32(sleeve.id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok ? fetchPortfolioThesisSleeve(id: sleeve.id) : nil
    }

    @discardableResult
    func deletePortfolioThesisSleeve(id: Int) -> Bool {
        guard let db, tableExists("PortfolioThesisSleeve") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM PortfolioThesisSleeve WHERE sleeve_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    private func fetchPortfolioThesisSleeve(id: Int) -> PortfolioThesisSleeve? {
        guard let db, tableExists("PortfolioThesisSleeve") else { return nil }
        let sql = "SELECT sleeve_id, portfolio_thesis_id, name, target_min_pct, target_max_pct, max_pct, rule_text, sort_order FROM PortfolioThesisSleeve WHERE sleeve_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: PortfolioThesisSleeve?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readPortfolioThesisSleeveRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    func listPortfolioThesisExposureRules(portfolioThesisId: Int) -> [PortfolioThesisExposureRule] {
        guard let db, tableExists("PortfolioThesisExposureRule") else { return [] }
        let sql = "SELECT exposure_rule_id, portfolio_thesis_id, sleeve_id, rule_type, rule_value, weighting, effective_from, effective_to, is_active FROM PortfolioThesisExposureRule WHERE portfolio_thesis_id = ? ORDER BY exposure_rule_id"
        var stmt: OpaquePointer?
        var items: [PortfolioThesisExposureRule] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(portfolioThesisId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readPortfolioThesisExposureRuleRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func upsertPortfolioThesisExposureRule(_ rule: PortfolioThesisExposureRule) -> PortfolioThesisExposureRule? {
        guard let db, tableExists("PortfolioThesisExposureRule") else { return nil }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if rule.id == 0 {
            let sql = "INSERT INTO PortfolioThesisExposureRule (portfolio_thesis_id, sleeve_id, rule_type, rule_value, weighting, effective_from, effective_to, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_int(stmt, 1, Int32(rule.portfolioThesisId))
            bindOptionalInt(stmt, index: 2, value: rule.sleeveId)
            sqlite3_bind_text(stmt, 3, rule.ruleType.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, rule.ruleValue, -1, SQLITE_TRANSIENT)
            bindOptionalDouble(stmt, index: 5, value: rule.weighting)
            bindOptionalText(stmt, index: 6, value: rule.effectiveFrom)
            bindOptionalText(stmt, index: 7, value: rule.effectiveTo)
            sqlite3_bind_int(stmt, 8, rule.isActive ? 1 : 0)
            let ok = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            guard ok else { return nil }
            let newId = Int(sqlite3_last_insert_rowid(db))
            return fetchPortfolioThesisExposureRule(id: newId)
        }

        let sql = "UPDATE PortfolioThesisExposureRule SET sleeve_id = ?, rule_type = ?, rule_value = ?, weighting = ?, effective_from = ?, effective_to = ?, is_active = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE exposure_rule_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        bindOptionalInt(stmt, index: 1, value: rule.sleeveId)
        sqlite3_bind_text(stmt, 2, rule.ruleType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, rule.ruleValue, -1, SQLITE_TRANSIENT)
        bindOptionalDouble(stmt, index: 4, value: rule.weighting)
        bindOptionalText(stmt, index: 5, value: rule.effectiveFrom)
        bindOptionalText(stmt, index: 6, value: rule.effectiveTo)
        sqlite3_bind_int(stmt, 7, rule.isActive ? 1 : 0)
        sqlite3_bind_int(stmt, 8, Int32(rule.id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok ? fetchPortfolioThesisExposureRule(id: rule.id) : nil
    }

    @discardableResult
    func deletePortfolioThesisExposureRule(id: Int) -> Bool {
        guard let db, tableExists("PortfolioThesisExposureRule") else { return false }
        var stmt: OpaquePointer?
        let sql = "DELETE FROM PortfolioThesisExposureRule WHERE exposure_rule_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    private func fetchPortfolioThesisExposureRule(id: Int) -> PortfolioThesisExposureRule? {
        guard let db, tableExists("PortfolioThesisExposureRule") else { return nil }
        let sql = "SELECT exposure_rule_id, portfolio_thesis_id, sleeve_id, rule_type, rule_value, weighting, effective_from, effective_to, is_active FROM PortfolioThesisExposureRule WHERE exposure_rule_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: PortfolioThesisExposureRule?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readPortfolioThesisExposureRuleRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    // MARK: - Weekly Assessments

    func fetchPortfolioThesisWeeklyAssessment(weeklyChecklistId: Int, portfolioThesisId: Int) -> PortfolioThesisWeeklyAssessment? {
        guard let db, tableExists("PortfolioThesisWeeklyAssessment") else { return nil }
        let sql = "SELECT assessment_id, weekly_checklist_id, portfolio_thesis_id, verdict, rag, driver_strength_score, risk_pressure_score, top_changes_text, actions_summary, created_at, updated_at FROM PortfolioThesisWeeklyAssessment WHERE weekly_checklist_id = ? AND portfolio_thesis_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var item: PortfolioThesisWeeklyAssessment?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(weeklyChecklistId))
            sqlite3_bind_int(stmt, 2, Int32(portfolioThesisId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readPortfolioThesisAssessmentRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    func fetchLatestPortfolioThesisWeeklyAssessment(portfolioThesisId: Int, beforeWeekStartDate: Date) -> PortfolioThesisWeeklyAssessment? {
        guard let db, tableExists("PortfolioThesisWeeklyAssessment"), tableExists("WeeklyChecklist") else { return nil }
        let sql = """
            SELECT a.assessment_id, a.weekly_checklist_id, a.portfolio_thesis_id, a.verdict, a.rag,
                   a.driver_strength_score, a.risk_pressure_score, a.top_changes_text, a.actions_summary, a.created_at, a.updated_at
              FROM PortfolioThesisWeeklyAssessment a
              JOIN WeeklyChecklist w ON w.id = a.weekly_checklist_id
             WHERE a.portfolio_thesis_id = ? AND w.week_start_date < ?
             ORDER BY w.week_start_date DESC
             LIMIT 1
        """
        var stmt: OpaquePointer?
        var item: PortfolioThesisWeeklyAssessment?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(portfolioThesisId))
            let dateStr = DateFormatter.iso8601DateOnly.string(from: beforeWeekStartDate)
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 2, dateStr, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                item = readPortfolioThesisAssessmentRow(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return item
    }

    func fetchDriverAssessmentItems(assessmentId: Int) -> [DriverWeeklyAssessmentItem] {
        guard let db, tableExists("DriverWeeklyAssessmentItem") else { return [] }
        let sql = "SELECT assessment_item_id, assessment_id, driver_def_id, rag, score, delta_vs_prior, change_sentence, evidence_refs_json, implication, sort_order FROM DriverWeeklyAssessmentItem WHERE assessment_id = ? ORDER BY sort_order, assessment_item_id"
        var stmt: OpaquePointer?
        var items: [DriverWeeklyAssessmentItem] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(assessmentId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readDriverAssessmentRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    func fetchRiskAssessmentItems(assessmentId: Int) -> [RiskWeeklyAssessmentItem] {
        guard let db, tableExists("RiskWeeklyAssessmentItem") else { return [] }
        let sql = "SELECT assessment_item_id, assessment_id, risk_def_id, rag, score, delta_vs_prior, change_sentence, evidence_refs_json, thesis_impact, recommended_action, sort_order FROM RiskWeeklyAssessmentItem WHERE assessment_id = ? ORDER BY sort_order, assessment_item_id"
        var stmt: OpaquePointer?
        var items: [RiskWeeklyAssessmentItem] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(assessmentId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                items.append(readRiskAssessmentRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    @discardableResult
    func upsertPortfolioThesisWeeklyAssessment(
        weeklyChecklistId: Int,
        portfolioThesisId: Int,
        verdict: ThesisVerdict?,
        rag: ThesisRAG?,
        driverStrengthScore: Double?,
        riskPressureScore: Double?,
        topChangesText: String?,
        actionsSummary: String?,
        driverItems: [DriverWeeklyAssessmentItem],
        riskItems: [RiskWeeklyAssessmentItem]
    ) -> Bool {
        guard let db, tableExists("PortfolioThesisWeeklyAssessment") else { return false }
        let existingId = fetchPortfolioThesisWeeklyAssessment(weeklyChecklistId: weeklyChecklistId, portfolioThesisId: portfolioThesisId)?.id
        let begin = sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil) == SQLITE_OK
        if !begin { return false }

        let assessmentId: Int
        if let existingId {
            let sql = """
                UPDATE PortfolioThesisWeeklyAssessment
                   SET verdict = ?, rag = ?, driver_strength_score = ?, risk_pressure_score = ?, top_changes_text = ?, actions_summary = ?,
                       updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
                 WHERE assessment_id = ?
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
            bindOptionalText(stmt, index: 1, value: verdict?.rawValue)
            bindOptionalText(stmt, index: 2, value: rag?.rawValue)
            bindOptionalDouble(stmt, index: 3, value: driverStrengthScore)
            bindOptionalDouble(stmt, index: 4, value: riskPressureScore)
            bindOptionalText(stmt, index: 5, value: topChangesText)
            bindOptionalText(stmt, index: 6, value: actionsSummary)
            sqlite3_bind_int(stmt, 7, Int32(existingId))
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return false
            }
            sqlite3_finalize(stmt)
            assessmentId = existingId
        } else {
            let sql = """
                INSERT INTO PortfolioThesisWeeklyAssessment
                    (weekly_checklist_id, portfolio_thesis_id, verdict, rag, driver_strength_score, risk_pressure_score, top_changes_text, actions_summary)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
            sqlite3_bind_int(stmt, 1, Int32(weeklyChecklistId))
            sqlite3_bind_int(stmt, 2, Int32(portfolioThesisId))
            bindOptionalText(stmt, index: 3, value: verdict?.rawValue)
            bindOptionalText(stmt, index: 4, value: rag?.rawValue)
            bindOptionalDouble(stmt, index: 5, value: driverStrengthScore)
            bindOptionalDouble(stmt, index: 6, value: riskPressureScore)
            bindOptionalText(stmt, index: 7, value: topChangesText)
            bindOptionalText(stmt, index: 8, value: actionsSummary)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                sqlite3_finalize(stmt)
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return false
            }
            sqlite3_finalize(stmt)
            assessmentId = Int(sqlite3_last_insert_rowid(db))
        }

        let deleteDriverSql = "DELETE FROM DriverWeeklyAssessmentItem WHERE assessment_id = ?"
        var deleteStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteDriverSql, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStmt, 1, Int32(assessmentId))
            _ = sqlite3_step(deleteStmt)
        }
        sqlite3_finalize(deleteStmt)

        let deleteRiskSql = "DELETE FROM RiskWeeklyAssessmentItem WHERE assessment_id = ?"
        deleteStmt = nil
        if sqlite3_prepare_v2(db, deleteRiskSql, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStmt, 1, Int32(assessmentId))
            _ = sqlite3_step(deleteStmt)
        }
        sqlite3_finalize(deleteStmt)

        let insertDriverSql = """
            INSERT INTO DriverWeeklyAssessmentItem
                (assessment_id, driver_def_id, rag, score, delta_vs_prior, change_sentence, evidence_refs_json, implication, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        for item in driverItems {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertDriverSql, -1, &stmt, nil) == SQLITE_OK else { continue }
            sqlite3_bind_int(stmt, 1, Int32(assessmentId))
            sqlite3_bind_int(stmt, 2, Int32(item.driverDefId))
            bindOptionalText(stmt, index: 3, value: item.rag?.rawValue)
            bindOptionalInt(stmt, index: 4, value: item.score)
            bindOptionalInt(stmt, index: 5, value: item.deltaVsPrior)
            bindOptionalText(stmt, index: 6, value: item.changeSentence)
            bindOptionalText(stmt, index: 7, value: encodeJSONStringArray(item.evidenceRefs))
            bindOptionalText(stmt, index: 8, value: item.implication?.rawValue)
            sqlite3_bind_int(stmt, 9, Int32(item.sortOrder))
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }

        let insertRiskSql = """
            INSERT INTO RiskWeeklyAssessmentItem
                (assessment_id, risk_def_id, rag, score, delta_vs_prior, change_sentence, evidence_refs_json, thesis_impact, recommended_action, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        for item in riskItems {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertRiskSql, -1, &stmt, nil) == SQLITE_OK else { continue }
            sqlite3_bind_int(stmt, 1, Int32(assessmentId))
            sqlite3_bind_int(stmt, 2, Int32(item.riskDefId))
            bindOptionalText(stmt, index: 3, value: item.rag?.rawValue)
            bindOptionalInt(stmt, index: 4, value: item.score)
            bindOptionalInt(stmt, index: 5, value: item.deltaVsPrior)
            bindOptionalText(stmt, index: 6, value: item.changeSentence)
            bindOptionalText(stmt, index: 7, value: encodeJSONStringArray(item.evidenceRefs))
            bindOptionalText(stmt, index: 8, value: item.thesisImpact?.rawValue)
            bindOptionalText(stmt, index: 9, value: item.recommendedAction?.rawValue)
            sqlite3_bind_int(stmt, 10, Int32(item.sortOrder))
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        let committed = sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK
        if !committed {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
        }
        return committed
    }

    // MARK: - Exposure Computation

    func computeThesisExposure(themeId: Int, portfolioThesisId: Int) -> ThesisExposureSnapshot? {
        let rules = listPortfolioThesisExposureRules(portfolioThesisId: portfolioThesisId).filter { $0.isActive }
        guard !rules.isEmpty else { return ThesisExposureSnapshot(portfolioThesisId: portfolioThesisId, totalPct: 0, sleeveActualPct: [:]) }
        let fxService = FXConversionService(dbManager: self)
        let valuationService = PortfolioValuationService(dbManager: self, fxService: fxService)
        let snapshot = valuationService.snapshot(themeId: themeId)
        let totalValue = snapshot.includedTotalValueBase
        guard totalValue > 0 else { return ThesisExposureSnapshot(portfolioThesisId: portfolioThesisId, totalPct: 0, sleeveActualPct: [:]) }

        let valueByInstrument = snapshot.rows.reduce(into: [Int: Double]()) { result, row in
            guard row.status == .ok, row.userTargetPct > 0 else { return }
            result[row.instrumentId] = row.currentValueBase
        }

        let instrumentMeta = fetchInstrumentMeta(instrumentIds: Array(valueByInstrument.keys))
        var totalMatchedValue: Double = 0
        var sleeveTotals: [Int: Double] = [:]
        let now = Date()
        for rule in rules {
            guard isRuleActive(rule, now: now) else { continue }
            let matching = matchInstrumentIds(rule: rule, meta: instrumentMeta)
            if matching.isEmpty { continue }
            let weight = max(0, rule.weighting ?? 1)
            let matchedValue = matching.reduce(0) { acc, id in
                acc + (valueByInstrument[id] ?? 0)
            } * weight
            totalMatchedValue += matchedValue
            if let sleeveId = rule.sleeveId {
                sleeveTotals[sleeveId, default: 0] += matchedValue
            }
        }
        let totalPct = (totalMatchedValue / totalValue) * 100
        let sleevePct = sleeveTotals.mapValues { ($0 / totalValue) * 100 }
        return ThesisExposureSnapshot(portfolioThesisId: portfolioThesisId, totalPct: totalPct, sleeveActualPct: sleevePct)
    }

    private func isRuleActive(_ rule: PortfolioThesisExposureRule, now: Date) -> Bool {
        if !rule.isActive { return false }
        let formatter = ISO8601DateFormatter()
        if let from = rule.effectiveFrom, let fromDate = formatter.date(from: from), now < fromDate { return false }
        if let to = rule.effectiveTo, let toDate = formatter.date(from: to), now > toDate { return false }
        return true
    }

    private struct InstrumentMeta {
        let instrumentId: Int
        let ticker: String
        let classCode: String
        let className: String
    }

    private func fetchInstrumentMeta(instrumentIds: [Int]) -> [Int: InstrumentMeta] {
        guard let db, tableExists("Instruments"), tableExists("AssetSubClasses"), tableExists("AssetClasses") else { return [:] }
        guard !instrumentIds.isEmpty else { return [:] }
        let placeholders = instrumentIds.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT i.instrument_id, COALESCE(i.ticker_symbol, ''), COALESCE(ac.class_code, ''), COALESCE(ac.class_name, '')
              FROM Instruments i
              JOIN AssetSubClasses sc ON sc.sub_class_id = i.sub_class_id
              JOIN AssetClasses ac ON ac.class_id = sc.class_id
             WHERE i.instrument_id IN (
                 \(placeholders)
             )
        """
        var stmt: OpaquePointer?
        var result: [Int: InstrumentMeta] = [:]
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for (index, id) in instrumentIds.enumerated() {
                sqlite3_bind_int(stmt, Int32(index + 1), Int32(id))
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let instrumentId = Int(sqlite3_column_int(stmt, 0))
                let ticker = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let classCode = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let className = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                result[instrumentId] = InstrumentMeta(instrumentId: instrumentId, ticker: ticker, classCode: classCode, className: className)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func matchInstrumentIds(rule: PortfolioThesisExposureRule, meta: [Int: InstrumentMeta]) -> [Int] {
        switch rule.ruleType {
        case .byTicker:
            let target = rule.ruleValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !target.isEmpty else { return [] }
            return meta.values.filter { $0.ticker.lowercased() == target }.map { $0.instrumentId }
        case .byInstrumentId:
            let trimmed = rule.ruleValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let id = Int(trimmed) else { return [] }
            return meta[id].map { [$0.instrumentId] } ?? []
        case .byAssetClass:
            let target = rule.ruleValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !target.isEmpty else { return [] }
            return meta.values.filter {
                $0.classCode.lowercased() == target || $0.className.lowercased() == target
            }.map { $0.instrumentId }
        case .byTag, .byCustomQuery:
            return []
        }
    }

    // MARK: - Row Readers

    private func readThesisDefinitionRow(_ stmt: OpaquePointer?) -> ThesisDefinition {
        let id = Int(sqlite3_column_int(stmt, 0))
        let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
        let summary = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
        let rules = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let createdAt = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
        let updatedAt = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
        return ThesisDefinition(id: id, name: name, summaryCoreThesis: summary, defaultScoringRules: rules, createdAt: createdAt, updatedAt: updatedAt)
    }

    private func readThesisSectionRow(_ stmt: OpaquePointer?) -> ThesisSection {
        let id = Int(sqlite3_column_int(stmt, 0))
        let thesisDefId = Int(sqlite3_column_int(stmt, 1))
        let sortOrder = Int(sqlite3_column_int(stmt, 2))
        let headline = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let description = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let ragRaw = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let score = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
        return ThesisSection(id: id, thesisDefId: thesisDefId, sortOrder: sortOrder, headline: headline, description: description, ragDefault: ragRaw.flatMap { ThesisRAG(rawValue: $0) }, scoreDefault: score)
    }

    private func readThesisBulletRow(_ stmt: OpaquePointer?) -> ThesisBullet {
        let id = Int(sqlite3_column_int(stmt, 0))
        let sectionId = Int(sqlite3_column_int(stmt, 1))
        let sortOrder = Int(sqlite3_column_int(stmt, 2))
        let text = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let typeRaw = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ThesisBulletType.claim.rawValue
        let metrics = decodeJSONStringArray(sqlite3_column_text(stmt, 5).map { String(cString: $0) })
        let evidence = decodeJSONStringArray(sqlite3_column_text(stmt, 6).map { String(cString: $0) })
        return ThesisBullet(id: id, sectionId: sectionId, sortOrder: sortOrder, text: text, type: ThesisBulletType(rawValue: typeRaw) ?? .claim, linkedMetrics: metrics, linkedEvidence: evidence)
    }

    private func readThesisDriverRow(_ stmt: OpaquePointer?) -> ThesisDriverDefinition {
        let id = Int(sqlite3_column_int(stmt, 0))
        let thesisDefId = Int(sqlite3_column_int(stmt, 1))
        let code = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let name = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let definition = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let reviewQuestion = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let weight = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 6)
        let sortOrder = Int(sqlite3_column_int(stmt, 7))
        return ThesisDriverDefinition(id: id, thesisDefId: thesisDefId, code: code, name: name, definition: definition, reviewQuestion: reviewQuestion, weight: weight, sortOrder: sortOrder)
    }

    private func readThesisRiskRow(_ stmt: OpaquePointer?) -> ThesisRiskDefinition {
        let id = Int(sqlite3_column_int(stmt, 0))
        let thesisDefId = Int(sqlite3_column_int(stmt, 1))
        let name = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let category = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "market"
        let worsens = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let improves = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let mitigations = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let weight = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 7)
        let sortOrder = Int(sqlite3_column_int(stmt, 8))
        return ThesisRiskDefinition(id: id, thesisDefId: thesisDefId, name: name, category: category, whatWorsens: worsens, whatImproves: improves, mitigations: mitigations, weight: weight, sortOrder: sortOrder)
    }

    private func readPortfolioThesisLinkRow(_ stmt: OpaquePointer?) -> PortfolioThesisLink {
        let id = Int(sqlite3_column_int(stmt, 0))
        let themeId = Int(sqlite3_column_int(stmt, 1))
        let thesisDefId = Int(sqlite3_column_int(stmt, 2))
        let statusRaw = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ThesisLinkStatus.active.rawValue
        let isPrimary = sqlite3_column_int(stmt, 4) == 1
        let reviewFrequency = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "weekly"
        let notes = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let createdAt = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? ""
        let updatedAt = sqlite3_column_text(stmt, 8).map { String(cString: $0) } ?? ""
        return PortfolioThesisLink(id: id, themeId: themeId, thesisDefId: thesisDefId, status: ThesisLinkStatus(rawValue: statusRaw) ?? .active, isPrimary: isPrimary, reviewFrequency: reviewFrequency, notes: notes, createdAt: createdAt, updatedAt: updatedAt)
    }

    private func readPortfolioThesisSleeveRow(_ stmt: OpaquePointer?) -> PortfolioThesisSleeve {
        let id = Int(sqlite3_column_int(stmt, 0))
        let portfolioThesisId = Int(sqlite3_column_int(stmt, 1))
        let name = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let minPct = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 3)
        let maxPct = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 4)
        let maxHard = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
        let ruleText = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let sortOrder = Int(sqlite3_column_int(stmt, 7))
        return PortfolioThesisSleeve(id: id, portfolioThesisId: portfolioThesisId, name: name, targetMinPct: minPct, targetMaxPct: maxPct, maxPct: maxHard, ruleText: ruleText, sortOrder: sortOrder)
    }

    private func readPortfolioThesisExposureRuleRow(_ stmt: OpaquePointer?) -> PortfolioThesisExposureRule {
        let id = Int(sqlite3_column_int(stmt, 0))
        let portfolioThesisId = Int(sqlite3_column_int(stmt, 1))
        let sleeveId = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
        let ruleTypeRaw = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ThesisExposureRuleType.byTicker.rawValue
        let ruleValue = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
        let weighting = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
        let effectiveFrom = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let effectiveTo = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let isActive = sqlite3_column_int(stmt, 8) == 1
        return PortfolioThesisExposureRule(id: id, portfolioThesisId: portfolioThesisId, sleeveId: sleeveId, ruleType: ThesisExposureRuleType(rawValue: ruleTypeRaw) ?? .byTicker, ruleValue: ruleValue, weighting: weighting, effectiveFrom: effectiveFrom, effectiveTo: effectiveTo, isActive: isActive)
    }

    private func readPortfolioThesisAssessmentRow(_ stmt: OpaquePointer?) -> PortfolioThesisWeeklyAssessment {
        let id = Int(sqlite3_column_int(stmt, 0))
        let weeklyChecklistId = Int(sqlite3_column_int(stmt, 1))
        let portfolioThesisId = Int(sqlite3_column_int(stmt, 2))
        let verdictRaw = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let ragRaw = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let driverScore = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
        let riskScore = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 6)
        let topChanges = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let actions = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let createdAt = sqlite3_column_text(stmt, 9).map { String(cString: $0) } ?? ""
        let updatedAt = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""
        return PortfolioThesisWeeklyAssessment(
            id: id,
            weeklyChecklistId: weeklyChecklistId,
            portfolioThesisId: portfolioThesisId,
            verdict: verdictRaw.flatMap { ThesisVerdict(rawValue: $0) },
            rag: ragRaw.flatMap { ThesisRAG(rawValue: $0) },
            driverStrengthScore: driverScore,
            riskPressureScore: riskScore,
            topChangesText: topChanges,
            actionsSummary: actions,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func readDriverAssessmentRow(_ stmt: OpaquePointer?) -> DriverWeeklyAssessmentItem {
        let id = Int(sqlite3_column_int(stmt, 0))
        let assessmentId = Int(sqlite3_column_int(stmt, 1))
        let driverDefId = Int(sqlite3_column_int(stmt, 2))
        let ragRaw = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let score = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
        let delta = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
        let changeSentence = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let evidence = decodeJSONStringArray(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
        let implicationRaw = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let sortOrder = Int(sqlite3_column_int(stmt, 9))
        return DriverWeeklyAssessmentItem(id: id, assessmentId: assessmentId, driverDefId: driverDefId, rag: ragRaw.flatMap { ThesisRAG(rawValue: $0) }, score: score, deltaVsPrior: delta, changeSentence: changeSentence, evidenceRefs: evidence, implication: implicationRaw.flatMap { ThesisDriverImplication(rawValue: $0) }, sortOrder: sortOrder)
    }

    private func readRiskAssessmentRow(_ stmt: OpaquePointer?) -> RiskWeeklyAssessmentItem {
        let id = Int(sqlite3_column_int(stmt, 0))
        let assessmentId = Int(sqlite3_column_int(stmt, 1))
        let riskDefId = Int(sqlite3_column_int(stmt, 2))
        let ragRaw = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let score = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
        let delta = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
        let changeSentence = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let evidence = decodeJSONStringArray(sqlite3_column_text(stmt, 7).map { String(cString: $0) })
        let impactRaw = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let actionRaw = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
        let sortOrder = Int(sqlite3_column_int(stmt, 10))
        return RiskWeeklyAssessmentItem(id: id, assessmentId: assessmentId, riskDefId: riskDefId, rag: ragRaw.flatMap { ThesisRAG(rawValue: $0) }, score: score, deltaVsPrior: delta, changeSentence: changeSentence, evidenceRefs: evidence, thesisImpact: impactRaw.flatMap { ThesisRiskImpact(rawValue: $0) }, recommendedAction: actionRaw.flatMap { ThesisRiskAction(rawValue: $0) }, sortOrder: sortOrder)
    }

    // MARK: - Binding Helpers

    private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let value, !value.isEmpty {
            sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalInt(_ stmt: OpaquePointer?, index: Int32, value: Int?) {
        if let value { sqlite3_bind_int(stmt, index, Int32(value)) } else { sqlite3_bind_null(stmt, index) }
    }

    private func bindOptionalDouble(_ stmt: OpaquePointer?, index: Int32, value: Double?) {
        if let value { sqlite3_bind_double(stmt, index, value) } else { sqlite3_bind_null(stmt, index) }
    }

    private func encodeJSONStringArray(_ values: [String]) -> String? {
        guard !values.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(values) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeJSONStringArray(_ value: String?) -> [String] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
