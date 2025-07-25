import SwiftUI

class AccountDetailWindowViewModel: ObservableObject {
    @Published var account: DatabaseManager.AccountData?
    @Published var positions: [EditablePosition] = []
    @Published var saveError: String?

    struct EditablePosition: Identifiable {
        let id: Int
        let instrument: String
        var quantity: Double
        var currentPrice: Double?
        var instrumentDate: Date?
    }

    private var accountId: Int
    private unowned var dbManager: DatabaseManager

    init(accountId: Int, dbManager: DatabaseManager) {
        self.accountId = accountId
        self.dbManager = dbManager
        load()
    }

    func load() {
        account = dbManager.fetchAccountDetails(id: accountId)
        positions = dbManager.fetchPositionReports(accountId: accountId).map {
            EditablePosition(id: $0.id,
                              instrument: $0.instrumentName,
                              quantity: $0.quantity,
                              currentPrice: $0.currentPrice,
                              instrumentDate: $0.instrumentUpdatedAt)
        }.sorted { ($0.quantity * ($0.currentPrice ?? 0)) > ($1.quantity * ($1.currentPrice ?? 0)) }
    }

    func save() {
        for pos in positions {
            let ok = dbManager.updatePositionValues(id: pos.id,
                                                    quantity: pos.quantity,
                                                    currentPrice: pos.currentPrice,
                                                    instrumentUpdatedAt: pos.instrumentDate)
            if !ok { saveError = "Failed to save position \(pos.id)" }
        }
        _ = dbManager.refreshEarliestInstrumentTimestamp(accountId: accountId)
        load()
    }
}
