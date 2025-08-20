import XCTest
@testable import DragonShield

final class PortfolioThemesListViewDeletionTests: XCTestCase {
    @MainActor
    func testDeleteUnarchivedThemeArchivesThenDeletes() {
        let mock = MockDatabaseManager()
        var view = PortfolioThemesListView()
        view.dbManager = mock
        let theme = PortfolioTheme(id: 1, name: "T", code: "T", statusId: 1, createdAt: "", updatedAt: "", archivedAt: nil, softDelete: false)
        view.handleDelete(theme)
        view.archiveAndDelete()
        XCTAssertEqual(mock.archiveCalls, [1])
        XCTAssertEqual(mock.softDeleteCalls, [1])
    }

    @MainActor
    func testDeleteArchivedThemeDeletesDirectly() {
        let mock = MockDatabaseManager()
        var view = PortfolioThemesListView()
        view.dbManager = mock
        let theme = PortfolioTheme(id: 2, name: "A", code: "A", statusId: 1, createdAt: "", updatedAt: "", archivedAt: "now", softDelete: false)
        view.handleDelete(theme)
        XCTAssertTrue(mock.archiveCalls.isEmpty)
        XCTAssertEqual(mock.softDeleteCalls, [2])
    }
}

final class MockDatabaseManager: DatabaseManager {
    var archiveCalls: [Int] = []
    var softDeleteCalls: [Int] = []
    override init() {
        super.init()
    }
    override func archivePortfolioTheme(id: Int) -> Bool {
        archiveCalls.append(id)
        return true
    }
    override func softDeletePortfolioTheme(id: Int) -> Bool {
        softDeleteCalls.append(id)
        return true
    }
}
