// DragonShield/Services/CreditSuisseCsvImporter.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Initial CSV import service for Credit-Suisse statements.

import Foundation
import OSLog

/// Parses Credit-Suisse CSV statements and records cash account positions.
struct CreditSuisseCsvImporter {
    private let csvParser = CSVParsingService()
    private let dbManager: DatabaseManager
    private let log = Logger.parser
    private let logging = LoggingService.shared

    init(dbManager: DatabaseManager = DatabaseManager.shared) {
        self.dbManager = dbManager
    }

    /// Mapping of Valor numbers to (ticker, currency) tuples for known cash accounts.
    private static let cashMap: [String: (String, String)] = [
        "CH9304835039842401009": ("CASHCHF", "CHF"),
        "CH8104835039842402001": ("CASHEUR", "EUR"),
        "CH5404835039842402002": ("CASHGBP", "GBP"),
        "CH1104835039842402000": ("CASHUSD", "USD"),
        "CH2704835039842402003": ("CASHUSD", "USD") // Call Account
    ]

    /// Imports a CSV file and stores cash account rows directly into PositionReports.
    func importFile(at url: URL) throws {
        logging.log("Starting Credit-Suisse CSV import", type: .info, logger: log)
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = csvParser.parse(csvString: content)
        let reportDate = Self.statementDate(from: url.lastPathComponent) ?? Date()

        for row in rows {
            guard let valor = row["Valor"]?.replacingOccurrences(of: " ", with: ""),
                  let desc = row["Beschreibung"] else { continue }
            guard let (ticker, currency) = Self.cashMap[valor],
                  desc.lowercased().contains("kontokorrent") || desc.lowercased().contains("call account") else { continue }

            let quantity = Self.parseNumber(row["Anzahl / Nominal"]) ?? 0
            guard let accId = dbManager.findAccountId(accountNumber: valor),
                  let details = dbManager.fetchAccountDetails(id: accId),
                  let instrId = dbManager.findInstrumentId(ticker: ticker) else { continue }
            _ = dbManager.addPositionReport(
                importSessionId: nil,
                accountId: accId,
                institutionId: details.institutionId,
                instrumentId: instrId,
                quantity: quantity,
                purchasePrice: 1,
                currentPrice: 1,
                instrumentUpdatedAt: reportDate,
                notes: nil,
                reportDate: reportDate
            )
            logging.log("Cash Account \(ticker) recorded", type: .info, logger: log)
        }
    }

    private static func parseNumber(_ str: String?) -> Double? {
        guard let s = str?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        let cleaned = s.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private static func statementDate(from filename: String) -> Date? {
        let pattern = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\\s.-]+(\\d{1,2})[\\s.-]+(\\d{4})"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) {
            let monthStr = String(filename[Range(match.range(at: 1), in: filename)!])
            let day = Int(filename[Range(match.range(at: 2), in: filename)!]) ?? 1
            let year = Int(filename[Range(match.range(at: 3), in: filename)!]) ?? 1970
            let months = ["Jan":1,"Feb":2,"Mar":3,"Apr":4,"May":5,"Jun":6,"Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12]
            if let month = months[String(monthStr.prefix(3)).capitalized] {
                var comps = DateComponents()
                comps.year = year
                comps.month = month
                comps.day = day
                return Calendar.current.date(from: comps)
            }
        }
        return nil
    }
}

