import SwiftUI

final class AccountDetailWindowViewModel: ObservableObject {
    @Published var account: DatabaseManager.AccountData
    @Published var positions: [DatabaseManager.EditablePositionData] = []

    private var dbManager: DatabaseManager?

    init(account: DatabaseManager.AccountData) {
        self.account = account
    }

    func configure(db: DatabaseManager) {
        self.dbManager = db
        loadData()
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
        loadData()
    }
}
