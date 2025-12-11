import SwiftUI

struct AccountDetailWindowView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AccountDetailWindowViewModel
    @State private var showPriceConfirmation = false

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
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            header
            positionsTable
            Spacer()
        }
        .padding(DSLayout.spaceM)
        .frame(minWidth: 600, minHeight: 400)
        .background(DSColor.background)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.discardChanges()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("OK") {
                    handleSave()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.showSaved {
                DSBadge(text: "Saved", color: DSColor.accentSuccess)
                    .padding(DSLayout.spaceS)
                    .transition(.opacity)
            }
        }
        .onAppear { viewModel.configure(db: dbManager) }
        .onChange(of: viewModel.pendingPriceConfirmation) { _, newValue in
            showPriceConfirmation = newValue != nil
        }
        .sheet(item: $editingInstrument) { target in
            InstrumentEditView(
                instrumentId: target.id,
                isPresented: Binding(
                    get: { editingInstrument != nil },
                    set: { if !$0 { editingInstrument = nil } }
                )
            )
            .environmentObject(dbManager)
        }
        .alert("Latest Price Saved", isPresented: $showPriceConfirmation, presenting: viewModel.pendingPriceConfirmation) { _ in
            Button("OK") {
                showPriceConfirmation = false
                viewModel.clearPendingPriceConfirmation()
                dismiss()
            }
        } message: { confirmation in
            Text(confirmationMessage(for: confirmation))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            Text("Update Prices in Account")
                .dsHeaderLarge()
                .foregroundColor(DSColor.textPrimary)
            Text(viewModel.account.accountName)
                .dsHeaderSmall()
                .foregroundColor(DSColor.accentMain)
            Text("Account Number: \(viewModel.account.accountNumber)")
                .dsBody()
                .foregroundColor(DSColor.textSecondary)
            Text("Institution: \(viewModel.account.institutionName)")
                .dsBody()
                .foregroundColor(DSColor.textSecondary)
            if let d = viewModel.account.earliestInstrumentLastUpdatedAt {
                Text("Earliest Update: \(DateFormatter.swissDate.string(from: d))")
                    .dsCaption()
                    .foregroundColor(DSColor.textTertiary)
            }
        }
    }

    private var positionsTable: some View {
        ScrollView {
            Grid(horizontalSpacing: DSLayout.spaceM, verticalSpacing: DSLayout.spaceM) {
                GridRow {
                    Color.clear
                    Color.clear
                    Color.clear
                    priceAsOfHeader()
                        .frame(width: 120, alignment: .leading)
                }
                Divider()
                ForEach(Array(viewModel.positions.enumerated()), id: \.element.id) { index, item in
                    GridRow {
                        Text(item.instrumentName)
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quantity")
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                            TextField("", value: $viewModel.positions[index].quantity, formatter: Self.numberFormatter)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.ds.mono)
                                .frame(width: 80)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latest Price")
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                            HStack(spacing: DSLayout.spaceXS) {
                                TextField("", text: priceBinding(for: index))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.ds.mono)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100, alignment: .trailing)
                                Text(item.instrumentCurrency)
                                    .dsCaption()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                            currentPriceInfo(for: item)
                            Button("Edit Price") { editingInstrument = InstrumentSheetTarget(id: item.instrumentId) }
                                .buttonStyle(.link)
                                .font(.ds.caption)
                                .frame(width: 140, alignment: .leading)
                        }

                        priceAsOfStyledText(for: item.instrumentUpdatedAt)
                            .frame(width: 120, alignment: .leading)
                    }
                    Divider()
                }
            }
            .padding(DSLayout.spaceS)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension AccountDetailWindowView {
    func handleSave() {
        viewModel.saveChanges()
        if viewModel.pendingPriceConfirmation == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                dismiss()
            }
        } else {
            showPriceConfirmation = true
        }
    }

    func confirmationMessage(for confirmation: AccountDetailWindowViewModel.PriceSaveConfirmation) -> String {
        let dateText = AccountDetailWindowView.priceDateFormatter.string(from: confirmation.asOf)
        let priceText = AccountDetailWindowView.priceFormatter.string(from: NSNumber(value: confirmation.price)) ?? String(format: "%.2f", confirmation.price)
        return "Saved latest price \(priceText) \(confirmation.currency) for \(confirmation.instrumentName) dated \(dateText)."
    }

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

    @ViewBuilder
    func currentPriceInfo(for item: DatabaseManager.EditablePositionData) -> some View {
        if let baseline = viewModel.baselinePosition(for: item.id) {
            let priceText = formattedPriceValue(baseline.currentPrice)
            let priceWithCurrency = baseline.currentPrice == nil ? priceText : "\(priceText) \(baseline.instrumentCurrency)"
            let dateText = formattedPriceAsOf(baseline.instrumentUpdatedAt)

            HStack(spacing: DSLayout.spaceXS) {
                Text("Current:")
                    .dsCaption()
                    .foregroundColor(DSColor.textTertiary)
                Text(priceWithCurrency)
                    .font(.ds.caption.monospacedDigit())
                    .foregroundColor(DSColor.textTertiary)
                Text("as of \(dateText)")
                    .dsCaption()
                    .foregroundColor(DSColor.textTertiary)
            }
            .padding(.top, 2)
        } else {
            Text("Current: —")
                .dsCaption()
                .foregroundColor(DSColor.textTertiary)
                .padding(.top, 2)
        }
    }

    func formattedPriceAsOf(_ date: Date?) -> String {
        guard let date else { return "—" }
        return AccountDetailWindowView.priceDateFormatter.string(from: date)
    }

    func formattedPriceValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return AccountDetailWindowView.priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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
            .font(stale ? .ds.caption.weight(.bold) : .ds.caption)
            .foregroundColor(stale ? DSColor.accentError : DSColor.textSecondary)
    }

    @ViewBuilder
    func priceAsOfHeader() -> some View {
        HStack(spacing: DSLayout.spaceXS) {
            Text("Price As Of")
                .dsCaption()
                .foregroundColor(DSColor.textSecondary)
            HStack(spacing: 2) {
                sortArrowButton(direction: .ascending, systemName: "arrow.up")
                sortArrowButton(direction: .descending, systemName: "arrow.down")
            }
        }
    }

    private func sortArrowButton(direction: AccountDetailWindowViewModel.PriceSortDirection,
                                 systemName: String) -> some View
    {
        let isSelected = viewModel.priceSortDirection == direction
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.setPriceSortDirection(direction)
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? DSColor.accentMain : DSColor.textTertiary)
        }
        .buttonStyle(.plain)
        .help(direction == .ascending ? "Sort by oldest first" : "Sort by newest first")
    }
}
