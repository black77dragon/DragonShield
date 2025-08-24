import XCTest
@testable import DragonShield

final class ImportParsingTests: XCTestCase {
    func testCreditSuisseSampleParses() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let url = root.appendingPathComponent("DragonShield/test_data/Position List Mar 26 2025.xlsx")
        let records = try CreditSuisseXLSXProcessor().process(url: url)
        XCTAssertGreaterThan(records.count, 0)
    }

    func testZKBSampleParses() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let url = root.appendingPathComponent("DragonShield/test_data/Depotauszug Feb 20 2025 ZKB.csv")
        let (summary, records) = try ZKBStatementParser().parse(url: url)
        XCTAssertGreaterThan(summary.parsedRows, 0)
        XCTAssertGreaterThan(records.count, 0)
    }
}
