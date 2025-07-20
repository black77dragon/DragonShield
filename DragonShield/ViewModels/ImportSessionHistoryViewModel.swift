import Foundation
import SwiftUI

class ImportSessionHistoryViewModel: ObservableObject {
    @Published var sessions: [SessionRow] = []

    struct SessionRow: Identifiable, Equatable {
        var data: DatabaseManager.ImportSessionData
        var totalValue: Double
        var id: Int { data.id }
    }

    func load(db: DatabaseManager) {
        DispatchQueue.global(qos: .userInitiated).async {
            let rows = db.fetchImportSessions()
            let result = rows.map { SessionRow(data: $0, totalValue: db.totalReportValue(for: $0.id)) }
            DispatchQueue.main.async {
                self.sessions = result
            }
        }
    }
}
