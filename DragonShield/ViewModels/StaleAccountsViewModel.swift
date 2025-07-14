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
            .sorted(by: Self.earliestFirst)
            .prefix(10)
            .map { $0 }
    }

    private static func earliestFirst(_ a: DatabaseManager.AccountData,
                                      _ b: DatabaseManager.AccountData) -> Bool {
        let lhs = a.earliestInstrumentLastUpdatedAt ?? Date.distantFuture
        let rhs = b.earliestInstrumentLastUpdatedAt ?? Date.distantFuture
        return lhs < rhs
    }

    func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}
