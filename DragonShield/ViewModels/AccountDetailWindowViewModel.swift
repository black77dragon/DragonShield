import SwiftUI

final class AccountDetailWindowViewModel: ObservableObject {
    @Published var account: DatabaseManager.AccountData
    @Published var positions: [DatabaseManager.EditablePositionData] = []
    @Published var showSaved = false
    @Published var pendingPriceConfirmation: PriceSaveConfirmation?
    @Published var priceSortDirection: PriceSortDirection = .ascending

    private var dbManager: DatabaseManager?
    private var originalPositions: [DatabaseManager.EditablePositionData] = []
    private var originalPositionsById: [Int: DatabaseManager.EditablePositionData] = [:]

    struct PriceSaveConfirmation: Equatable {
        let instrumentName: String
        let price: Double
        let currency: String
        let asOf: Date
    }

    init(account: DatabaseManager.AccountData) {
        self.account = account
    }

    enum PriceSortDirection {
        case ascending
        case descending
    }

    func configure(db: DatabaseManager) {
        dbManager = db
        loadData()
    }

    func loadData() {
        guard let db = dbManager else { return }
        let fetched = db.fetchEditablePositions(accountId: account.id)
        positions = sortPositions(fetched, direction: priceSortDirection)
        originalPositions = positions
        originalPositionsById = Dictionary(uniqueKeysWithValues: positions.map { ($0.id, $0) })
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
        positions = sortPositions(originalPositions, direction: priceSortDirection)
    }

    func clearPendingPriceConfirmation() {
        pendingPriceConfirmation = nil
    }

    func baselinePosition(for id: Int) -> DatabaseManager.EditablePositionData? {
        originalPositionsById[id]
    }

    func setPriceSortDirection(_ direction: PriceSortDirection) {
        priceSortDirection = direction
        positions = sortPositions(positions, direction: direction)
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

    private func sortPositions(_ items: [DatabaseManager.EditablePositionData],
                               direction: PriceSortDirection) -> [DatabaseManager.EditablePositionData]
    {
        items.sorted { lhs, rhs in
            switch (lhs.instrumentUpdatedAt, rhs.instrumentUpdatedAt) {
            case (nil, nil):
                return lhs.instrumentName.localizedCaseInsensitiveCompare(rhs.instrumentName) == .orderedAscending
            case (nil, _):
                return false
            case (_, nil):
                return true
            case let (lhsDate?, rhsDate?):
                if lhsDate == rhsDate {
                    return lhs.instrumentName.localizedCaseInsensitiveCompare(rhs.instrumentName) == .orderedAscending
                }
                return direction == .ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }
        }
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
