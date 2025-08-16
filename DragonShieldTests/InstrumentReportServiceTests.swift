import XCTest
@testable import DragonShield

final class InstrumentReportServiceTests: XCTestCase {
    func testGenerateReportCreatesFile() throws {
        let service = InstrumentReportService()
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDir.appendingPathComponent("instrument_report_test.xlsx")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        try service.generateReport(outputPath: fileURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        try FileManager.default.removeItem(at: fileURL)
    }
}
