import XCTest

@testable import DragonShield

final class PositionsSearchTests: XCTestCase {
  func testSearchMatchesVariousFields() {
    let model = PositionsViewModel()
    let date = Date(timeIntervalSince1970: 0)
    let position1 = PositionReportData(
      id: 1,
      importSessionId: 10,
      accountName: "Alpha Account",
      institutionName: "BankOne",
      instrumentName: "Tesla",
      instrumentCurrency: "USD",
      instrumentCountry: "US",
      instrumentSector: "Auto",
      assetClass: "Equity",
      assetSubClass: "US Equity",
      quantity: 5,
      purchasePrice: 100,
      currentPrice: 110,
      instrumentUpdatedAt: date,
      notes: "Growth",
      reportDate: date,
      uploadedAt: date
    )
    let position2 = PositionReportData(
      id: 2,
      importSessionId: 20,
      accountName: "Beta Account",
      institutionName: "BankTwo",
      instrumentName: "Apple",
      instrumentCurrency: "EUR",
      instrumentCountry: "DE",
      instrumentSector: "Tech",
      assetClass: "Equity",
      assetSubClass: "EU Equity",
      quantity: 10,
      purchasePrice: 50,
      currentPrice: 55,
      instrumentUpdatedAt: date,
      notes: nil,
      reportDate: date,
      uploadedAt: date
    )
    let positions = [position1, position2]

    var result = model.filterPositions(
      positions, searchText: "apple", selectedInstitutionNames: [], currencyFilters: [])
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 2)

    result = model.filterPositions(
      positions, searchText: "bankone", selectedInstitutionNames: [], currencyFilters: [])
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 1)

    result = model.filterPositions(
      positions, searchText: "eur", selectedInstitutionNames: [], currencyFilters: [])
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 2)

    result = model.filterPositions(
      positions, searchText: "1", selectedInstitutionNames: [], currencyFilters: [])
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 1)
  }
}
