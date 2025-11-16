// DragonShield/XLSXProcessor.swift

// MARK: - Version 1.0.1.1

// MARK: - History

// - 1.0.0.2 -> 1.0.1.0: Adapted processor for XLSX files.
// - 1.0.1.0 -> 1.0.1.1: Include row information when validation fails.

import Foundation

enum XLSXProcessorError: LocalizedError {
    case invalidFileExtension(expected: String, actual: String)
    case unsupportedArchive
    case validationFailed(row: Int, message: String)

    var errorDescription: String? {
        switch self {
        case let .invalidFileExtension(expected, actual):
            return "Error: The uploaded file is in an incorrect format.\nExpected: \(expected)\nReceived: \(actual)"
        case .unsupportedArchive:
            return "Could not read XLSX archive"
        case let .validationFailed(row, message):
            return "Row \(row): \(message)"
        }
    }
}

class XLSXProcessor {
    private let parser: XLSXParsingService
    private let validator: DataValidationService

    init(parser: XLSXParsingService = XLSXParsingService(), validator: DataValidationService = DataValidationService()) {
        self.parser = parser
        self.validator = validator
    }

    func processXLSXFile(url: URL) throws -> [MyBankRecord] {
        guard url.pathExtension.lowercased() == "xlsx" else {
            throw XLSXProcessorError.invalidFileExtension(expected: ".xlsx", actual: "." + url.pathExtension)
        }
        let rawRows = try parser.parseWorkbook(at: url)
        var records: [MyBankRecord] = []
        for (idx, row) in rawRows.enumerated() {
            do {
                let record = try validator.validate(rawRecord: row)
                records.append(record)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                throw XLSXProcessorError.validationFailed(row: idx + 1, message: message)
            }
        }
        return records
    }
}
