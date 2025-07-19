import Foundation
import OSLog

struct ZKBStatementParser {
    private let log = Logger.parser
    private let logging = LoggingService.shared

    func parse(url: URL, progress: ((String) -> Void)? = nil) throws -> (PositionImportSummary, [ParsedPositionRecord]) {
        logging.log("Starting ZKB CSV parse", type: .info, logger: log)
        progress?("Opening \(url.lastPathComponent)")
        let statementDate = Self.statementDate(from: url.lastPathComponent) ?? Date()
        let dateMsg = "Statement date: \(ISO8601DateFormatter().string(from: statementDate))"
        logging.log(dateMsg, type: .info, logger: log)
        progress?(dateMsg)

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.split(whereSeparator: { $0.isNewline })
        guard let header = lines.first else {
            return (PositionImportSummary(totalRows: 0,
                                           parsedRows: 0,
                                           cashAccounts: 0,
                                           securityRecords: 0,
                                           unmatchedInstruments: 0,
                                           percentValuations: 0), [])
        }
        let headers = header.replacing("\u{FEFF}", with: "").split(separator: ";").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
        var headerMap: [String: Int] = [:]
        for (idx, name) in headers.enumerated() {
            if headerMap[name] == nil { headerMap[name] = idx }
        }
        var summary = PositionImportSummary(totalRows: lines.count - 1,
                                             parsedRows: 0,
                                             cashAccounts: 0,
                                             securityRecords: 0,
                                             unmatchedInstruments: 0,
                                             percentValuations: 0)
        var records: [ParsedPositionRecord] = []
        var percentValuations = 0
        for line in lines.dropFirst() {
            let cells = line.split(separator: ";", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            let row: (String) -> String = { key in
                if let idx = headerMap[key], idx < cells.count { return cells[idx] } else { return "" }
            }
            let category = row("Anlagekategorie")
            if category == "Konten" { continue }
            let quantity = Self.parseNumber(row("Anz./Nom.")) ?? 0
            var purchasePrice = Self.parseNumber(row("Einstandskurs"))
            var currentPrice = Self.parseNumber(row("Marktkurs"))
            let marktkursUnit = cells.count > 7 ? cells[7].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let hasPercent = marktkursUnit.hasSuffix("%")
            if hasPercent {
                if let pp = purchasePrice { purchasePrice = pp / 100 }
                let priceStr: String? = {
                    if let idx = headerMap["Einstandswert (G)"], idx < cells.count { return cells[idx] } else { return nil }
                }()
                if let p = Self.parseNumber(priceStr) {
                    currentPrice = p / 100
                } else if let cp = currentPrice {
                    currentPrice = cp / 100
                }
                percentValuations += 1
            }
            let currency = row("Währung")
            let name = row("Bezeichnung")
            let valor = row("Valor/IBAN/MSCI ESG-Rating")
            let rec = ParsedPositionRecord(
                accountNumber: "1-2600-01180149",
                accountName: "ZKB Account",
                instrumentName: name,
                tickerSymbol: nil,
                isin: nil,
                valorNr: valor.isEmpty ? nil : valor,
                currency: currency,
                quantity: quantity,
                purchasePrice: purchasePrice,
                currentPrice: currentPrice,
                reportDate: statementDate,
                isCash: false,
                subClassIdGuess: Self.subClassId(for: category)
            )
            records.append(rec)
            summary.parsedRows += 1
            summary.securityRecords += 1
            var msg = "Parsed row: \(name) qty \(quantity) \(currency)"
            if hasPercent { msg += " % Valuation" }
            logging.log(msg, type: .debug, logger: log)
            progress?(msg)
        }
        summary.percentValuations = percentValuations
        logging.log("Finished ZKB parsing", type: .info, logger: log)
        progress?("Parsed \(summary.parsedRows) rows")
        return (summary, records)
    }

    private static func subClassId(for category: String) -> Int? {
        let map: [String: Int] = [
            "Liquide Mittel": 1,
            "Obligationen und Ähnliches": 8,
            "Aktien und Ähnliches": 3
        ]
        return map[category]
    }

    static func parseNumber(_ string: String?) -> Double? {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        var cleaned = s.replacingOccurrences(of: "'", with: "")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    static func statementDate(from filename: String) -> Date? {
        let pattern = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+(\\d{1,2})\\s+(\\d{4})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) else { return nil }
        let monthStr = String(filename[Range(match.range(at: 1), in: filename)!])
        let day = Int(filename[Range(match.range(at: 2), in: filename)!]) ?? 1
        let year = Int(filename[Range(match.range(at: 3), in: filename)!]) ?? 1970
        let months = ["Jan":1,"Feb":2,"Mar":3,"Apr":4,"May":5,"Jun":6,"Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12]
        guard let month = months[String(monthStr.prefix(3)).capitalized] else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps)
    }
}
