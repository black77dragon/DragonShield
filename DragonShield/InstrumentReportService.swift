import Foundation
import SQLite3
import OSLog

final class InstrumentReportService {
    struct Summary {
        let instrumentCount: Int
        let subClassCount: Int
        let portfolioInstrumentCount: Int
    }

    func generateReport(databasePath: String, destinationURL: URL) throws -> Summary {
        let logger = LoggingService.shared
        logger.log("instrument_report.start \(destinationURL.path)", logger: .database)
        let start = Date()
        let db = try ReportDB(path: databasePath)
        defer { db.close() }

        let summary = try Summary(
            instrumentCount: db.count(table: "Instruments"),
            subClassCount: db.count(table: "AssetSubClasses"),
            portfolioInstrumentCount: db.count(table: "PortfolioInstruments")
        )

        var csv = "Section,Count\n"
        csv += "Instruments,\(summary.instrumentCount)\n"
        csv += "AssetSubClasses,\(summary.subClassCount)\n"
        csv += "PortfolioInstruments,\(summary.portfolioInstrumentCount)\n"

        let dir = destinationURL.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("tmp")
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        let attrs = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        let duration = Date().timeIntervalSince(start)
        logger.log("instrument_report.complete file=\(destinationURL.path) size=\(size) duration=\(duration)", logger: .database)
        return summary
    }
}
