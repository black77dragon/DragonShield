import SwiftUI

class AccountDetailViewModel: ObservableObject {
    @Published var account: DatabaseManager.AccountData
    @Published var positions: [AccountPositionData] = []

    private let db: DatabaseManager
    private let accountId: Int

    init(accountId: Int, db: DatabaseManager) {
        self.db = db
        self.accountId = accountId
        self.account = db.fetchAccountDetails(id: accountId) ?? DatabaseManager.AccountData(id: accountId, accountName: "", institutionId: 0, institutionName: "", institutionBic: nil, accountNumber: "", accountType: "", accountTypeId: 0, currencyCode: "", openingDate: nil, closingDate: nil, earliestInstrumentLastUpdatedAt: nil, includeInPortfolio: true, isActive: true, notes: nil)
        load()
    }

    func load() {
        positions = db.fetchAccountPositions(accountId: accountId)
            .sorted { ($0.quantity * ($0.currentPrice ?? 0)) > ($1.quantity * ($1.currentPrice ?? 0)) }
        if let acc = db.fetchAccountDetails(id: accountId) {
            account = acc
        }
    }

    func saveAll() {
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
        db.updateEarliestInstrumentTimestamp(accountId: accountId)
        load()
    }
}
