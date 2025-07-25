import SwiftUI

struct AccountDetailWindowView: View {
    @ObservedObject var viewModel: AccountDetailWindowViewModel

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            positionsList
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .onDisappear { viewModel.save() }
    }

    @ViewBuilder
    private var header: some View {
        if let acc = viewModel.account {
            VStack(alignment: .leading, spacing: 4) {
                Text(acc.accountName).font(.title2.bold())
                Text("\(acc.accountNumber) – \(acc.institutionName)")
                    .font(.subheadline)
                if let date = acc.earliestInstrumentLastUpdatedAt {
                    Text("Earliest Updated: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var positionsList: some View {
        List {
            ForEach($viewModel.positions) { $pos in
                HStack {
                    Text(pos.instrument)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Qty", value: $pos.quantity, formatter: Self.numberFormatter)
                        .frame(width: 80)
                    TextField("Price", value: Binding(get: { pos.currentPrice ?? 0 }, set: { pos.currentPrice = $0 }), formatter: Self.numberFormatter)
                        .frame(width: 80)
                    DatePicker("", selection: Binding(get: { pos.instrumentDate ?? Date() }, set: { pos.instrumentDate = $0 }), displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 150)
                }
                .textFieldStyle(.roundedBorder)
            }
        }
    }
}
