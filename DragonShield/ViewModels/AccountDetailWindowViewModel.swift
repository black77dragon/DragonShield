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
    }

    func loadData() {
        guard let db = dbManager else { return }
        positions = db.fetchEditablePositions(accountId: account.id)
        originalPositions = positions
        if let updated = db.fetchAccountDetails(id: account.id) {
            account = updated
        }
    }

    func saveChanges() {
        guard let db = dbManager else { return }
        for pos in positions {
            _ = db.updatePositionReport(
                id: pos.id,
                importSessionId: pos.importSessionId,
                accountId: pos.accountId,
                institutionId: pos.institutionId,
                instrumentId: pos.instrumentId,
                quantity: pos.quantity,
                purchasePrice: pos.purchasePrice,
                currentPrice: pos.currentPrice,
                instrumentUpdatedAt: pos.instrumentUpdatedAt,
                notes: pos.notes,
                reportDate: pos.reportDate
            )
        }
        loadData()
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.showSaved = false
        }
    }

    func discardChanges() {
        positions = originalPositions
    }
}
