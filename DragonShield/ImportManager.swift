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
import SwiftUI
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
        case save(name: String, subClassId: Int, currency: String, ticker: String?, isin: String?, sector: String?)
        case ignore
        case abort
    }

    enum AccountPromptResult {
        case save(name: String, institutionId: Int, number: String, accountTypeId: Int, currency: String)
        case cancel
        case abort
    }

    enum ImportError: Error {
        case aborted
    }


    private func promptForInstrument(record: ParsedPositionRecord) -> InstrumentPromptResult {
        var result: InstrumentPromptResult = .ignore
        let view = InstrumentPromptView(
            name: record.instrumentName,
            ticker: record.tickerSymbol ?? "",
            isin: record.isin ?? "",
            currency: record.currency
        ) { action in
            result = action
            NSApp.stopModal()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Add Instrument"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: view)
        NSApp.runModal(for: window)
        return result
    }

    private func promptForAccount(number: String, currency: String) -> AccountPromptResult {
        var result: AccountPromptResult = .cancel
        let instId = dbManager.findInstitutionId(name: "ZKB") ?? 1
        let typeId = dbManager.findAccountTypeId(code: "CUSTODY") ?? 1
        let view = AccountPromptView(accountName: "ZKB Custody Account",
                                     accountNumber: number,
                                     institutionId: instId,
                                     accountTypeId: typeId,
                                     currencyCode: currency) { action in
            result = action
            NSApp.stopModal()
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Add Account"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: view.environmentObject(dbManager))
        NSApp.runModal(for: window)
        return result
    }

    private func promptForPosition(record: ParsedPositionRecord) -> RecordPromptResult {
        var mutable = record
        var result: RecordPromptResult = .ignore
        let view = PositionReviewView(record: mutable) { action in
            result = action
            NSApp.stopModal()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Review Position"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: view)
        NSApp.runModal(for: window)
        // capture updated record if Save was chosen
        if case .save(let updated) = result {
            mutable = updated
            result = .save(mutable)
        }
        return result
    }

    private func showImportSummary(fileName: String, account: String?, valueDate: Date?, validRows: Int) {
        let view = ImportSummaryView(fileName: fileName,
                                     accountNumber: account,
                                     valueDate: valueDate,
                                     validRows: validRows) {
            NSApp.stopModal()
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 350),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Import Details"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: view)
        NSApp.runModal(for: window)
    }

    private func showStatusAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
    func importPositions(at url: URL, deleteExisting: Bool = false, progress: ((String) -> Void)? = nil, completion: @escaping (Result<PositionImportSummary, Error>) -> Void) {
        LoggingService.shared.clearLog()
        let logger: (String) -> Void = { message in
            LoggingService.shared.log(message, type: .info, logger: .parser)
            progress?(message)
        }
        LoggingService.shared.log("Importing positions: \(url.lastPathComponent)", type: .info, logger: .parser)
        DispatchQueue.global(qos: .userInitiated).async {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            if deleteExisting {
                let removed = self.deleteZKBPositions()
                LoggingService.shared.log("Existing ZKB positions removed: \(removed)", type: .info, logger: .database)
            }
            do {
                let (summary, rows) = try self.positionParser.parse(url: url, progress: logger)
                DispatchQueue.main.sync {
                    let first = rows.first
                    self.showImportSummary(fileName: url.lastPathComponent,
                                           account: first?.accountNumber,
                                           valueDate: first?.reportDate,
                                           validRows: summary.parsedRows)
                }

                let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
                let fileSize = (attrs[.size] as? NSNumber)?.intValue ?? 0
                let hash = url.sha256() ?? ""
               let valueDate = rows.first?.reportDate ?? Date()
               let baseSessionName = "ZKB Positions \(DateFormatter.swissDate.string(from: valueDate))"
               let sessionName = self.dbManager.nextImportSessionName(base: baseSessionName)
                let fileType = url.pathExtension.uppercased()

                let custodyNumber = rows.first?.accountNumber ?? ""
                var accountId = self.dbManager.findAccountId(accountNumber: custodyNumber)
                LoggingService.shared.log("Lookup account for \(custodyNumber) -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                if accountId == nil {
                    accountId = self.dbManager.findAccountId(accountNumber: custodyNumber, nameContains: "ZKB")
                    LoggingService.shared.log("Lookup with name filter -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                }
                while accountId == nil {
                    var accAction: AccountPromptResult = .cancel
                    DispatchQueue.main.sync {
                        accAction = self.promptForAccount(number: custodyNumber,
                                                         currency: rows.first?.currency ?? "CHF")
                    }
                    switch accAction {
                    case let .save(name, instId, number, typeId, curr):
                        _ = self.dbManager.addAccount(accountName: name,
                                                       institutionId: instId,
                                                       accountNumber: number,
                                                       accountTypeId: typeId,
                                                       currencyCode: curr,
                                                       openingDate: nil,
                                                       closingDate: nil,
                                                       includeInPortfolio: true,
                                                       isActive: true,
                                                       notes: nil)
                        accountId = self.dbManager.findAccountId(accountNumber: number)
                        LoggingService.shared.log("Post-create lookup -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                        if accountId == nil {
                            accountId = self.dbManager.findAccountId(accountNumber: number, nameContains: "ZKB")
                            LoggingService.shared.log("Post-create lookup with name filter -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                        }
                        if accountId != nil {
                            LoggingService.shared.log("Created account \(name)", type: .info, logger: .database)
                        }
                    case .cancel:
                        accountId = self.dbManager.findAccountId(accountNumber: custodyNumber)
                        LoggingService.shared.log("Retry lookup -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                        if accountId == nil {
                            accountId = self.dbManager.findAccountId(accountNumber: custodyNumber, nameContains: "ZKB")
                            LoggingService.shared.log("Retry lookup with name filter -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                        }
                        if accountId == nil {
                            DispatchQueue.main.sync {
                                self.showStatusAlert(title: "Account Required",
                                                      message: "Account \(custodyNumber) is required to save positions.")
                            }
                        }
                    case .abort:
                        throw ImportError.aborted
                    }
                }
                let accId = accountId!
                let accountInfo = self.dbManager.fetchAccountDetails(id: accId)
                let institutionId = accountInfo?.institutionId ?? self.dbManager.findInstitutionId(name: "ZKB") ?? 1

                let sessionId = self.dbManager.startImportSession(sessionName: sessionName,
                                                                  fileName: url.lastPathComponent,
                                                                  filePath: url.path,
                                                                  fileType: fileType,
                                                                  fileSize: fileSize,
                                                                  fileHash: hash,
                                                                  institutionId: institutionId)

                var success = 0
                var failure = 0
                for parsed in rows {
                    var action: RecordPromptResult = .save(parsed)
                    DispatchQueue.main.sync {
                        action = self.promptForPosition(record: parsed)
                    }
                    guard case let .save(row) = action else {
                        if case .abort = action { throw ImportError.aborted }
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
                        case let .save(name, subClassId, currency, ticker, isin, sector):
                            _ = self.dbManager.addInstrument(name: name,
                                                           subClassId: subClassId,
                                                           currency: currency,
                                                           tickerSymbol: ticker,
                                                           isin: isin,
                                                           countryCode: nil,
                                                           exchangeCode: nil,
                                                           sector: sector)
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
                    let report = PositionReport(importSessionId: sessionId,
                                                accountId: accId,
                                                institutionId: institutionId,
                                                instrumentId: insId,
                                                quantity: row.quantity,
                                                purchasePrice: row.purchasePrice,
                                                currentPrice: row.currentPrice,
                                                reportDate: row.reportDate)
                    do {
                        try self.positionRepository.saveReports([report])
                        success += 1
                        DispatchQueue.main.sync {
                            self.showStatusAlert(title: "Position Saved",
                                                  message: "Saved \(row.instrumentName)")
                        }
                    } catch {
                        failure += 1
                        DispatchQueue.main.sync {
                            self.showStatusAlert(title: "Save Failed",
                                                  message: error.localizedDescription)
                        }
                    }
                }
                if let sid = sessionId {
                    self.dbManager.completeImportSession(id: sid,
                                                       totalRows: summary.totalRows,
                                                       successRows: success,
                                                       failedRows: failure,
                                                       duplicateRows: 0,
                                                       notes: "will be determined later")
                }
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

    /// Deletes all ZKB position reports by selecting accounts linked to the ZKB institution.
    /// - Returns: The number of deleted records.
    func deleteZKBPositions() -> Int {
        let accounts = dbManager.fetchAccounts(institutionName: "ZKB")
        if !accounts.isEmpty {
            let numbers = accounts.map { $0.number }.joined(separator: ", ")
            LoggingService.shared.log("Deleting position reports for ZKB accounts: \(numbers)",
                                      type: .info, logger: .database)
        }
        return dbManager.deletePositionReports(institutionName: "ZKB")
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
