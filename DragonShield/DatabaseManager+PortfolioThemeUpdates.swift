// DragonShield/DatabaseManager+PortfolioThemeUpdates.swift

// MARK: - Version 1.2

// MARK: - History

// - 1.0 -> 1.1: Support Markdown bodies and pinning with ordering options.
// - 1.1 -> 1.2: Add search, type filter, and soft-delete with restore and permanent delete.

import Foundation

extension DatabaseManager {
    func ensurePortfolioThemeUpdateTable() {
        PortfolioThemeUpdateRepository(connection: databaseConnection).ensurePortfolioThemeUpdateTable()
    }

    func listThemeUpdates(themeId: Int, view: ThemeUpdateView = .active, typeId: Int? = nil, searchQuery: String? = nil, pinnedFirst: Bool = true) -> [PortfolioThemeUpdate] {
        PortfolioThemeUpdateRepository(connection: databaseConnection)
            .listThemeUpdates(themeId: themeId, view: view, typeId: typeId, searchQuery: searchQuery, pinnedFirst: pinnedFirst)
    }

    func createThemeUpdate(themeId: Int, title: String, bodyMarkdown: String, newsTypeCode: String, pinned: Bool, author: String, positionsAsOf: String?, totalValueChf: Double?, source: String? = nil) -> PortfolioThemeUpdate? {
        PortfolioThemeUpdateRepository(connection: databaseConnection).createThemeUpdate(
            themeId: themeId,
            title: title,
            bodyMarkdown: bodyMarkdown,
            newsTypeCode: newsTypeCode,
            pinned: pinned,
            author: author,
            positionsAsOf: positionsAsOf,
            totalValueChf: totalValueChf,
            source: source
        )
    }

    func getThemeUpdate(id: Int) -> PortfolioThemeUpdate? {
        PortfolioThemeUpdateRepository(connection: databaseConnection).getThemeUpdate(id: id)
    }

    func updateThemeUpdate(id: Int, title: String?, bodyMarkdown: String?, newsTypeCode: String?, pinned: Bool?, actor: String, expectedUpdatedAt: String, source: String? = nil) -> PortfolioThemeUpdate? {
        PortfolioThemeUpdateRepository(connection: databaseConnection).updateThemeUpdate(
            id: id,
            title: title,
            bodyMarkdown: bodyMarkdown,
            newsTypeCode: newsTypeCode,
            pinned: pinned,
            actor: actor,
            expectedUpdatedAt: expectedUpdatedAt,
            source: source
        )
    }

    func softDeleteThemeUpdate(id: Int, actor: String, source: String? = nil) -> Bool {
        PortfolioThemeUpdateRepository(connection: databaseConnection)
            .softDeleteThemeUpdate(id: id, actor: actor, source: source)
    }

    func restoreThemeUpdate(id: Int, actor: String, source: String? = nil) -> Bool {
        PortfolioThemeUpdateRepository(connection: databaseConnection)
            .restoreThemeUpdate(id: id, actor: actor, source: source)
    }

    func deleteThemeUpdatePermanently(id: Int, actor: String, source: String? = nil) -> Bool {
        PortfolioThemeUpdateRepository(connection: databaseConnection)
            .deleteThemeUpdatePermanently(id: id, actor: actor, source: source)
    }
}

extension DatabaseManager {
    // List all theme updates across all themes with optional filters
    func listAllThemeUpdates(view: ThemeUpdateView = .active, typeId: Int? = nil, searchQuery: String? = nil, pinnedFirst: Bool = true) -> [PortfolioThemeUpdate] {
        PortfolioThemeUpdateRepository(connection: databaseConnection)
            .listAllThemeUpdates(view: view, typeId: typeId, searchQuery: searchQuery, pinnedFirst: pinnedFirst)
    }
}
