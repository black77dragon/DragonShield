import XCTest
import SQLite3
@testable import DragonShield

final class InstrumentReportServiceTests: XCTestCase {
    func testGenerateReportCreatesCSVWithCounts() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("report test", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let dbURL = tmpDir.appendingPathComponent("test.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        sqlite3_exec(db, "CREATE TABLE Instruments(id INTEGER);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE AssetSubClasses(id INTEGER);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE PortfolioInstruments(id INTEGER);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO Instruments VALUES (1);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO AssetSubClasses VALUES (1);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO PortfolioInstruments VALUES (1);", nil, nil, nil)
        sqlite3_close(db)

        let destination = tmpDir.appendingPathComponent("report.csv")
        let service = InstrumentReportService()
        let summary = try service.generateReport(databasePath: dbURL.path, destinationURL: destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        let csv = try String(contentsOf: destination)
        XCTAssertTrue(csv.contains("Instruments,1"))
        XCTAssertEqual(summary.instrumentCount, 1)
    }
}
