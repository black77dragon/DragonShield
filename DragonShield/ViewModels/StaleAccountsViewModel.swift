import Foundation
import SwiftUI

class StaleAccountsViewModel: ObservableObject {
    @Published var staleAccounts: [DatabaseManager.AccountData] = []

    private var dbManager: DatabaseManager?

    init(dbManager: DatabaseManager? = nil) {
        self.dbManager = dbManager
        if dbManager != nil {
            loadStaleAccounts()
        }
    }

    func loadStaleAccounts(db: DatabaseManager? = nil) {
        if let db { self.dbManager = db }
        guard let dbManager else { return }
        let accounts = dbManager.fetchAccounts()
        staleAccounts = accounts
            .sorted(by: Self.earliestThenName)
    }

    private static func earliestThenName(_ a: DatabaseManager.AccountData,
                                         _ b: DatabaseManager.AccountData) -> Bool {
        let lhsDate = a.earliestInstrumentLastUpdatedAt ?? Date.distantFuture
        let rhsDate = b.earliestInstrumentLastUpdatedAt ?? Date.distantFuture
        if lhsDate == rhsDate {
            return a.accountName.localizedCaseInsensitiveCompare(b.accountName) == .orderedAscending
        }
        return lhsDate < rhsDate
    }

    func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}
