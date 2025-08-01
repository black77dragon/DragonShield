// DragonShield/CreditSuisseXLSXProcessor.swift
// MARK: - Version 1.0.7.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial implementation applying credit_suisse_parser logic in Swift.
// - 1.0.0.0 -> 1.0.1.0: Log progress and read report date from cell A1.
// - 1.0.1.0 -> 1.0.1.1: Fix conditional binding when reading cell value.
// - 1.0.1.1 -> 1.0.1.2: Correct regex pattern for statement date parsing.
// - 1.0.1.2 -> 1.0.2.0: Parse positions according to Credit-Suisse_Parser_Mapping documentation.
// - 1.0.2.0 -> 1.0.2.1: Add detailed progress messages for each row.
// - 1.0.2.1 -> 1.0.3.0: Emit OSLog entries for parsing progress.
// - 1.0.3.0 -> 1.0.4.0: Log messages via LoggingService and improve number parsing.
// - 1.0.4.0 -> 1.0.5.0: Emit human readable log messages and report parsed count.
// - 1.0.5.0 -> 1.0.6.0: Log each parsed record and flag parsing failures.
// - 1.0.6.0 -> 1.0.7.0: Print parsed row data and log file completion summary.

import Foundation
import OSLog

struct CreditSuisseXLSXProcessor {
    private let parser: XLSXParsingService
    private let log = Logger.parser
    private let logging = LoggingService.shared

    init(parser: XLSXParsingService = XLSXParsingService()) {
        self.parser = parser
    }

    func process(url: URL, progress: ((String) -> Void)? = nil) throws -> [MyBankRecord] {

        let openMsg = "Starting import: \(url.lastPathComponent)"
        logging.log(openMsg, type: .info, logger: log)
        progress?(openMsg)

        if let cellValue = try? parser.cellValue(from: url, cell: "A1") {
            let msg = "A1 header: \(cellValue)"
            logging.log(msg, type: .debug, logger: log)

            progress?(msg)
        }

        let statementDate = Self.statementDate(from: url.lastPathComponent) ?? Date()
        let dateString = ISO8601DateFormatter().string(from: statementDate)
        let dateMsg = "Parsed statement date \(dateString)"
        logging.log(dateMsg, type: .info, logger: log)

        progress?(dateMsg)
        let portfolioCell = try? parser.cellValue(from: url, cell: "A6")
        let portfolioNumber = Self.portfolioNumber(from: portfolioCell)
        if let number = portfolioNumber {
            let msg = "Detected portfolio number \(number)"
            logging.log(msg, type: .info, logger: log)
            progress?(msg)
        }

        // Worksheet header is on row 7
        let rawRows = try parser.parseWorkbook(at: url, headerRow: 7)
        let rowsMsg = "Worksheet rows found: \(rawRows.count)"
        logging.log(rowsMsg, type: .info, logger: log)
        progress?(rowsMsg)
        var records: [MyBankRecord] = []
        var parsedCount = 0
        for (idx, row) in rawRows.enumerated() {
            let rawMsg = "Row \(idx + 1) raw values: " +
                row.map { "\($0)=\($1)" }.joined(separator: ", ")
            logging.log(rawMsg, type: .debug, logger: log)
            progress?(rawMsg)
            let isCash = row["Asset-Unterkategorie"] == "Konten"
            let desc = row["Beschreibung"] ?? ""
            let account = isCash ? (row["Valor"] ?? "") : (portfolioNumber ?? "")
            let currency = row["Whrg."] ?? ""
            let amountStr = isCash ? (row["Anzahl / Nominal"] ?? row["Wert in CHF"] ?? "") : (row["Wert in CHF"] ?? row["Anzahl / Nominal"] ?? "")
            guard let amount = Self.parseNumber(amountStr) else {
                let failMsg = "Row \(idx + 1): could not parse amount '\(amountStr)'"
                logging.log(failMsg, type: .error, logger: log)
                progress?(failMsg)
                continue
            }
            let typeMsg = isCash ? "cash" : "position"
            let msg = "Parsed \(typeMsg) row \(idx + 1): \(desc), amount \(amount) \(currency), account \(account)"
            logging.log(msg, type: .debug, logger: log)
            progress?(msg)
            let record = MyBankRecord(transactionDate: statementDate,
                                     description: desc,
                                     amount: amount,
                                     currency: currency,
                                     bankAccount: account)
            records.append(record)
            parsedCount += 1
            let recordMsg = "Record \(idx + 1) parsed: date \(dateString), desc '\(desc)', amount \(amount) \(currency), account \(account)"
            logging.log(recordMsg, type: .debug, logger: log)
            progress?(recordMsg)
        }
        let summary = "Finished parsing: \(parsedCount) records created"
        logging.log(summary, type: .info, logger: log)
        progress?(summary)
        let fileSummary = "Completed import for \(url.lastPathComponent) with \(parsedCount) records"
        logging.log(fileSummary, type: .info, logger: log)
        progress?(fileSummary)
        return records
    }

    static func portfolioNumber(from cell: String?) -> String? {
        let spaces = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{00a0}"))
        guard let raw = cell?.trimmingCharacters(in: spaces), !raw.isEmpty else { return nil }
        let pattern = "Portfolio-Nr.?\\s*(.+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            return String(raw[Range(match.range(at: 1), in: raw)!]).trimmingCharacters(in: spaces)
        }
        return raw
    }

    static func parseNumber(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let isPercent = trimmed.hasSuffix("%") || trimmed.hasSuffix(" %")
        var cleaned = trimmed
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        if cleaned.hasPrefix("(") && cleaned.hasSuffix(")") {
            cleaned.removeFirst(); cleaned.removeLast()
            cleaned = "-" + cleaned
        }
        guard let value = Double(cleaned) else { return nil }
        return isPercent ? value / 100.0 : value
    }

    static func statementDate(from filename: String) -> Date? {
        // Match strings like "Mar 26 2025" in filenames
        let pattern = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[ .-]+(\\d{1,2})[ .-]+(\\d{4})"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) {
            let monthStr = String(filename[Range(match.range(at: 1), in: filename)!])
            let day = Int(filename[Range(match.range(at: 2), in: filename)!]) ?? 1
            let year = Int(filename[Range(match.range(at: 3), in: filename)!]) ?? 1970
            let months = ["Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6, "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12]
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
