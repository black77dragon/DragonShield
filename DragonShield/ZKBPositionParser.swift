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
    var accountNumber: String
    var accountName: String
    var instrumentName: String
    var tickerSymbol: String?
    var isin: String?
    var currency: String
    var quantity: Double
    var purchasePrice: Double?
    var currentPrice: Double?
    let reportDate: Date
    let isCash: Bool
    var subClassIdGuess: Int?
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
        let valueDateStr = (try? parser.cellValue(from: url, cell: "B3")) ?? ""
        let valueDate = DateFormatter.swissDate.date(from: valueDateStr) ?? statementDate
        let valMsg = "Value date: \(DateFormatter.swissDate.string(from: valueDate))"
        logging.log(valMsg, type: .info, logger: log)
        progress?(valMsg)
        let portfolioCell = try? parser.cellValue(from: url, cell: "B6")
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
            let category = row["Anlagekategorie"] ?? ""
            let subCategory = row["Asset-Unterkategorie"] ?? ""
            let isCash = subCategory == "Konten"
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
           let purchasePrice = row["Einstandskurs"].flatMap { ZKBXLSXProcessor.parseNumber($0) }
           let currentPrice = row["Kurs"].flatMap { ZKBXLSXProcessor.parseNumber($0) }
            let guess = Self.guessSubClassId(category: category, subCategory: subCategory, isCash: isCash)
            let record = ParsedPositionRecord(accountNumber: accountNumber,
                                               accountName: isCash ? descr : "ZKB Custody Account",
                                               instrumentName: instrumentName,
                                               tickerSymbol: ticker,
                                               isin: isin,
                                               currency: currency,
                                               quantity: quantity,
                                               purchasePrice: purchasePrice,
                                               currentPrice: currentPrice,
                                               reportDate: valueDate,
                                               isCash: isCash,
                                               subClassIdGuess: guess)
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

    /// Maps the ZKB "Anlagekategorie" and "Asset-Unterkategorie" strings to an
    /// `AssetSubClasses.sub_class_id` based on the table in
    /// `docs/AssetClassDefinitionConcept.md`.
    private static func guessSubClassId(category: String, subCategory: String, isCash: Bool) -> Int? {
        if isCash { return 1 } // Cash

        let cat = category.lowercased()
        let sub = subCategory.lowercased()

        if sub.contains("geldmarktfonds") { return 2 } // Money Market Instruments
        if sub.contains("aktienfonds") { return 5 } // Equity Fund
        if sub.contains("etf") && cat.contains("aktien") { return 4 } // Equity ETF
        if sub.contains("etf") && cat.contains("festverzinsliche") { return 9 } // Bond ETF
        if sub.starts(with: "aktien") { return 3 } // Single Stock
        if sub.contains("obligationenfonds") { return 10 } // Bond Fund
        if sub.contains("obligationen") { return 8 } // Corporate Bond
        if sub.contains("hedge") { return 15 } // Hedge Fund

        if cat.contains("liquid") { return 1 }
        if cat.contains("aktien") { return 3 }
        if cat.contains("festverzinsliche") { return 8 }
        if cat.contains("rohstoff") || cat.contains("immobil") || cat.contains("ai") { return 13 }
        return nil
    }
}
