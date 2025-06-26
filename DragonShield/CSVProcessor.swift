// DragonShield/CSVProcessor.swift
// MARK: - Version 1.0.0.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial orchestrator combining parsing and validation.

import Foundation

class CSVProcessor {
    private let parser: CSVParsingService
    private let validator: DataValidationService

    init(parser: CSVParsingService = CSVParsingService(), validator: DataValidationService = DataValidationService()) {
        self.parser = parser
        self.validator = validator
    }

    func processCSVFile(url: URL) throws -> [MyBankRecord] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rawRows = parser.parse(csvString: content)
        return try rawRows.map { try validator.validate(rawRecord: $0) }
    }
}
