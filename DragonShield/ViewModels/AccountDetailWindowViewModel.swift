import SwiftUI

final class AccountDetailWindowViewModel: ObservableObject {
    @Published var account: DatabaseManager.AccountData
    @Published var positions: [DatabaseManager.EditablePositionData] = []
    @Published var showSaved = false
    @Published var pendingPriceConfirmation: PriceSaveConfirmation?

    private var dbManager: DatabaseManager?
    private var originalPositions: [DatabaseManager.EditablePositionData] = []

    struct PriceSaveConfirmation: Equatable {
        let instrumentName: String
        let price: Double
        let currency: String
        let asOf: Date
    }

    init(account: DatabaseManager.AccountData) {
        self.account = account
    }

    func configure(db: DatabaseManager) {
        dbManager = db
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
        let originalsById = Dictionary(uniqueKeysWithValues: originalPositions.map { ($0.id, $0) })
        var firstConfirmation: PriceSaveConfirmation?

        for index in positions.indices {
            let normalizedAsOf = normalizedDate(for: positions[index])
            positions[index].instrumentUpdatedAt = normalizedAsOf
            let pos = positions[index]
            let original = originalsById[pos.id]

            if let price = pos.currentPrice,
               shouldPersistLatestPrice(new: pos, original: original)
            {
                let asOfDate = normalizedAsOf ?? startOfDay(Date())
                let asOfString = DateFormatter.iso8601DateOnly.string(from: asOfDate)
                let ok = db.upsertPrice(
                    instrumentId: pos.instrumentId,
                    price: price,
                    currency: pos.instrumentCurrency,
                    asOf: asOfString,
                    source: "manual"
                )
                if ok && firstConfirmation == nil {
                    firstConfirmation = PriceSaveConfirmation(
                        instrumentName: pos.instrumentName,
                        price: price,
                        currency: pos.instrumentCurrency,
                        asOf: asOfDate
                    )
                }
            }

            _ = db.updatePositionReport(
                id: pos.id,
                importSessionId: pos.importSessionId,
                accountId: pos.accountId,
                institutionId: pos.institutionId,
                instrumentId: pos.instrumentId,
                quantity: pos.quantity,
                purchasePrice: pos.purchasePrice,
                currentPrice: pos.currentPrice,
                instrumentUpdatedAt: positions[index].instrumentUpdatedAt,
                notes: pos.notes,
                reportDate: pos.reportDate
            )
        }

        if firstConfirmation != nil {
            db.refreshEarliestInstrumentTimestamps { _ in }
        }
        loadData()
        pendingPriceConfirmation = firstConfirmation
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.showSaved = false
        }
    }

    func discardChanges() {
        positions = originalPositions
    }

    func clearPendingPriceConfirmation() {
        pendingPriceConfirmation = nil
    }

    func originalPriceInfo(for positionId: Int) -> (price: Double?, asOf: Date?)? {
        guard let match = originalPositions.first(where: { $0.id == positionId }) else { return nil }
        return (price: match.currentPrice, asOf: match.instrumentUpdatedAt)
    }

    private func shouldPersistLatestPrice(new: DatabaseManager.EditablePositionData,
                                          original: DatabaseManager.EditablePositionData?) -> Bool
    {
        guard let newPrice = new.currentPrice else { return false }
        guard let original else { return true }
        if original.currentPrice == nil { return true }
        if let oldPrice = original.currentPrice, abs(oldPrice - newPrice) > 0.0000001 {
            return true
        }
        let oldDate = original.instrumentUpdatedAt.map(startOfDay)
        let newDate = new.instrumentUpdatedAt.map(startOfDay)
        return oldDate != newDate
    }

    private func normalizedDate(for position: DatabaseManager.EditablePositionData) -> Date? {
        if let date = position.instrumentUpdatedAt {
            return startOfDay(date)
        }
        if position.currentPrice != nil {
            return startOfDay(Date())
        }
        return nil
    }

    private func startOfDay(_ date: Date) -> Date {
        var utcCalendar = Calendar(identifier: .iso8601)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return utcCalendar.startOfDay(for: date)
    }
}
