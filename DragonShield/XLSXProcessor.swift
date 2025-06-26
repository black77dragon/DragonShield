// DragonShield/XLSXProcessor.swift
// MARK: - Version 1.0.1.0
// MARK: - History
// - 1.0.0.2 -> 1.0.1.0: Adapted processor for XLSX files.

import Foundation

enum XLSXProcessorError: LocalizedError {
    case invalidFileExtension(expected: String, actual: String)
    case unsupportedArchive

    var errorDescription: String? {
        switch self {
        case .invalidFileExtension(let expected, let actual):
            return "Error: The uploaded file is in an incorrect format.\nExpected: \(expected)\nReceived: \(actual)"
        case .unsupportedArchive:
            return "Could not read XLSX archive"
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
        return try rawRows.map { try validator.validate(rawRecord: $0) }
    }
}
