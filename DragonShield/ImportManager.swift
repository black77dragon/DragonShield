// DragonShield/ImportManager.swift

// MARK: - Version 2.0.3.0
// MARK: - History
// - 1.11 -> 2.0.0.0: Rewritten to use native Swift XLSX processing instead of Python parser.
// - 2.0.0.0 -> 2.0.0.1: Replace deprecated allowedFileTypes API.
// - 2.0.0.1 -> 2.0.0.2: Begin security-scoped access when reading selected file.
// - 2.0.0.2 -> 2.0.0.3: Surface detailed file format errors from XLSXProcessor.
// - 2.0.0.3 -> 2.0.1.0: Expect XLSX files and use XLSXProcessor.
// - 2.0.1.0 -> 2.0.2.0: Integrate CreditSuisseXLSXProcessor for Credit-Suisse statements.
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
    private let xlsxProcessor = CreditSuisseXLSXProcessor()
    private let positionParser = CreditSuissePositionParser()
    private let zkbParser = ZKBStatementParser()
    private let dbManager = DatabaseManager()
    private lazy var repository: BankRecordRepository = {
        BankRecordRepository(dbManager: dbManager)
    }()
    private lazy var positionRepository: PositionReportRepository = {
        PositionReportRepository(dbManager: dbManager)
    }()

    private var checkpointsEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableParsingCheckpoints)
    }

    /// Returns the institution ID for Zürcher Kantonalbank using various name
    /// variants. Defaults to 1 if not found.
    private func zkbInstitutionId() -> Int {
        let names = ["Zürcher Kantonalbank ZKB", "Zürcher Kantonalbank", "ZKB"]
        for name in names {
            if let id = dbManager.findInstitutionId(name: name) { return id }
        }
        return 1
    }

    enum RecordPromptResult {
        case save(ParsedPositionRecord)
        case ignore
        case abort
    }

    enum InstrumentPromptResult {
        case save(name: String, subClassId: Int, currency: String, ticker: String?, isin: String?, valorNr: String?, sector: String?)
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

    enum StatementType {
        case creditSuisse
        case zkb
    }


    private func promptForInstrument(record: ParsedPositionRecord) -> InstrumentPromptResult {
        var result: InstrumentPromptResult = .ignore
        let view = InstrumentPromptView(
            name: record.instrumentName,
            ticker: record.tickerSymbol ?? "",
            isin: record.isin ?? "",
            valorNr: record.valorNr ?? "",
            currency: record.currency,
            subClassId: record.subClassIdGuess
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

    private func promptForAccount(number: String,
                                  currency: String,
                                  accountTypeCode: String = "CUSTODY") -> AccountPromptResult {
        var result: AccountPromptResult = .cancel
        let instId = dbManager.findInstitutionId(name: "Credit-Suisse") ?? 1
        let typeId = dbManager.findAccountTypeId(code: accountTypeCode) ?? 1
        let defaultName = accountTypeCode == "CASH" ? "Credit-Suisse Cash Account" : "Credit-Suisse Account"
        let view = AccountPromptView(accountName: defaultName,
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

    private func confirmCashAccount(name: String, currency: String, amount: Double) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Create Cash Account?"
        alert.informativeText = "Account: \(name)\nCurrency: \(currency)\nBalance: \(amount)"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Skip")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Looks up an instrument using valor number, ISIN and ticker symbol in priority order.
    /// Returns the matching ID or nil if none found. Logs the lookup result.
    private func lookupInstrumentId(name: String, valor: String?, isin: String?, ticker: String?) -> Int? {
        if let val = valor, !val.isEmpty, let id = dbManager.findInstrumentId(valorNr: val) {
            LoggingService.shared.log("Matched instrument \(name) (ID: \(id)) via valor", type: .info, logger: .parser)
            return id
        }
        if let i = isin, !i.isEmpty, let id = dbManager.findInstrumentId(isin: i) {
            LoggingService.shared.log("Matched instrument \(name) (ID: \(id)) via ISIN", type: .info, logger: .parser)
            return id
        }
        if let t = ticker, !t.isEmpty, let id = dbManager.findInstrumentId(ticker: t) {
            LoggingService.shared.log("Matched instrument \(name) (ID: \(id)) via ticker", type: .info, logger: .parser)
            return id
        }
        LoggingService.shared.log("Unmatched instrument description: \(name)", type: .info, logger: .parser)
        return nil
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
        // Enlarged window to prevent clipping of details
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 420),
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

    /// Parses a Credit-Suisse statement and saves position reports.
    func importPositions(at url: URL, type: StatementType = .creditSuisse, deleteExisting: Bool = false, progress: ((String) -> Void)? = nil, completion: @escaping (Result<PositionImportSummary, Error>) -> Void) {
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
                if type == .creditSuisse {
                    let removed = self.deleteCreditSuissePositions()
                    let msg = "Existing Credit-Suisse positions removed: \(removed)"
                    LoggingService.shared.log(msg, type: .info, logger: .database)
                    progress?(msg)
                } else if type == .zkb {
                    let removed = self.deleteZKBPositions()
                    let msg = "Existing ZKB positions removed: \(removed)"
                    LoggingService.shared.log(msg, type: .info, logger: .database)
                    progress?(msg)
                }
            }
            do {
                var (summary, rows) = try {
                    if type == .creditSuisse {
                        return try self.positionParser.parse(url: url, progress: logger)
                    } else {
                        return try self.zkbParser.parse(url: url, progress: logger)
                    }
                }()
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
               let institutionName = type == .creditSuisse ? "Credit-Suisse" : "Zürcher Kantonalbank ZKB"
               let institutionIdDefault = type == .creditSuisse ? (self.dbManager.findInstitutionId(name: institutionName) ?? 1) : self.zkbInstitutionId()
               let baseSessionName = "\(institutionName) Positions \(DateFormatter.swissDate.string(from: valueDate))"
               let sessionName = self.dbManager.nextImportSessionName(base: baseSessionName)
                let fileType = url.pathExtension.uppercased()

                let custodyNumber = rows.first?.accountNumber ?? ""
                var accountId = self.dbManager.findAccountId(accountNumber: custodyNumber)
                LoggingService.shared.log("Lookup account for \(custodyNumber) -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                if accountId == nil {
                    accountId = self.dbManager.findAccountId(accountNumber: custodyNumber, nameContains: institutionName)
                    LoggingService.shared.log("Lookup with name filter -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                }
                while accountId == nil {
                    if self.checkpointsEnabled {
                        var accAction: AccountPromptResult = .cancel
                    DispatchQueue.main.sync {
                        accAction = self.promptForAccount(number: custodyNumber,
                                                         currency: rows.first?.currency ?? "CHF",
                                                         accountTypeCode: "CUSTODY")
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
                        accountId = self.dbManager.findAccountId(accountNumber: number, nameContains: institutionName)
                            LoggingService.shared.log("Post-create lookup with name filter -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                        }
                        if accountId != nil {
                            LoggingService.shared.log("Created account \(name)", type: .info, logger: .database)
                        }
                    case .cancel:
                        accountId = self.dbManager.findAccountId(accountNumber: custodyNumber)
                        LoggingService.shared.log("Retry lookup -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                        if accountId == nil {
                        accountId = self.dbManager.findAccountId(accountNumber: custodyNumber, nameContains: institutionName)
                            LoggingService.shared.log("Retry lookup with name filter -> \(accountId?.description ?? "nil")", type: .debug, logger: .database)
                        }
                        if accountId == nil {
                            if self.checkpointsEnabled {
                                DispatchQueue.main.sync {
                                    self.showStatusAlert(title: "Account Required",
                                                          message: "Account \(custodyNumber) is required to save positions.")
                                }
                            }
                        }
                    case .abort:
                        throw ImportError.aborted
                    }
                    } else {
                        let instId = institutionIdDefault
                        let typeId = self.dbManager.findAccountTypeId(code: "CUSTODY") ?? 1
                        let defaultName = type == .creditSuisse ? "Credit-Suisse Account" : "ZKB Account"
                        _ = self.dbManager.addAccount(accountName: defaultName,
                                                       institutionId: instId,
                                                       accountNumber: custodyNumber,
                                                       accountTypeId: typeId,
                                                       currencyCode: rows.first?.currency ?? "CHF",
                                                       openingDate: nil,
                                                       closingDate: nil,
                                                       includeInPortfolio: true,
                                                       isActive: true,
                                                       notes: nil)
                        accountId = self.dbManager.findAccountId(accountNumber: custodyNumber)
                    }
                }
                let accId = accountId!
                let accountInfo = self.dbManager.fetchAccountDetails(id: accId)
                let institutionId = accountInfo?.institutionId ?? institutionIdDefault

                let sessionId = self.dbManager.startImportSession(sessionName: sessionName,
                                                                  fileName: url.lastPathComponent,
                                                                  filePath: url.path,
                                                                  fileType: fileType,
                                                                  fileSize: fileSize,
                                                                  fileHash: hash,
                                                                  institutionId: institutionId)

                var success = 0
                let failure = 0
                var unmatched = 0
                for parsed in rows {
                    if parsed.isCash {
                        let accNumber = parsed.tickerSymbol ?? ""
                        var accId = self.dbManager.findAccountId(accountNumber: accNumber)
                        if accId == nil {
                            var proceed = true
                            if self.checkpointsEnabled {
                                proceed = false
                                DispatchQueue.main.sync {
                                    proceed = self.confirmCashAccount(name: parsed.accountName,
                                                                      currency: parsed.currency,
                                                                      amount: parsed.quantity)
                                }
                            }
                            if proceed {
                                let instId = self.dbManager.findInstitutionId(name: "Credit-Suisse") ?? 1
                                let typeId = self.dbManager.findAccountTypeId(code: "CASH") ?? 5
                                _ = self.dbManager.addAccount(accountName: parsed.accountName,
                                                           institutionId: instId,
                                                           accountNumber: accNumber,
                                                           accountTypeId: typeId,
                                                           currencyCode: parsed.currency,
                                                           openingDate: nil,
                                                           closingDate: nil,
                                                           includeInPortfolio: true,
                                                           isActive: true,
                                                           notes: nil)
                                accId = self.dbManager.findAccountId(accountNumber: accNumber)
                            }
                        }
                        if let aId = accId,
                           let instrId = self.dbManager.findInstrumentId(ticker: "\(parsed.currency.uppercased())_CASH") {
                            _ = self.dbManager.addPositionReport(
                                importSessionId: sessionId,
                                accountId: aId,
                                institutionId: institutionId,
                                instrumentId: instrId,
                                quantity: parsed.quantity,
                                purchasePrice: nil,
                                currentPrice: nil,
                                instrumentUpdatedAt: parsed.reportDate,
                                notes: nil,
                                reportDate: parsed.reportDate
                            )
                            success += 1
                        }
                        continue
                    }

                    var action: RecordPromptResult = .save(parsed)
                    if self.checkpointsEnabled {
                        DispatchQueue.main.sync {
                            action = self.promptForPosition(record: parsed)
                        }
                    }
                    guard case let .save(row) = action else {
                        if case .abort = action { throw ImportError.aborted }
                        continue
                    }
                    var instrumentId = self.lookupInstrumentId(name: row.instrumentName,
                                                                valor: row.valorNr,
                                                                isin: row.isin,
                                                                ticker: row.tickerSymbol)
                    if instrumentId == nil {
                        unmatched += 1
                        var proceed = true
                        DispatchQueue.main.sync {
                            let alert = NSAlert()
                            alert.messageText = "Unknown Instrument"
                            alert.informativeText = "Instrument \(row.instrumentName) is not in the database. Please add it manually. Do you want to continue the upload?"
                            alert.addButton(withTitle: "Yes")
                            alert.addButton(withTitle: "No")
                            proceed = alert.runModal() == .alertFirstButtonReturn
                        }
                        if !proceed {
                            throw ImportError.aborted
                        }
                        continue
                    }
                    guard let insId = instrumentId else {
                        LoggingService.shared.log("Instrument missing for \(row.instrumentName)", type: .error, logger: .database)
                        continue
                    }
                    _ = self.dbManager.addPositionReport(
                        importSessionId: sessionId,
                        accountId: accId,
                        institutionId: institutionId,
                        instrumentId: insId,
                        quantity: row.quantity,
                        purchasePrice: row.purchasePrice,
                        currentPrice: row.currentPrice,
                        instrumentUpdatedAt: row.reportDate,
                        notes: nil,
                        reportDate: row.reportDate
                    )
                    success += 1
                    if self.checkpointsEnabled {
                        DispatchQueue.main.sync {
                            self.showStatusAlert(title: "Position Saved",
                                                  message: "Saved \(row.instrumentName)")
                        }
                    }
                }
                summary.unmatchedInstruments = unmatched
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

    /// Deletes all Credit-Suisse position reports by selecting accounts linked to the Credit-Suisse institution.
    /// - Returns: The number of deleted records.
    func deleteCreditSuissePositions() -> Int {
        let accounts = dbManager.fetchAccounts(institutionName: "Credit-Suisse")
        if !accounts.isEmpty {
            let numbers = accounts.map { $0.number }.joined(separator: ", ")
            LoggingService.shared.log("Deleting position reports for Credit-Suisse accounts: \(numbers)",
                                      type: .info, logger: .database)
        }
        return dbManager.deletePositionReports(institutionName: "Credit-Suisse")
    }

    /// Deletes all ZKB position reports by selecting accounts linked to the ZKB institution.
    /// - Returns: The number of deleted records.
    func deleteZKBPositions() -> Int {
        let name = "Zürcher Kantonalbank ZKB"
        let bic = "ZKBKCHZZ80A"
        var ids = dbManager.findInstitutionIds(name: name)
        ids.append(contentsOf: dbManager.findInstitutionIds(bic: bic))
        ids = Array(Set(ids))
        if ids.isEmpty { return 0 }
        let accounts = dbManager.fetchAccounts(institutionName: name)
        if !accounts.isEmpty {
            let numbers = accounts.map { $0.number }.joined(separator: ", ")
            LoggingService.shared.log("Deleting position reports for ZKB accounts: \(numbers)",
                                      type: .info, logger: .database)
        }
        return dbManager.deletePositionReports(institutionIds: ids)
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
