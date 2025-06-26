// DragonShield/CSVParsingService.swift
// MARK: - Version 1.0.0.1
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial basic CSV parsing implementation.
// - 1.0.0.0 -> 1.0.0.1: Fix newline splitting logic.

import Foundation

struct CSVParsingService {
    func parse(csvString: String, delimiter: Character = ",") -> [[String: String]] {
        var rows: [[String: String]] = []
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return rows }
        let headers = headerLine.split(separator: delimiter).map { String($0).trimmingCharacters(in: .whitespaces) }
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let values = line.split(separator: delimiter, omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            var dict: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                dict[header] = index < values.count ? values[index] : ""
            }
            rows.append(dict)
        }
        return rows
    }
}
