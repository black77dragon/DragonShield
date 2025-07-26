import SwiftUI

struct AccountDetailWindowView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AccountDetailWindowViewModel

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        f.minimumFractionDigits = 0
        return f
    }()

    init(account: DatabaseManager.AccountData) {
        _viewModel = StateObject(wrappedValue: AccountDetailWindowViewModel(account: account))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            positionsTable
            Spacer()
            actionButtons
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 400)
        .overlay(alignment: .topTrailing) {
            if viewModel.showSaved {
                Text("Saved")
                    .padding(6)
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .transition(.opacity)
            }
        }
        .onAppear { viewModel.configure(db: dbManager) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Account Detail – \(viewModel.account.accountName)")
                .font(.title2)
            Text("Account Number: \(viewModel.account.accountNumber)")
            Text("Institution: \(viewModel.account.institutionName)")
            if let d = viewModel.account.earliestInstrumentLastUpdatedAt {
                Text("Earliest Update: \(DateFormatter.swissDate.string(from: d))")
            }
        }
    }

    private var positionsTable: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach($viewModel.positions) { $item in
                    HStack {
                        Text(item.instrumentName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Qty", value: $item.quantity, formatter: Self.numberFormatter)
                            .frame(width: 80)
                        TextField("Price", value: Binding(
                            get: { item.currentPrice ?? 0 },
                            set: { item.currentPrice = $0 }
                        ), formatter: Self.numberFormatter)
                            .frame(width: 80)
                        DatePicker("", selection: Binding(
                            get: { item.instrumentUpdatedAt ?? Date() },
                            set: { item.instrumentUpdatedAt = $0 }
                        ), displayedComponents: .date)
                            .labelsHidden()
                    }
                    .padding(4)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                viewModel.discardChanges()
                dismiss()
            }
            Button("OK") {
                viewModel.saveChanges()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}
