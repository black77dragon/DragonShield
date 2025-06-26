// DragonShield/CSVProcessor.swift
// MARK: - Version 1.0.0.2
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial orchestrator combining parsing and validation.
// - 1.0.0.0 -> 1.0.0.1: Add fallback encoding support when reading CSV files.
// - 1.0.0.1 -> 1.0.0.2: Provide clearer error for invalid file extension and encoding.

import Foundation

enum CSVProcessorError: LocalizedError {
    case invalidFileExtension(expected: String, actual: String)
    case unsupportedEncoding

    var errorDescription: String? {
        switch self {
        case .invalidFileExtension(let expected, let actual):
            return "Error: The uploaded file is in an incorrect format.\nExpected: \(expected)\nReceived: \(actual)"
        case .unsupportedEncoding:
            return "Unsupported file encoding"
        }
    }
}

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
        throw CSVProcessorError.unsupportedEncoding
    }

    func processCSVFile(url: URL) throws -> [MyBankRecord] {
        guard url.pathExtension.lowercased() == "csv" else {
            throw CSVProcessorError.invalidFileExtension(expected: ".csv", actual: "." + url.pathExtension)
        }
        let content = try readCSV(from: url)
        let rawRows = parser.parse(csvString: content)
        return try rawRows.map { try validator.validate(rawRecord: $0) }
    }
}
