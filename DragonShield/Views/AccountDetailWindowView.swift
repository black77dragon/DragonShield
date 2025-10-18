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

    private static let priceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yy"
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Update Account Information")
                .font(.system(size: 22, weight: .bold))
            Text(viewModel.account.accountName)
                .font(.headline)
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
                ForEach(Array(viewModel.positions.enumerated()), id: \.element.id) { index, item in
                    GridRow {
                        Text(item.instrumentName)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quantity")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            TextField("", value: $viewModel.positions[index].quantity, formatter: Self.numberFormatter)
                                .frame(width: 80)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Latest Price")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                TextField("", text: priceBinding(for: index))
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100, alignment: .trailing)
                                Text(item.instrumentCurrency)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Button("Edit Price") { editingInstrument = InstrumentSheetTarget(id: item.instrumentId) }
                                .buttonStyle(.link)
                                .font(.caption)
                                .frame(width: 140, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Price As Of")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            priceAsOfStyledText(for: item.instrumentUpdatedAt)
                                .frame(width: 120, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension AccountDetailWindowView {
    func priceBinding(for index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard viewModel.positions.indices.contains(index) else { return "" }
                if let value = viewModel.positions[index].currentPrice {
                    return AccountDetailWindowView.priceFormatter.string(from: NSNumber(value: value)) ?? String(value)
                }
                return ""
            },
            set: { newValue in
                guard viewModel.positions.indices.contains(index) else { return }
                let sanitized = newValue.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: ".")
                let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    viewModel.positions[index].currentPrice = nil
                    viewModel.positions[index].instrumentUpdatedAt = nil
                } else if let value = Double(trimmed) {
                    viewModel.positions[index].currentPrice = value
                    viewModel.positions[index].instrumentUpdatedAt = Date()
                }
            }
        )
    }

    func formattedPriceAsOf(_ date: Date?) -> String {
        guard let date else { return "—" }
        return AccountDetailWindowView.priceDateFormatter.string(from: date)
    }

    func priceIsStale(_ date: Date?) -> Bool {
        guard let date else { return false }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days > 30
    }

    @ViewBuilder
    func priceAsOfStyledText(for date: Date?) -> some View {
        let formatted = formattedPriceAsOf(date)
        let stale = priceIsStale(date)
        Text(formatted)
            .font(.caption2.weight(stale ? .bold : .regular))
            .foregroundColor(stale ? .red : .secondary)
    }
}
