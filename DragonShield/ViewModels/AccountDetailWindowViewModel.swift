import SwiftUI

final class AccountDetailWindowViewModel: ObservableObject {
    @Published var account: DatabaseManager.AccountData
    @Published var positions: [DatabaseManager.EditablePositionData] = []
    @Published var showSaved = false

    private var dbManager: DatabaseManager?
    private var originalPositions: [DatabaseManager.EditablePositionData] = []

    init(account: DatabaseManager.AccountData) {
        self.account = account
    }

    func configure(db: DatabaseManager) {
        self.dbManager = db
        loadData()
        originalPositions = positions
    }

    func loadData() {
        guard let db = dbManager else { return }
        positions = db.fetchEditablePositions(accountId: account.id)
        if let updated = db.fetchAccountDetails(id: account.id) {
            account = updated
        }
    }

    func update(position: DatabaseManager.EditablePositionData) {
        guard let db = dbManager else { return }
        _ = db.updatePositionReport(
            id: position.id,
            importSessionId: position.importSessionId,
            accountId: position.accountId,
            institutionId: position.institutionId,
            instrumentId: position.instrumentId,
            quantity: position.quantity,
            purchasePrice: position.purchasePrice,
            currentPrice: position.currentPrice,
            instrumentUpdatedAt: position.instrumentUpdatedAt,
            notes: position.notes,
            reportDate: position.reportDate
        )
        db.refreshEarliestInstrumentTimestamp(accountId: account.id)
        if let updated = db.fetchAccountDetails(id: account.id) {
            account = updated
        }
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showSaved = false
        }
    }

    func saveAll() {
        guard let db = dbManager else { return }
        for p in positions {
            _ = db.updatePositionReport(
                id: p.id,
                importSessionId: p.importSessionId,
                accountId: p.accountId,
                institutionId: p.institutionId,
                instrumentId: p.instrumentId,
                quantity: p.quantity,
                purchasePrice: p.purchasePrice,
                currentPrice: p.currentPrice,
                instrumentUpdatedAt: p.instrumentUpdatedAt,
                notes: p.notes,
                reportDate: p.reportDate
            )
        }
        db.refreshEarliestInstrumentTimestamp(accountId: account.id)
        if let updated = db.fetchAccountDetails(id: account.id) {
            account = updated
        }
    }

    func revertChanges() {
        guard let db = dbManager else { return }
        for p in originalPositions {
            _ = db.updatePositionReport(
                id: p.id,
                importSessionId: p.importSessionId,
                accountId: p.accountId,
                institutionId: p.institutionId,
                instrumentId: p.instrumentId,
                quantity: p.quantity,
                purchasePrice: p.purchasePrice,
                currentPrice: p.currentPrice,
                instrumentUpdatedAt: p.instrumentUpdatedAt,
                notes: p.notes,
                reportDate: p.reportDate
            )
        }
        db.refreshEarliestInstrumentTimestamp(accountId: account.id)
        if let updated = db.fetchAccountDetails(id: account.id) {
            account = updated
        }
    }
}
