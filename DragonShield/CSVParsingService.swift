// DragonShield/CSVParsingService.swift
// MARK: - Version 1.0.0.2
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial basic CSV parsing implementation.
// - 1.0.0.0 -> 1.0.0.1: Fix newline splitting logic.
// - 1.0.0.1 -> 1.0.0.2: Support quoted fields and avoid key path compilation issues.

import Foundation

struct CSVParsingService {
    func parse(csvString: String, delimiter: Character = ",") -> [[String: String]] {
        var rows: [[String: String]] = []
        let rawLines = csvString.split(whereSeparator: { $0.isNewline }).map(String.init)
        guard let headerLine = rawLines.first else { return rows }

        let headers = headerLine.split(separator: delimiter).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in rawLines.dropFirst() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }

            var values: [String] = []
            var current = ""
            var insideQuotes = false

            for char in line {
                if char == "\"" {
                    insideQuotes.toggle()
                } else if char == delimiter && !insideQuotes {
                    values.append(current)
                    current.removeAll()
                } else {
                    current.append(char)
                }
            }
            values.append(current)

            let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var dict: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                dict[header] = index < cleaned.count ? cleaned[index] : ""
            }
            rows.append(dict)
        }

        return rows
    }
}
