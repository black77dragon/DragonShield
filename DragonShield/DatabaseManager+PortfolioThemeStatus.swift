// DragonShield/DatabaseManager+PortfolioThemeStatus.swift

// MARK: - Version 1.1

// MARK: - History

// - Initial creation: CRUD helpers for PortfolioThemeStatus with default enforcement.
// - 1.1: Return detailed errors and support deletion of unused statuses.

import Foundation

extension DatabaseManager {
    func fetchPortfolioThemeStatuses() -> [PortfolioThemeStatus] {
        PortfolioThemeStatusRepository(connection: databaseConnection).fetchPortfolioThemeStatuses()
    }

    func insertPortfolioThemeStatus(code: String, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        PortfolioThemeStatusRepository(connection: databaseConnection)
            .insertPortfolioThemeStatus(code: code, name: name, colorHex: colorHex, isDefault: isDefault)
    }

    func updatePortfolioThemeStatus(id: Int, name: String, colorHex: String, isDefault: Bool) -> Result<Void, ThemeStatusDBError> {
        PortfolioThemeStatusRepository(connection: databaseConnection)
            .updatePortfolioThemeStatus(id: id, name: name, colorHex: colorHex, isDefault: isDefault)
    }

    func deletePortfolioThemeStatus(id: Int) -> Result<Void, ThemeStatusDBError> {
        PortfolioThemeStatusRepository(connection: databaseConnection).deletePortfolioThemeStatus(id: id)
    }

    func setDefaultThemeStatus(id: Int) {
        PortfolioThemeStatusRepository(connection: databaseConnection).setDefaultThemeStatus(id: id)
    }

    func ensurePortfolioThemeStatusDefault() {
        PortfolioThemeStatusRepository(connection: databaseConnection).ensurePortfolioThemeStatusDefault()
    }
}
