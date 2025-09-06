import SwiftUI

struct AlertEventsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [(id: Int, alertId: Int, alertName: String, occurredAt: String, status: String, message: String?)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Alert Events").font(.title3).bold(); Spacer() ; Button("Refresh", action: load) }
            Table(rows, selection: .constant(nil)) {
                TableColumn("When") { r in Text(r.occurredAt).font(.system(.caption, design: .monospaced)) }.width(200)
                TableColumn("Alert") { r in Text(r.alertName) }
                TableColumn("Status") { r in Text(r.status.capitalized) }.width(100)
                TableColumn("Message") { r in Text(r.message ?? "") }
            }
            .frame(minHeight: 320)
        }
        .padding(16)
        .onAppear(perform: load)
    }

    private func load() { rows = dbManager.listAlertEvents(limit: 300) }
}

