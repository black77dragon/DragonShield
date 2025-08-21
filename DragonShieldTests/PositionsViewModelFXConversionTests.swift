import XCTest
import SQLite3
@testable import DragonShield

final class PositionsViewModelFXConversionTests: XCTestCase {
    func testCalculatesValuesInCHFUsingExchangeRates() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        manager.baseCurrency = "CHF"
        let sql = """
        CREATE TABLE Currencies (currency_code TEXT, currency_name TEXT, currency_symbol TEXT, is_active INTEGER, api_supported INTEGER);
        INSERT INTO Currencies VALUES ('USD','US Dollar','$',1,1);
        INSERT INTO Currencies VALUES ('CHF','Swiss Franc','CHF',1,1);
        CREATE TABLE ExchangeRates (currency_code TEXT, rate_date TEXT, rate_to_chf REAL);
        INSERT INTO ExchangeRates VALUES ('USD','2025-08-20T14:00:00Z',0.9);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        let posUSD = PositionReportData(id: 1, importSessionId: nil, accountName: "A", institutionName: "I", instrumentName: "Stock", instrumentCurrency: "USD", instrumentCountry: nil, instrumentSector: nil, assetClass: nil, assetSubClass: nil, quantity: 10, purchasePrice: nil, currentPrice: 5, instrumentUpdatedAt: nil, notes: nil, reportDate: Date(), uploadedAt: Date())
        let posCHF = PositionReportData(id: 2, importSessionId: nil, accountName: "B", institutionName: "J", instrumentName: "Bond", instrumentCurrency: "CHF", instrumentCountry: nil, instrumentSector: nil, assetClass: nil, assetSubClass: nil, quantity: 3, purchasePrice: nil, currentPrice: 20, instrumentUpdatedAt: nil, notes: nil, reportDate: Date(), uploadedAt: Date())
        let viewModel = PositionsViewModel()
        viewModel.calculateValues(positions: [posUSD, posCHF], db: manager)
        let exp = expectation(description: "calc")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(viewModel.positionValueCHF[1]!, 45.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.positionValueCHF[2]!, 60.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.totalAssetValueCHF, 105.0, accuracy: 0.01)
        sqlite3_close(db)
    }
}
