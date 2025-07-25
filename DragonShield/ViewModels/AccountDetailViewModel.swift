import Foundation
import SwiftUI

class AccountDetailViewModel: ObservableObject {
    @Published var account: DatabaseManager.AccountData?
    @Published var positions: [PositionReportData] = []

    private let accountId: Int
    private weak var db: DatabaseManager?

    init(accountId: Int, db: DatabaseManager? = nil) {
        self.accountId = accountId
        self.db = db
    }

    func load(db: DatabaseManager? = nil) {
        if let db { self.db = db }
        guard let db = self.db else { return }
        account = db.fetchAccountDetails(id: accountId)
        positions = db.fetchPositionReports(accountId: accountId)
            .sorted { ($0.currentPrice ?? 0) * $0.quantity > ($1.currentPrice ?? 0) * $1.quantity }
    }

    func update(position: PositionReportData) {
        guard let db = db else { return }
        _ = db.updatePositionValues(id: position.id,
                                    quantity: position.quantity,
                                    currentPrice: position.currentPrice,
                                    instrumentUpdatedAt: position.instrumentUpdatedAt)
        db.refreshEarliestInstrumentTimestamp(accountId: accountId)
        load()
    }
}
