import Foundation

extension DatabaseManager {
    /// Returns instrument notes that are scoped to portfolio themes. When `themeId` is nil the
    /// result aggregates notes across all themes the instrument participates in.
    func listInstrumentUpdatesForInstrument(instrumentId: Int, themeId: Int? = nil, pinnedFirst: Bool = true) -> [InstrumentNote] {
        InstrumentNoteRepository(connection: databaseConnection)
            .listInstrumentUpdatesForInstrument(instrumentId: instrumentId, themeId: themeId, pinnedFirst: pinnedFirst)
    }

    /// Returns instrument notes that are not linked to any portfolio theme.
    func listInstrumentGeneralNotes(instrumentId: Int, pinnedFirst: Bool = true) -> [InstrumentNote] {
        InstrumentNoteRepository(connection: databaseConnection)
            .listInstrumentGeneralNotes(instrumentId: instrumentId, pinnedFirst: pinnedFirst)
    }

    func createInstrumentNote(instrumentId: Int, title: String, bodyMarkdown: String, newsTypeCode: String? = nil, pinned: Bool, author: String, source: String? = nil) -> InstrumentNote? {
        let typeCode = newsTypeCode ?? PortfolioUpdateType.General.rawValue
        guard InstrumentNote.isValidTitle(title), InstrumentNote.isValidBody(bodyMarkdown) else { return nil }
        guard let newId = InstrumentNoteRepository(connection: databaseConnection).createInstrumentNote(
            instrumentId: instrumentId,
            title: title,
            bodyMarkdown: bodyMarkdown,
            newsTypeCode: typeCode,
            pinned: pinned,
            author: author
        ) else { return nil }
        guard let item = getInstrumentUpdate(id: newId) else { return nil }
        var payload: [String: Any] = [
            "instrumentId": instrumentId,
            "noteId": newId,
            "actor": author,
            "op": "create",
            "pinned": pinned ? 1 : 0,
        ]
        if let source = source { payload["source"] = source }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .database)
        }
        return item
    }

    func createInstrumentNote(instrumentId: Int, title: String, bodyMarkdown: String, type: PortfolioUpdateType, pinned: Bool, author: String, source: String? = nil) -> InstrumentNote? {
        createInstrumentNote(instrumentId: instrumentId, title: title, bodyMarkdown: bodyMarkdown, newsTypeCode: type.rawValue, pinned: pinned, author: author, source: source)
    }

    func listThemeMentions(themeId: Int, instrumentCode: String, instrumentName: String) -> [PortfolioThemeUpdate] {
        InstrumentNoteRepository(connection: databaseConnection)
            .listThemeMentions(themeId: themeId, instrumentCode: instrumentCode, instrumentName: instrumentName)
    }

    func instrumentNotesSummary(instrumentId: Int, instrumentCode: String, instrumentName: String) -> (updates: Int, mentions: Int) {
        let updates = InstrumentNoteRepository(connection: databaseConnection).countInstrumentUpdates(instrumentId: instrumentId)
        let themes = listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
        let mentions = themes.reduce(0) { $0 + $1.mentionsCount }
        return (updates, mentions)
    }
}
