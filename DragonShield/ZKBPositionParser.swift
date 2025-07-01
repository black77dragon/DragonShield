// DragonShield/ZKBPositionParser.swift
// MARK: - Version 1.0.0
// Parses ZKB position statements using XLSXParsingService.

import Foundation
import OSLog

struct PositionImportSummary: Codable {
    var totalRows: Int
    var parsedRows: Int
    var cashAccounts: Int
    var securityRecords: Int
}

struct ParsedPositionRecord {
    let accountNumber: String
    let accountName: String
    let instrumentName: String
    let tickerSymbol: String?
    let isin: String?
    let currency: String
    let quantity: Double
    let reportDate: Date
    let isCash: Bool
}

struct ZKBPositionParser {
    private let parser = XLSXParsingService()
    private let log = Logger.parser
    private let logging = LoggingService.shared

    func parse(url: URL, progress: ((String) -> Void)? = nil) throws -> (PositionImportSummary, [ParsedPositionRecord]) {
        logging.log("Starting ZKB position parse", type: .info, logger: log)
        progress?("Opening \(url.lastPathComponent)")
        let statementDate = ZKBXLSXProcessor.statementDate(from: url.lastPathComponent) ?? Date()
        let dateMsg = "Statement date: \(ISO8601DateFormatter().string(from: statementDate))"
        logging.log(dateMsg, type: .info, logger: log)
        progress?(dateMsg)
        let portfolioCell = try? parser.cellValue(from: url, cell: "A6")
        let accountNumber = ZKBXLSXProcessor.portfolioNumber(from: portfolioCell) ?? ""
        logging.log("Portfolio number: \(accountNumber)", type: .info, logger: log)
        progress?("Portfolio \(accountNumber)")

        // Header row starts at Excel row 7 so data begins at row 8
        let rows = try parser.parseWorkbook(at: url, headerRow: 7)
        logging.log("Rows found: \(rows.count)", type: .info, logger: log)
        progress?("Rows found: \(rows.count)")

        var summary = PositionImportSummary(totalRows: rows.count, parsedRows: 0, cashAccounts: 0, securityRecords: 0)
        var records: [ParsedPositionRecord] = []

        for (idx, row) in rows.enumerated() {
            let isCash = row["Asset-Unterkategorie"] == "Konten"
            let currency = row["Whrg."] ?? "CHF"
            let descr = row["Beschreibung"] ?? ""
            let isin = row["ISIN"]
            let ticker = row["Valor"]
            let instrumentName = "ZKB \(descr) \(currency)"
            let qtyStr = row["Anzahl / Nominal"]
            var quantity: Double
            if let str = qtyStr, let q = ZKBXLSXProcessor.parseNumber(str) {
                quantity = q
            } else if instrumentName == "ZKB Call Account USD" {
                quantity = 0
                logging.log("Row \(idx+1) missing quantity - defaulting to 0 for Call Account USD", type: .debug, logger: log)
            } else {
                logging.log("Row \(idx+1) skipped - missing quantity", type: .debug, logger: log)
                progress?("Row \(idx+1) skipped")
                continue
            }
            let record = ParsedPositionRecord(accountNumber: isCash ? (row["Valor"] ?? "") : accountNumber,
                                               accountName: descr,
                                               instrumentName: instrumentName,
                                               tickerSymbol: ticker,
                                               isin: isin,
                                               currency: currency,
                                               quantity: quantity,
                                               reportDate: statementDate,
                                               isCash: isCash)
            records.append(record)
            summary.parsedRows += 1
            if isCash { summary.cashAccounts += 1 } else { summary.securityRecords += 1 }
            let msg = "Parsed row \(idx+1): \(instrumentName) qty \(quantity) \(currency)"
            logging.log(msg, type: .debug, logger: log)
            progress?(msg)
        }

        logging.log("Finished parsing positions", type: .info, logger: log)
        progress?("Parsed \(summary.parsedRows) rows")
        return (summary, records)
    }
}
