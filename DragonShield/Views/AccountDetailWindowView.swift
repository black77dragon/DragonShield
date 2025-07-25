import SwiftUI

struct AccountDetailWindowView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel: AccountDetailViewModel

    init(accountId: Int) {
        _viewModel = StateObject(wrappedValue: AccountDetailViewModel(accountId: accountId))
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let acc = viewModel.account {
                header(for: acc)
                positionsTable
            } else {
                ProgressView()
            }
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 400)
        .onAppear { viewModel.load(db: dbManager) }
        .navigationTitle("Account Detail – \(viewModel.account?.accountName ?? "")")
    }

    private func header(for acc: DatabaseManager.AccountData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(acc.accountName).font(.title2)
            Text(acc.accountNumber)
            Text(acc.institutionName)
            if let d = acc.earliestInstrumentLastUpdatedAt {
                Text("Earliest Update: " + DateFormatter.swissDate.string(from: d))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var positionsTable: some View {
        Table($viewModel.positions) {
            TableColumn("Instrument") { $row in
                Text(row.instrumentName)
            }
            TableColumn("Qty") { $row in
                TextField("", value: $row.quantity, formatter: Self.numberFormatter)
                    .onSubmit { viewModel.update(position: row) }
            }
            TableColumn("Price") { $row in
                TextField("", value: Binding(get: { row.currentPrice ?? 0 }, set: { row.currentPrice = $0 }), formatter: Self.numberFormatter)
                    .onSubmit { viewModel.update(position: row) }
            }
            TableColumn("Updated") { $row in
                DatePicker("", selection: Binding(get: { row.instrumentUpdatedAt ?? Date() }, set: { row.instrumentUpdatedAt = $0 }), displayedComponents: .date)
                    .datePickerStyle(.field)
                    .onChange(of: row.instrumentUpdatedAt) { _ in viewModel.update(position: row) }
            }
        }
    }
}
