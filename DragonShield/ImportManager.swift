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

    private func promptForInstrument(record: ParsedPositionRecord) -> (name: String, ticker: String?, isin: String?, currency: String)? {
        var nameField = NSTextField(string: record.instrumentName)
        var tickerField = NSTextField(string: record.tickerSymbol ?? "")
        var isinField = NSTextField(string: record.isin ?? "")
        var currencyField = NSTextField(string: record.currency)

        func row(label: String, field: NSTextField) -> NSStackView {
            field.frame = NSRect(x: 0, y: 0, width: 200, height: 22)
            let labelView = NSTextField(labelWithString: label)
            labelView.alignment = .right
            labelView.frame = NSRect(x: 0, y: 0, width: 80, height: 22)
            let stack = NSStackView(views: [labelView, field])
            stack.orientation = .horizontal
            stack.spacing = 8
            return stack
        }

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 8
        content.addArrangedSubview(row(label: "Name", field: nameField))
        content.addArrangedSubview(row(label: "Ticker", field: tickerField))
        content.addArrangedSubview(row(label: "ISIN", field: isinField))
        content.addArrangedSubview(row(label: "Currency", field: currencyField))

        let alert = NSAlert()
        alert.messageText = "New Instrument"
        alert.informativeText = "Provide details for the new instrument"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = content
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let ticker = tickerField.stringValue.trimmingCharacters(in: .whitespaces)
        let isin = isinField.stringValue.trimmingCharacters(in: .whitespaces)
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        let currency = currencyField.stringValue.trimmingCharacters(in: .whitespaces)
        return (name: name,
                ticker: ticker.isEmpty ? nil : ticker,
                isin: isin.isEmpty ? nil : isin,
                currency: currency.isEmpty ? record.currency : currency)
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
                for row in rows {
                    guard let accountId = self.dbManager.findAccountId(accountNumber: row.accountNumber) else {
                        LoggingService.shared.log("Account not found for \(row.accountNumber)", type: .error, logger: .database)
                        continue
                    }
                    var instrumentId: Int?
                    if let isin = row.isin {
                        instrumentId = self.dbManager.findInstrumentId(isin: isin)
                    }
                    if instrumentId == nil {
                        var details: (name: String, ticker: String?, isin: String?, currency: String)?
                        DispatchQueue.main.sync {
                            details = self.promptForInstrument(record: row)
                        }
                        guard let info = details else { continue }
                        _ = self.dbManager.addInstrument(name: info.name,
                                                           subClassId: 3,
                                                           currency: info.currency,
                                                           tickerSymbol: info.ticker,
                                                           isin: info.isin,
                                                           countryCode: nil,
                                                           exchangeCode: nil,
                                                           sector: nil)
                        if let searchIsin = info.isin ?? row.isin {
                            instrumentId = self.dbManager.findInstrumentId(isin: searchIsin)
                        }
                    }
                    guard let insId = instrumentId else {
                        LoggingService.shared.log("Instrument missing for \(row.instrumentName)", type: .error, logger: .database)
                        continue
                    }
                    let report = PositionReport(accountId: accountId, instrumentId: insId, quantity: row.quantity, reportDate: Date())
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
