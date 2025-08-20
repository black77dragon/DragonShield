import XCTest
import SQLite3
@testable import DragonShield

extension PortfolioThemesListView {
    init(testManager: DatabaseManager) {
        self._dbManager = EnvironmentObject(wrappedValue: testManager)
    }
}

final class PortfolioThemesListValuationTests: XCTestCase {
    private func setupManager() -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        manager.baseCurrency = "CHF"
        let sql = """
        CREATE TABLE PortfolioThemeStatus (id INTEGER PRIMARY KEY, code TEXT, name TEXT, color_hex TEXT, is_default INTEGER);
        INSERT INTO PortfolioThemeStatus VALUES (1,'ACTIVE','Active','#fff',1);
        CREATE TABLE PortfolioTheme (id INTEGER PRIMARY KEY, name TEXT, code TEXT, status_id INTEGER, created_at TEXT, updated_at TEXT, archived_at TEXT, soft_delete INTEGER DEFAULT 0);
        INSERT INTO PortfolioTheme VALUES (1,'Core','CORE',1,'2025-08-20T14:05:00Z','2025-08-20T14:05:00Z',NULL,0);
        CREATE TABLE PortfolioThemeAsset (theme_id INTEGER, instrument_id INTEGER, research_target_pct REAL, user_target_pct REAL, notes TEXT, PRIMARY KEY(theme_id,instrument_id));
        INSERT INTO PortfolioThemeAsset VALUES (1,1,50,50,NULL);
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, currency TEXT, sub_class_id INTEGER);
        INSERT INTO Instruments VALUES (1,'AAPL','CHF',1);
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, import_session_id INTEGER, instrument_id INTEGER, quantity REAL, current_price REAL, report_date TEXT);
        INSERT INTO PositionReports (import_session_id,instrument_id,quantity,current_price,report_date) VALUES (10,1,10,100,'2025-08-20T14:05:00Z');
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    @MainActor func testLoadValuationsPopulatesTotal() async {
        let manager = setupManager()
        var view = PortfolioThemesListView(testManager: manager)
        view.themes = manager.fetchPortfolioThemes()
        view.loadValuations()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(view.themes.first?.totalValueBase, 1000, accuracy: 0.01)
        sqlite3_close(manager.db)
    }
}
