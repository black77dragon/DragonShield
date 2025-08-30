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

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private struct InstrumentSheetTarget: Identifiable { let id: Int }
    @State private var editingInstrument: InstrumentSheetTarget?

    init(account: DatabaseManager.AccountData) {
        _viewModel = StateObject(wrappedValue: AccountDetailWindowViewModel(account: account))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            positionsTable
            Spacer()
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.discardChanges()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") {
                    viewModel.saveChanges()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
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
        .sheet(item: $editingInstrument) { target in
            InstrumentEditView(instrumentId: target.id)
                .environmentObject(dbManager)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.account.accountName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.accentColor)
            Text("Account Number: \(viewModel.account.accountNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Institution: \(viewModel.account.institutionName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let d = viewModel.account.earliestInstrumentLastUpdatedAt {
                Text("Earliest Update: \(DateFormatter.swissDate.string(from: d))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var positionsTable: some View {
        ScrollView {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                ForEach($viewModel.positions) { $item in
                    GridRow {
                        Text(item.instrumentName)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quantity")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            TextField("", value: $item.quantity, formatter: Self.numberFormatter)
                                .frame(width: 80)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Latest Price")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if let lp = dbManager.getLatestPrice(instrumentId: item.instrumentId) {
                                let formatted = Self.priceFormatter.string(from: NSNumber(value: lp.price)) ?? String(format: "%.2f", lp.price)
                                Text("\(formatted) \(lp.currency)")
                                    .frame(width: 140, alignment: .trailing)
                                Button("Edit Price") { editingInstrument = InstrumentSheetTarget(id: item.instrumentId) }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                    .frame(width: 140, alignment: .trailing)
                            } else {
                                Text("—")
                                    .foregroundColor(.secondary)
                                    .frame(width: 140, alignment: .trailing)
                                Button("Edit Price") { editingInstrument = InstrumentSheetTarget(id: item.instrumentId) }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                    .frame(width: 140, alignment: .trailing)
                            }
                        }

                        // Instrument price is now centralized; position-level updated date is not editable.
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Price As Of")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if let lp = dbManager.getLatestPrice(instrumentId: item.instrumentId) {
                                Text(lp.asOf)
                                    .frame(width: 120, alignment: .leading)
                            } else {
                                Text("—")
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .leading)
                            }
                        }
        }
    }

    // (Sheet attached in body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
