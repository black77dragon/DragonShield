import XCTest
@testable import DragonShield

final class PortfolioThemesListViewNewUpdateTests: XCTestCase {
    @MainActor
    func testInvokeNewUpdateSetsSheet() {
        let manager = DatabaseManager()
        manager.portfolioThemeUpdatesEnabled = true
        var view = PortfolioThemesListView()
        view.dbManager = manager
        let theme = PortfolioTheme(id: 1, name: "T", code: "T", statusId: 1, createdAt: "", updatedAt: "", archivedAt: nil, softDelete: false)
        view.themes = [theme]
        view.selectedThemeId = 1
        view.invokeNewUpdate(source: "toolbar")
        XCTAssertEqual(view.newUpdateTheme?.id, 1)
    }
}
