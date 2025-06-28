// DragonShield/ZKBXLSXProcessor.swift
// MARK: - Version 1.0.3.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial implementation applying zkb_parser logic in Swift.
// - 1.0.0.0 -> 1.0.1.0: Log progress and read report date from cell A1.
// - 1.0.1.0 -> 1.0.1.1: Fix conditional binding when reading cell value.
// - 1.0.1.1 -> 1.0.1.2: Correct regex pattern for statement date parsing.
// - 1.0.1.2 -> 1.0.2.0: Parse positions according to ZKB_Parser_Mapping documentation.
// - 1.0.2.0 -> 1.0.2.1: Add detailed progress messages for each row.
// - 1.0.2.1 -> 1.0.3.0: Emit OSLog entries for parsing progress.
import Foundation
import OSLog

struct ZKBXLSXProcessor {
    private let parser: XLSXParsingService
    private let log = Logger.parser

    init(parser: XLSXParsingService = XLSXParsingService()) {
        self.parser = parser
    }

    func process(url: URL, progress: ((String) -> Void)? = nil) throws -> [MyBankRecord] {
        let openMsg = "Opened file \(url.lastPathComponent)"
        log.info("\(openMsg, privacy: .public)")
        progress?(openMsg)
        if let cellValue = try? parser.cellValue(from: url, cell: "A1") {
            let msg = "Cell A1 value: \(cellValue)"
            log.info("\(msg, privacy: .public)")
            progress?(msg)
        }
        let statementDate = Self.statementDate(from: url.lastPathComponent) ?? Date()
        let dateString = ISO8601DateFormatter().string(from: statementDate)
        let dateMsg = "Statement date: \(dateString)"
        log.info("\(dateMsg, privacy: .public)")
        progress?(dateMsg)
        let portfolioCell = try? parser.cellValue(from: url, cell: "A6")
        let portfolioNumber = Self.portfolioNumber(from: portfolioCell)
        if let number = portfolioNumber {
            let msg = "Portfolio number: \(number)"
            log.info("\(msg, privacy: .public)")
            progress?(msg)
        }

        let rawRows = try parser.parseWorkbook(at: url, headerRow: 8)
        let rowsMsg = "Rows found: \(rawRows.count)"
        log.info("\(rowsMsg, privacy: .public)")
        progress?(rowsMsg)
        var records: [MyBankRecord] = []
        for (idx, row) in rawRows.enumerated() {
            if row["Asset-Unterkategorie"] == "Konten" {
                let desc = row["Beschreibung"] ?? ""
                let account = row["Valor"] ?? ""
                let currency = row["Whrg."] ?? ""
                let amountStr = row["Anzahl / Nominal"] ?? row["Wert in CHF"] ?? ""
                guard let amount = Self.parseNumber(amountStr) else { continue }
                let msg = "Row \(idx + 1): cash \(desc) \(amount) \(currency)"
                log.debug("\(msg, privacy: .public)")
                progress?(msg)
                let record = MyBankRecord(transactionDate: statementDate,
                                         description: desc,
                                         amount: amount,
                                         currency: currency,
                                         bankAccount: account)
                records.append(record)
            } else {
                let desc = row["Beschreibung"] ?? ""
                let account = portfolioNumber ?? ""
                let currency = row["Whrg."] ?? ""
                let amountStr = row["Wert in CHF"] ?? row["Anzahl / Nominal"] ?? ""
                guard let amount = Self.parseNumber(amountStr) else { continue }
                let msg = "Row \(idx + 1): position \(desc) \(amount) \(currency)"
                log.debug("\(msg, privacy: .public)")
                progress?(msg)
                let record = MyBankRecord(transactionDate: statementDate,
                                         description: desc,
                                         amount: amount,
                                         currency: currency,
                                         bankAccount: account)
                records.append(record)
            }
        }
        return records
    }

    private static func portfolioNumber(from cell: String?) -> String? {
        guard let cell = cell else { return nil }
        let pattern = "Portfolio-Nr.\\s*(.+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: cell, range: NSRange(cell.startIndex..., in: cell)) {
            return String(cell[Range(match.range(at: 1), in: cell)!]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func parseNumber(_ string: String) -> Double? {
        let cleaned = string.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private static func statementDate(from filename: String) -> Date? {
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
