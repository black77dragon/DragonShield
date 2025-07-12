// DragonShield/CreditSuissePositionParser.swift
// MARK: - Version 1.0.0
// Parses Credit-Suisse position statements using XLSXParsingService.

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

struct CreditSuissePositionParser {
    private let parser = XLSXParsingService()
    private let log = Logger.parser
    private let logging = LoggingService.shared

    func parse(url: URL, progress: ((String) -> Void)? = nil) throws -> (PositionImportSummary, [ParsedPositionRecord]) {
        logging.log("Starting Credit-Suisse position parse", type: .info, logger: log)
        progress?("Opening \(url.lastPathComponent)")
        let statementDate = CreditSuisseXLSXProcessor.statementDate(from: url.lastPathComponent) ?? Date()
        let dateMsg = "Statement date: \(ISO8601DateFormatter().string(from: statementDate))"
        logging.log(dateMsg, type: .info, logger: log)
        progress?(dateMsg)
        let valueDateStr = (try? parser.cellValue(from: url, cell: "B3")) ?? ""
        let valueDate = DateFormatter.swissDate.date(from: valueDateStr) ?? statementDate
        let valMsg = "Value date: \(DateFormatter.swissDate.string(from: valueDate))"
        logging.log(valMsg, type: .info, logger: log)
        progress?(valMsg)
        let portfolioCell = try? parser.cellValue(from: url, cell: "B6")
        let accountNumber = CreditSuisseXLSXProcessor.portfolioNumber(from: portfolioCell) ?? ""
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
            let instrumentName = "Credit-Suisse \(descr) \(currency)"
            let qtyStr = row["Anzahl / Nominal"]
            var quantity: Double
            if let str = qtyStr, let q = CreditSuisseXLSXProcessor.parseNumber(str) {
                quantity = q
            } else if instrumentName == "Credit-Suisse Call Account USD" {
                quantity = 0
                logging.log("Row \(idx+1) missing quantity - defaulting to 0 for Call Account USD", type: .debug, logger: log)
            } else {
                logging.log("Row \(idx+1) skipped - missing quantity", type: .debug, logger: log)
                progress?("Row \(idx+1) skipped")
                continue
            }
           let purchasePrice = row["Einstandskurs"].flatMap { CreditSuisseXLSXProcessor.parseNumber($0) }
           let currentPrice = row["Kurs"].flatMap { CreditSuisseXLSXProcessor.parseNumber($0) }
            let guess = Self.guessSubClassId(category: category, subCategory: subCategory, isCash: isCash)
            let accountName = isCash ? Self.renameCashAccount(description: descr,
                                                             currency: currency,
                                                             institution: "Credit-Suisse")
                                      : "Credit-Suisse Custody Account"
            let record = ParsedPositionRecord(accountNumber: accountNumber,
                                               accountName: accountName,
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

    /// Renames a cash account using the institution and currency codes.
    /// - Parameters:
    ///   - description: The German description from the statement.
    ///   - currency: The account currency code.
    ///   - institution: The institution code prefix.
    /// - Returns: The formatted account name.
    private static func renameCashAccount(description: String,
                                          currency: String,
                                          institution: String) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let english = (lower == "kontokorrent" || lower == "kontokorrent wertschriften")
            ? "Cash Account" : trimmed
        let parts = [institution, english, currency]
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Maps the Credit-Suisse "Anlagekategorie" and "Asset-Unterkategorie" strings to an
    /// `AssetSubClasses.sub_class_id` based on the table in
    /// `docs/AssetClassDefinitionConcept.md`.
    private static func guessSubClassId(category: String, subCategory: String, isCash: Bool) -> Int? {
        // Mapping based on the "Credit-Suisse Parsing" column in
        // docs/AssetClassDefinitionConcept.md. Keys are matched
        // case-insensitively and may represent prefixes.

        // Hard-coded lookup for subclass names used in log messages
        let names: [Int: String] = [
            1: "Cash", 2: "Money Market Instruments", 3: "Single Stock",
            4: "Equity ETF", 5: "Equity Fund", 6: "Equity REIT",
            7: "Government Bond", 8: "Corporate Bond", 9: "Bond ETF",
            10: "Bond Fund", 11: "Direct Real Estate", 12: "Mortgage REIT",
            13: "Commodities", 14: "Infrastructure", 15: "Hedge Fund",
            16: "Private Equity / Debt", 17: "Structured Product",
            18: "Cryptocurrency", 19: "Options", 20: "Futures",
            21: "Other"
        ]

        let cat = category.lowercased()
        let sub = subCategory.lowercased()

        var result: Int?

        if isCash {
            result = 1
        } else if sub.contains("geldmarktfonds") {
            result = 2
        } else if sub.starts(with: "aktienfonds") {
            result = 5
        } else if sub.starts(with: "aktien ") || sub.starts(with: "aktien/") {
            result = 3
        } else if sub.contains("obligationenfonds") {
            result = 10
        } else if sub.starts(with: "obligationen") {
            result = 8
        } else if sub.contains("hedge-funds") || sub.contains("hedge funds") {
            result = 15
        } else if sub.contains("standard-optionen") {
            result = 19
        } else if sub.contains("etf") && cat.contains("aktien") {
            result = 4
        } else if sub.contains("etf") && cat.contains("festverzinsliche") {
            result = 9
        } else if cat.contains("festverzinsliche") {
            result = 8
        } else if cat.contains("aktien") {
            result = 3
        } else if cat.contains("rohstoff") || cat.contains("immobil") || cat.contains("ai") {
            result = 13
        } else if cat.contains("liquid") {
            result = 1
        }

        if let id = result {
            let name = names[id] ?? "Unknown"
            LoggingService.shared.log("Sub-category '\(subCategory)' mapped to \(name) (ID \(id))", type: .debug, logger: .parser)
        } else {
            LoggingService.shared.log("Sub-category '\(subCategory)' has no mapping", type: .debug, logger: .parser)
        }

        return result
    }
}
