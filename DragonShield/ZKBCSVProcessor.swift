import Foundation

/// Processes ZKB CSV statements and maps them to `MyBankRecord` entries.
/// The CSV is expected to use Swiss date and decimal formats.
struct ZKBCSVProcessor {
    private let parser: CSVParsingService
    private let dateFormatter: DateFormatter

    init(parser: CSVParsingService = CSVParsingService()) {
        self.parser = parser
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "dd.MM.yyyy"
    }

    /// Parses a CSV file at the given URL into bank records.
    /// - Parameters:
    ///   - url: Statement file URL.
    ///   - progress: Optional progress callback.
    /// - Returns: Parsed bank records.
    func process(url: URL, progress: ((String) -> Void)? = nil) throws -> [MyBankRecord] {
        progress?("Opening \(url.lastPathComponent)")
        let content = try String(contentsOf: url, encoding: .utf8)
        let rawRows = parser.parse(csvString: content)
        progress?("Rows found: \(rawRows.count)")
        var results: [MyBankRecord] = []
        for (idx, row) in rawRows.enumerated() {
            let debug = row.map { "\($0)=\($1)" }.joined(separator: ", ")
            progress?("Row \(idx + 1) raw: \(debug)")
            guard let dateStr = row["Valutadatum"],
                  let date = dateFormatter.date(from: dateStr) else {
                progress?("Row \(idx + 1) skipped - invalid date")
                continue
            }
            let amountString = (row["Betrag"] ?? "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            guard let amount = Double(amountString) else {
                progress?("Row \(idx + 1) skipped - invalid amount")
                continue
            }
            let record = MyBankRecord(
                transactionDate: date,
                description: row["Buchungstext"] ?? row["Beschreibung"] ?? "",
                amount: amount,
                currency: row["Währung"] ?? row["Currency"] ?? "CHF",
                bankAccount: row["Kontonummer"] ?? row["Account"] ?? ""
            )
            results.append(record)
            progress?("Row \(idx + 1) parsed")
        }
        progress?("Finished parsing: \(results.count) records")
        return results
    }
}
