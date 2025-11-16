// DragonShield/CSVProcessor.swift

// MARK: - Version 1.0.0.1

// MARK: - History

// - 0.0.0.0 -> 1.0.0.0: Initial orchestrator combining parsing and validation.
// - 1.0.0.0 -> 1.0.0.1: Add fallback encoding support when reading CSV files.

import Foundation

class CSVProcessor {
    private let parser: CSVParsingService
    private let validator: DataValidationService

    init(parser: CSVParsingService = CSVParsingService(), validator: DataValidationService = DataValidationService()) {
        self.parser = parser
        self.validator = validator
    }

    private func readCSV(from url: URL) throws -> String {
        // Try UTF-8 first, then fall back to common legacy encodings
        let encodings: [String.Encoding] = [.utf8, .isoLatin1, .macOSRoman, .windowsCP1252]
        for encoding in encodings {
            if let content = try? String(contentsOf: url, encoding: encoding) {
                return content
            }
        }
        // If all attempts fail, signal unsupported encoding
        throw NSError(domain: "CSVProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file encoding"])
    }

    func processCSVFile(url: URL) throws -> [MyBankRecord] {
        let content = try readCSV(from: url)
        let rawRows = parser.parse(csvString: content)
        return try rawRows.map { try validator.validate(rawRecord: $0) }
    }
}
