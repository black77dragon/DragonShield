// DragonShield/CSVParsingService.swift

// MARK: - Version 1.0.0.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Basic CSV parsing utility used for early prototypes.

import Foundation

/// Provides simple CSV parsing for comma-separated values.
struct CSVParsingService {
    /// Parses a CSV string into an array of dictionaries keyed by the header row.
    /// - Parameter csvString: The raw CSV text.
    /// - Returns: Array of rows as `[header: value]`.
    func parse(csvString: String) -> [[String: String]] {
        let lines = csvString.split(whereSeparator: { $0.isNewline }).map(String.init)
        guard let headerLine = lines.first else { return [] }
        let headers = headerLine.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        var records: [[String: String]] = []
        for line in lines.dropFirst() {
            let values = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            var row: [String: String] = [:]
            for (idx, header) in headers.enumerated() {
                row[header] = idx < values.count ? values[idx] : ""
            }
            records.append(row)
        }
        return records

    }
}
