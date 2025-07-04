// DragonShield/ImportManager.swift

// MARK: - Version 2.0.3.0
// MARK: - History
// - 1.11 -> 2.0.0.0: Rewritten to use native Swift XLSX processing instead of Python parser.
// - 2.0.0.0 -> 2.0.0.1: Replace deprecated allowedFileTypes API.
// - 2.0.0.1 -> 2.0.0.2: Begin security-scoped access when reading selected file.
// - 2.0.0.2 -> 2.0.0.3: Surface detailed file format errors from XLSXProcessor.
// - 2.0.0.3 -> 2.0.1.0: Expect XLSX files and use XLSXProcessor.
// - 2.0.1.0 -> 2.0.2.0: Integrate ZKBXLSXProcessor for ZKB statements.
// - 2.0.2.0 -> 2.0.2.1: Provide progress logging via callback.
// - 2.0.2.1 -> 2.0.2.2: Hold DB connection to avoid invalid pointer errors.
// - 2.0.2.2 -> 2.0.2.3: Propagate detailed repository errors.
// - 2.0.2.3 -> 2.0.2.4: Keep DB manager alive via repository reference.
// - 2.0.2.4 -> 2.0.2.5: Guard UTType initialization and minor cleanup.
// - 2.0.2.5 -> 2.0.2.6: Log import details to file and forward progress.
// - 2.0.2.6 -> 2.0.3.0: Route log messages through OSLog categories.
import Foundation
import AppKit
import UniformTypeIdentifiers

/// Manages document imports using the native XLSX processing pipeline.
class ImportManager {
    static let shared = ImportManager()
    private let xlsxProcessor = ZKBXLSXProcessor()
    private let positionParser = ZKBPositionParser()
    private let dbManager = DatabaseManager()
    private lazy var repository: BankRecordRepository = {
        BankRecordRepository(dbManager: dbManager)
    }()
    private lazy var positionRepository: PositionReportRepository = {
        PositionReportRepository(dbManager: dbManager)
    }()

    enum RecordPromptResult {
        case save(ParsedPositionRecord)
        case ignore
        case abort
    }

    enum InstrumentPromptResult {
        case save(name: String, ticker: String?, isin: String?, currency: String)
        case ignore
        case abort
    }

    enum ImportError: Error {
        case aborted
    }

    private func makeRow(label: String, field: NSTextField) -> NSStackView {
        field.translatesAutoresizingMaskIntoConstraints = false
        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        let stack = NSStackView(views: [labelView, field])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    private func promptForInstrument(record: ParsedPositionRecord) -> InstrumentPromptResult {
        let nameField = NSTextField(string: record.instrumentName)
        let tickerField = NSTextField(string: record.tickerSymbol ?? "")
        let isinField = NSTextField(string: record.isin ?? "")
        let currencyField = NSTextField(string: record.currency)

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addArrangedSubview(makeRow(label: "Name", field: nameField))
        content.addArrangedSubview(makeRow(label: "Ticker", field: tickerField))
        content.addArrangedSubview(makeRow(label: "ISIN", field: isinField))
        content.addArrangedSubview(makeRow(label: "Currency", field: currencyField))
        content.widthAnchor.constraint(equalToConstant: 320).isActive = true

        let alert = NSAlert()
        alert.messageText = "Add Instrument"
        alert.informativeText = "Provide details for the new instrument"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Ignore")
        alert.addButton(withTitle: "Abort")
        alert.accessoryView = content
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            let ticker = tickerField.stringValue.trimmingCharacters(in: .whitespaces)
            let isin = isinField.stringValue.trimmingCharacters(in: .whitespaces)
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            let currency = currencyField.stringValue.trimmingCharacters(in: .whitespaces)
            return .save(name: name,
                         ticker: ticker.isEmpty ? nil : ticker,
                         isin: isin.isEmpty ? nil : isin,
                         currency: currency.isEmpty ? record.currency : currency)
        case .alertSecondButtonReturn:
            return .ignore
        default:
            return .abort
        }
    }

    private func promptForPosition(record: ParsedPositionRecord) -> RecordPromptResult {
        let accNumberField = NSTextField(string: record.accountNumber)
        let accNameField = NSTextField(string: record.accountName)
        let nameField = NSTextField(string: record.instrumentName)
        let tickerField = NSTextField(string: record.tickerSymbol ?? "")
        let isinField = NSTextField(string: record.isin ?? "")
        let currencyField = NSTextField(string: record.currency)
        let qtyField = NSTextField(string: String(record.quantity))

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addArrangedSubview(makeRow(label: "Account No", field: accNumberField))
        content.addArrangedSubview(makeRow(label: "Account Name", field: accNameField))
        content.addArrangedSubview(makeRow(label: "Instrument", field: nameField))
        content.addArrangedSubview(makeRow(label: "Ticker", field: tickerField))
        content.addArrangedSubview(makeRow(label: "ISIN", field: isinField))
        content.addArrangedSubview(makeRow(label: "Currency", field: currencyField))
        content.addArrangedSubview(makeRow(label: "Quantity", field: qtyField))
        content.widthAnchor.constraint(equalToConstant: 360).isActive = true

        let alert = NSAlert()
        alert.messageText = "Review Position"
        alert.informativeText = "Edit details or choose an action"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Ignore")
        alert.addButton(withTitle: "Abort")
        alert.accessoryView = content
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            let qty = Double(qtyField.stringValue) ?? record.quantity
            let newRecord = ParsedPositionRecord(accountNumber: accNumberField.stringValue,
                                                 accountName: accNameField.stringValue,
                                                 instrumentName: nameField.stringValue,
                                                 tickerSymbol: tickerField.stringValue.isEmpty ? nil : tickerField.stringValue,
                                                 isin: isinField.stringValue.isEmpty ? nil : isinField.stringValue,
                                                 currency: currencyField.stringValue,
                                                 quantity: qty,
                                                 reportDate: record.reportDate,
                                                 isCash: record.isCash)
            return .save(newRecord)
        case .alertSecondButtonReturn:
            return .ignore
        default:
            return .abort
        }
    }

    /// Parses a XLSX document and saves the records to the database.
    func parseDocument(at url: URL, progress: ((String) -> Void)? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        LoggingService.shared.clearLog()
        let logger: (String) -> Void = { message in
            LoggingService.shared.log(message, type: .info, logger: .parser)
            progress?(message)
        }
        LoggingService.shared.log("Importing file: \(url.lastPathComponent)", type: .info, logger: .parser)
        DispatchQueue.global(qos: .userInitiated).async {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            do {
                let records = try self.xlsxProcessor.process(url: url, progress: logger)
                LoggingService.shared.log("Parsed \(records.count) rows", type: .info, logger: .parser)
                try self.repository.saveRecords(records)
                LoggingService.shared.log("Saved records to database", type: .info, logger: .database)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(records)
                let json = String(data: data, encoding: .utf8) ?? "[]"
                DispatchQueue.main.async {
                    completion(.success(json))
                }
                LoggingService.shared.log("Import complete for \(url.lastPathComponent)", type: .info, logger: .parser)
            } catch {
                LoggingService.shared.log("Import failed: \(error.localizedDescription)", type: .error, logger: .parser)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Parses a ZKB statement and saves position reports.
    func importPositions(at url: URL, progress: ((String) -> Void)? = nil, completion: @escaping (Result<PositionImportSummary, Error>) -> Void) {
        LoggingService.shared.clearLog()
        let logger: (String) -> Void = { message in
            LoggingService.shared.log(message, type: .info, logger: .parser)
            progress?(message)
        }
        LoggingService.shared.log("Importing positions: \(url.lastPathComponent)", type: .info, logger: .parser)
        DispatchQueue.global(qos: .userInitiated).async {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            do {
                let (summary, rows) = try self.positionParser.parse(url: url, progress: logger)
                var reports: [PositionReport] = []
                for parsed in rows {
                    var action: RecordPromptResult = .save(parsed)
                    DispatchQueue.main.sync {
                        action = self.promptForPosition(record: parsed)
                    }
                    guard case let .save(row) = action else {
                        if case .abort = action { throw ImportError.aborted }
                        continue
                    }
                    var accountId = self.dbManager.findAccountId(accountNumber: row.accountNumber)
                    if accountId == nil {
                        let institutionId = self.dbManager.findInstitutionId(name: "ZKB") ?? 1
                        let typeCode = row.isCash ? "CASH" : "CUSTODY"
                        let accountTypeId = self.dbManager.findAccountTypeId(code: typeCode) ?? 1
                        let name = row.isCash ? row.accountName : "ZKB Custody \(row.accountNumber)"
                        let created = self.dbManager.addAccount(accountName: name,
                                                                institutionId: institutionId,
                                                                accountNumber: row.accountNumber,
                                                                accountTypeId: accountTypeId,
                                                                currencyCode: row.currency,
                                                                openingDate: nil,
                                                                closingDate: nil,
                                                                includeInPortfolio: true,
                                                                isActive: true,
                                                                notes: nil)
                        if created {
                            accountId = self.dbManager.findAccountId(accountNumber: row.accountNumber)
                            LoggingService.shared.log("Created account \(name)", type: .info, logger: .database)
                        }
                    }
                    guard let accId = accountId else {
                        LoggingService.shared.log("Account not found for \(row.accountNumber)", type: .error, logger: .database)
                        continue
                    }
                    var instrumentId: Int?
                    if let isin = row.isin {
                        instrumentId = self.dbManager.findInstrumentId(isin: isin)
                    }
                    if instrumentId == nil {
                        var instAction: InstrumentPromptResult = .ignore
                        DispatchQueue.main.sync {
                            instAction = self.promptForInstrument(record: row)
                        }
                        switch instAction {
                        case let .save(name, ticker, isin, currency):
                            _ = self.dbManager.addInstrument(name: name,
                                                           subClassId: 3,
                                                           currency: currency,
                                                           tickerSymbol: ticker,
                                                           isin: isin,
                                                           countryCode: nil,
                                                           exchangeCode: nil,
                                                           sector: nil)
                            if let searchIsin = isin ?? row.isin {
                                instrumentId = self.dbManager.findInstrumentId(isin: searchIsin)
                            }
                        case .ignore:
                            continue
                        case .abort:
                            throw ImportError.aborted
                        }
                    }
                    guard let insId = instrumentId else {
                        LoggingService.shared.log("Instrument missing for \(row.instrumentName)", type: .error, logger: .database)
                        continue
                    }
                    let report = PositionReport(accountId: accId, instrumentId: insId, quantity: row.quantity, reportDate: row.reportDate)
                    reports.append(report)
                }
                try self.positionRepository.saveReports(reports)
                LoggingService.shared.log("Saved position reports", type: .info, logger: .database)
                DispatchQueue.main.async {
                    completion(.success(summary))
                }
                LoggingService.shared.log("Position import complete", type: .info, logger: .parser)
            } catch {
                LoggingService.shared.log("Position import failed: \(error.localizedDescription)", type: .error, logger: .parser)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Presents an open panel and processes the selected XLSX file.
    func openAndParseDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if #available(macOS 12.0, *) {
            if let xlsxType = UTType(filenameExtension: "xlsx") {
                panel.allowedContentTypes = [xlsxType]
            }
        } else {
            panel.allowedFileTypes = ["xlsx"]
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.parseDocument(at: url, progress: { message in
                print("\u{1F4C4} \(message)")
            }) { result in
                switch result {
                case .success(let output):
                    print("\n📥 Import result:\n\(output)")
                case .failure(let error):
                    print("❌ Import failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Import Error"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
}
