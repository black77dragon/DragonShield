import Foundation

final class IchimokuReportService {
    private let fileManager = FileManager.default
    private let dbManager: DatabaseManager

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func generateReport(summary: IchimokuPipelineSummary) throws -> URL {
        let formatter = DateFormatter.iso8601DateOnly
        let timestamp = DateFormatter.iso8601DateTime.string(from: Date())
        let sanitizedTimestamp = timestamp.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: " ", with: "_")
        let fileName = "ichimoku_report_\(formatter.string(from: summary.scanDate))_\(sanitizedTimestamp).csv"
        let directory = try reportsDirectory()
        let fileURL = directory.appendingPathComponent(fileName)
        var csv = "Section,Symbol,Name,Value1,Value2,Value3,Value4\n"
        csv.append("Summary,Scan Date,,\(formatter.string(from: summary.scanDate)),Processed Tickers,\(summary.processedTickers),Candidates,\(summary.candidates.count)\n")
        csv.append("Summary,Run ID,,\(summary.runId.map(String.init) ?? "-"),,,\n")
        csv.append("Candidates,,,,,,,,\n")
        csv.append("Type,Symbol,Name,Momentum,Close,Tenkan,Kijun,Price/Kijun,Notes\n")
        for candidate in summary.candidates {
            let symbol = csvEscape(fetchSymbol(for: candidate.tickerId))
            let name = csvEscape(fetchName(for: candidate.tickerId))
            let notes = csvEscape(candidate.notes ?? "")
            let line = String(format: "Candidate,%@,%@,%.6f,%.2f,%.2f,%.2f,%.4f,%@\n",
                              symbol,
                              name,
                              candidate.momentumScore,
                              candidate.closePrice,
                              candidate.tenkan ?? 0,
                              candidate.kijun ?? 0,
                              candidate.priceToKijunRatio ?? 0,
                              notes)
            csv.append(line)
        }
        csv.append("Sell Alerts,,,,,,,,\n")
        csv.append("Type,Symbol,Name,Alert Date,Close,Kijun,Reason,,\n")
        for alert in summary.sellAlerts {
            let symbol = csvEscape(alert.ticker.symbol)
            let name = csvEscape(alert.ticker.name)
            let reason = csvEscape(alert.reason)
            let line = String(format: "Alert,%@,%@,%@,%.2f,%.2f,%@,,\n",
                              symbol,
                              name,
                              formatter.string(from: alert.alertDate),
                              alert.closePrice,
                              alert.kijunValue ?? 0,
                              reason)
            csv.append(line)
        }
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        } else {
            return escaped
        }
    }

    private func reportsDirectory() throws -> URL {
        let support = try fileManager.url(for: .applicationSupportDirectory,
                                          in: .userDomainMask,
                                          appropriateFor: nil,
                                          create: true)
        let dir = support.appendingPathComponent("DragonShield/IchimokuReports", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func fetchSymbol(for tickerId: Int) -> String {
        return dbManager.ichimokuFetchTickerById(tickerId)?.symbol ?? "T\(tickerId)"
    }

    private func fetchName(for tickerId: Int) -> String {
        return dbManager.ichimokuFetchTickerById(tickerId)?.name ?? ""
    }
}
