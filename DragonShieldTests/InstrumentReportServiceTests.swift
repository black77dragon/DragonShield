import XCTest
@testable import DragonShield
import SQLite3

final class InstrumentReportServiceTests: XCTestCase {
    func testGenerateReportCreatesCSV() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("report_test.sqlite")
        let destURL = tempDir.appendingPathComponent("report.csv")

        if FileManager.default.fileExists(atPath: dbURL.path) {
            try FileManager.default.removeItem(at: dbURL)
        }
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL.path)
        }

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        sqlite3_exec(db, "CREATE TABLE Instruments(id INTEGER, name TEXT);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO Instruments VALUES (1,'Foo');", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE AssetSubClasses(id INTEGER);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE PortfolioInstruments(id INTEGER);", nil, nil, nil)
        sqlite3_close(db)

        let service = InstrumentReportService()
        let result = try service.generateReport(databasePath: dbURL.path, destinationURL: destURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
        XCTAssertEqual(result.instrumentCount, 1)
        let data = try Data(contentsOf: destURL)
        XCTAssertFalse(data.isEmpty)
    }
}

