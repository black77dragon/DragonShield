import Foundation

struct InstrumentReportResult {
    let fileURL: URL
    let size: Int64
    let duration: TimeInterval
    let instrumentCount: Int
    let assetSubClassCount: Int
    let portfolioAssignmentCount: Int
}

final class InstrumentReportService {
    func generateReport(databasePath: String, destinationURL: URL) throws -> InstrumentReportResult {
        let start = Date()
        let db = try ReportDB(path: databasePath)

        let instruments = try db.fetchRows(sql: "SELECT id, name FROM Instruments")
        let instrumentCount = instruments.count
        let assetSubClassCount = try db.count(table: "AssetSubClasses")
        let portfolioAssignmentCount = try db.count(table: "PortfolioInstruments")

        var csv = "id,name\n"
        for row in instruments { csv += row.joined(separator: ",") + "\n" }

        let directory = destinationURL.deletingLastPathComponent()
        let tmpURL = directory.appendingPathComponent(destinationURL.lastPathComponent + ".tmp")
        try csv.write(to: tmpURL, atomically: true, encoding: .utf8)
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.moveItem(at: tmpURL, to: destinationURL)

        let attrs = try fm.attributesOfItem(atPath: destinationURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let duration = Date().timeIntervalSince(start)

        LoggingService.shared.log(
            "InstrumentReport path=\(destinationURL.path) size=\(size) instruments=\(instrumentCount) duration=\(duration)",
            type: .info,
            logger: .general
        )

        return InstrumentReportResult(
            fileURL: destinationURL,
            size: size,
            duration: duration,
            instrumentCount: instrumentCount,
            assetSubClassCount: assetSubClassCount,
            portfolioAssignmentCount: portfolioAssignmentCount
        )
    }
}

