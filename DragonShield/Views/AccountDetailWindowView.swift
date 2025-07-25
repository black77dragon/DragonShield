import SwiftUI

struct AccountDetailWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager

    @StateObject private var viewModel: AccountDetailViewModel

    init(accountId: Int, db: DatabaseManager) {
        _viewModel = StateObject(wrappedValue: AccountDetailViewModel(accountId: accountId, db: db))
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        return f
    }()

    var body: some View {
        VStack(alignment: .leading) {
            header
            Table($viewModel.positions) {
                TableColumn("Instrument") { Text($0.wrappedValue.instrumentName) }
                TableColumn("Quantity") {
                    TextField(value: $0.quantity, formatter: Self.numberFormatter)
                        .frame(width: 80)
                }
                TableColumn("Current Price") {
                    TextField(value: Binding(get: { $0.currentPrice ?? 0 }, set: { $0.currentPrice = $0 == 0 ? nil : $0 }), formatter: Self.numberFormatter)
                        .frame(width: 80)
                }
                TableColumn("Updated") {
                    DatePicker("", selection: Binding(get: { $0.instrumentUpdatedAt ?? Date() }, set: { $0.instrumentUpdatedAt = $0 }), displayedComponents: .date)
                        .labelsHidden()
                }
            }
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 400)
        .onDisappear { viewModel.saveAll() }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text("Account Detail – \(viewModel.account.accountName)")
                .font(.title2.bold())
            if let date = viewModel.account.earliestInstrumentLastUpdatedAt {
                Text("Earliest Instrument Update: " + DateFormatter.swissDate.string(from: date))
            }
            Text(viewModel.account.accountNumber)
            Text(viewModel.account.institutionName)
        }
        .padding(.bottom, 8)
    }

}
