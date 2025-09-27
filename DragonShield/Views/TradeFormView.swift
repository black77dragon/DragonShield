import SwiftUI

struct TradeFormView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) var presentation
    var onSaved: () -> Void
    var onCancel: () -> Void
    var editTradeId: Int? = nil

    @State private var typeCode: String = "BUY"
    @State private var date: Date = Date()
    @State private var instruments: [DatabaseManager.InstrumentRow] = []
    @State private var accounts: [DatabaseManager.AccountData] = []
    @State private var accountTypes: [DatabaseManager.AccountTypeData] = []
    @State private var instrumentId: Int? = nil
    @State private var instrumentSearch: String = ""
    @State private var showInstrumentPicker = false
    @State private var custodyAccountId: Int? = nil
    @State private var cashAccountId: Int? = nil
    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var feesChf: String = "0"
    @State private var commissionChf: String = "0"
    @State private var notes: String = ""
    @State private var errorMessage: String? = nil

    private var currency: String? { instrumentId.flatMap { id in instruments.first(where: { $0.id == id })?.currency } }
    private var cashCurrency: String? { cashAccountId.flatMap { id in accounts.first(where: { $0.id == id })?.currencyCode } }

    private var custodyTypeIds: Set<Int> {
        Set(accountTypes.filter { $0.code.uppercased() == "CUSTODY" }.map { $0.id })
    }

    private var custodyAccounts: [DatabaseManager.AccountData] {
        var base = accounts.filter { custodyTypeIds.contains($0.accountTypeId) }
            .sorted { $0.accountName.localizedCaseInsensitiveCompare($1.accountName) == .orderedAscending }
        if let sel = custodyAccountId, !base.contains(where: { $0.id == sel }), let acc = accounts.first(where: { $0.id == sel }) {
            base.insert(acc, at: 0)
        }
        return base
    }

    private var cashAccounts: [DatabaseManager.AccountData] {
        guard let code = currency?.uppercased() else { return [] }
        return accounts.filter { $0.currencyCode.uppercased() == code }
    }

    private var canSave: Bool {
        guard instrumentId != nil, custodyAccountId != nil, cashAccountId != nil else { return false }
        guard Double(quantity) ?? 0 > 0, Double(price) ?? 0 > 0 else { return false }
        return true
    }

    private var preview: (cashDelta: Double, instrDelta: Double)? {
        guard let qty = Double(quantity), let p = Double(price) else { return nil }
        // Prefer cash account currency for fees conversion; fallback to instrument currency
        let code = (cashCurrency ?? currency)?.uppercased()
        guard let c = code else { return nil }
        let fxRate = dbManager.fetchExchangeRates(currencyCode: c, upTo: date).first?.rateToChf
        let chfToTxn = (fxRate != nil && fxRate! > 0) ? (1.0 / fxRate!) : 1.0
        let fees = (Double(feesChf) ?? 0) * chfToTxn
        let comm = (Double(commissionChf) ?? 0) * chfToTxn
        let val = qty * p
        let cash = typeCode == "BUY" ? -(val + fees + comm) : +(val - fees - comm)
        let instr = typeCode == "BUY" ? qty : -qty
        return (round(cash * 10000)/10000, round(instr * 10000)/10000)
    }

    // Current holdings based on selected accounts/instrument and date
    private var currentCash: Double? {
        guard let acc = cashAccountId else { return nil }
        return dbManager.currentCashBalance(accountId: acc, upTo: date)
    }
    private var currentHolding: Double? {
        guard let acc = custodyAccountId, let iid = instrumentId else { return nil }
        return dbManager.currentInstrumentHolding(accountId: acc, instrumentId: iid, upTo: date)
    }
    private var updatedCash: Double? {
        guard let cur = currentCash, let pv = preview else { return nil }
        return (cur + pv.cashDelta).rounded(toPlaces: 4)
    }
    private var updatedHolding: Double? {
        guard let cur = currentHolding, let pv = preview else { return nil }
        return (cur + pv.instrDelta).rounded(toPlaces: 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editTradeId == nil ? "New Trade" : "Edit Trade").font(.title2).bold()
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill").foregroundColor(.blue)
                Text("Transactions are NOT updating the custody and cash accounts. They are maintained manually. Currently the purpose of the transaction journal is to calculate the P&L of transactions only.")
                    .font(.callout)
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            .cornerRadius(8)
            ScrollView {
            Form {
                let labelWidth: CGFloat = 120
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Date")
                            .frame(width: labelWidth, alignment: .trailing)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Type")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("", selection: $typeCode) { Text("Buy").tag("BUY"); Text("Sell").tag("SELL") }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Instrument")
                            .frame(width: labelWidth, alignment: .trailing)
                        Button("Choose Instrument…") {
                            instrumentSearch = instrumentDisplayForCurrent() ?? ""
                            showInstrumentPicker = true
                        }
                        Text(selectedInstrumentDisplay)
                            .foregroundColor(selectedInstrumentDisplay == "No instrument selected" ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Custody Account")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("", selection: $custodyAccountId) {
                            Text("Select Account").tag(Optional<Int>(nil))
                            ForEach(custodyAccounts, id: \.id) { a in Text("\(a.accountName) [\(a.currencyCode)]").tag(Optional(a.id)) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 280, alignment: .leading)
                        Spacer()
                        if let curH = currentHolding {
                            Text(String(format: "Holding: %.4f", curH))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let code = currency {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Cash Account (\(code))")
                                .frame(width: labelWidth, alignment: .trailing)
                            Picker("", selection: $cashAccountId) {
                                Text("Select Account").tag(Optional<Int>(nil))
                                ForEach(cashAccounts, id: \.id) { a in Text(a.accountName).tag(Optional(a.id)) }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 280, alignment: .leading)
                            Spacer()
                            if let curC = currentCash {
                                Text(String(format: "Cash: %.4f %@", curC, (cashCurrency ?? code)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow {
                            Text("Quantity").frame(width: labelWidth, alignment: .trailing)
                            TextField("", text: $quantity)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 160)
                        }
                        GridRow {
                            Text("Price").frame(width: labelWidth, alignment: .trailing)
                            TextField("", text: $price)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 160)
                        }
                        GridRow {
                            Text("Fees (CHF)").frame(width: labelWidth, alignment: .trailing)
                            TextField("", text: $feesChf)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 160)
                        }
                        GridRow {
                            Text("Commission (CHF)").frame(width: labelWidth, alignment: .trailing)
                            TextField("", text: $commissionChf)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 160)
                        }
                    }
                }
                Section("Preview") {
                    if let pv = preview, let code = (cashCurrency ?? currency) {
                        HStack { Text("Cash Leg").frame(width: 120, alignment: .trailing); Text(String(format: "%.4f %@", pv.cashDelta, code)).foregroundColor(pv.cashDelta >= 0 ? .green : .red) }
                        HStack { Text("Instrument Leg").frame(width: 120, alignment: .trailing); Text(String(format: "%.4f", pv.instrDelta)) }
                        if let code = (cashCurrency ?? currency) {
                            // FX used for CHF->cash conversion
                            if let rate = dbManager.fetchExchangeRates(currencyCode: code, upTo: date).first {
                                let chfToTxn = rate.rateToChf > 0 ? (1.0 / rate.rateToChf) : 1.0
                                HStack {
                                    Text("FX used").frame(width: 120, alignment: .trailing)
                                    Text(String(format: "1 CHF = %.6f %@ (as of %@)", chfToTxn, code, DateFormatter.iso8601DateOnly.string(from: rate.rateDate)))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("Enter instrument, qty and price to preview.").foregroundColor(.secondary)
                    }
                }
                Section("Holdings (as of date)") {
                    if let curC = currentCash, let upC = updatedCash, let code = (cashCurrency ?? currency) {
                        HStack { Text("Cash").frame(width: 120, alignment: .trailing); Text(String(format: "%.4f %@ → %.4f %@", curC, code, upC, code)) }
                    } else {
                        HStack { Text("Cash").frame(width: 120, alignment: .trailing); Text("Select cash account and fill preview inputs").foregroundColor(.secondary) }
                    }
                    if let curH = currentHolding, let upH = updatedHolding {
                        HStack { Text("Holding").frame(width: 120, alignment: .trailing); Text(String(format: "%.4f → %.4f", curH, upH)) }
                    } else {
                        HStack { Text("Holding").frame(width: 120, alignment: .trailing); Text("Select custody account and instrument").foregroundColor(.secondary) }
                    }
                }
                Section("Notes") {
                    TextField("", text: $notes)
                }
            }
            }
            if let e = errorMessage { Text(e).foregroundColor(.red) }
            HStack {
                Spacer()
                Button("Cancel") { onCancel(); presentation.wrappedValue.dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Save") { save() }.buttonStyle(PrimaryButtonStyle()).disabled(!canSave)
            }
        }
        .padding(24)
        .frame(minWidth: 820, minHeight: 760)
        .sheet(isPresented: $showInstrumentPicker) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Instrument")
                    .font(.headline)
                FloatingSearchPicker(
                    title: "Choose Instrument",
                    placeholder: "Search instruments",
                    items: instrumentPickerItems,
                    selectedId: instrumentPickerBinding,
                    showsClearButton: true,
                    emptyStateText: "No instruments",
                    query: $instrumentSearch,
                    onSelection: { _ in
                        showInstrumentPicker = false
                    },
                    onClear: {
                        instrumentPickerBinding.wrappedValue = nil
                    },
                    onSubmit: { _ in
                        if instrumentId != nil { showInstrumentPicker = false }
                    },
                    selectsFirstOnSubmit: false
                )
                .frame(minWidth: 360)
                HStack {
                    Spacer()
                    Button("Close") { showInstrumentPicker = false }
                }
            }
            .padding(16)
            .frame(width: 520)
            .onAppear {
                instrumentSearch = instrumentDisplayForCurrent() ?? ""
            }
        }
        .onAppear { load(); populateIfEditing() }
    }

    private func load() {
        instruments = dbManager.fetchAssets(includeDeleted: false, includeInactive: true)
        accounts = dbManager.fetchAccounts()
        accountTypes = dbManager.fetchAccountTypes(activeOnly: true)
    }

    private func populateIfEditing() {
        guard let tid = editTradeId, let d = dbManager.fetchTradeForEdit(tradeId: tid) else { return }
        typeCode = d.typeCode.uppercased()
        date = d.date
        instrumentId = d.instrumentId
        custodyAccountId = d.custodyAccountId
        cashAccountId = d.cashAccountId
        quantity = String(format: "%.4f", d.quantity)
        price = String(format: "%.4f", d.priceTxn)
        feesChf = String(format: "%.4f", d.feesChf)
        commissionChf = String(format: "%.4f", d.commissionChf)
        notes = d.notes ?? ""
    }

    private var instrumentPickerItems: [FloatingSearchPicker.Item] {
        instruments.map { ins in
            FloatingSearchPicker.Item(
                id: AnyHashable(ins.id),
                title: ins.name,
                subtitle: instrumentSubtitle(ins),
                searchText: instrumentSearchText(ins)
            )
        }
    }

    private var instrumentPickerBinding: Binding<AnyHashable?> {
        Binding<AnyHashable?>(
            get: { instrumentId.map { AnyHashable($0) } },
            set: { newValue in
                if let value = newValue as? Int {
                    instrumentId = value
                    instrumentSearch = instrumentDisplay(for: value) ?? ""
                } else {
                    instrumentId = nil
                    instrumentSearch = ""
                }
            }
        )
    }

    private var selectedInstrumentDisplay: String {
        instrumentDisplayForCurrent() ?? "No instrument selected"
    }

    private func instrumentDisplayForCurrent() -> String? {
        guard let id = instrumentId else { return nil }
        return instrumentDisplay(for: id)
    }

    private func instrumentDisplay(for id: Int) -> String? {
        guard let ins = instruments.first(where: { $0.id == id }) else { return nil }
        if let subtitle = instrumentSubtitle(ins) {
            return "\(ins.name) • \(subtitle)"
        }
        return ins.name
    }

    private func instrumentSubtitle(_ ins: DatabaseManager.InstrumentRow) -> String? {
        var parts: [String] = []
        if let ticker = ins.tickerSymbol, !ticker.isEmpty {
            parts.append(ticker.uppercased())
        }
        if !ins.currency.isEmpty {
            parts.append(ins.currency.uppercased())
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func instrumentSearchText(_ ins: DatabaseManager.InstrumentRow) -> String {
        var parts: [String] = [ins.name]
        if let ticker = ins.tickerSymbol?.trimmingCharacters(in: .whitespacesAndNewlines), !ticker.isEmpty {
            parts.append(ticker.uppercased())
        }
        if let isin = ins.isin?.trimmingCharacters(in: .whitespacesAndNewlines), !isin.isEmpty {
            parts.append(isin.uppercased())
        }
        if let valor = ins.valorNr?.trimmingCharacters(in: .whitespacesAndNewlines), !valor.isEmpty {
            parts.append(valor.uppercased())
        }
        parts.append(ins.currency.uppercased())
        return parts.joined(separator: " ")
    }

    private func save() {
        guard let instr = instrumentId, let cust = custodyAccountId, let cash = cashAccountId, let qty = Double(quantity), let pr = Double(price) else { return }
        let input = DatabaseManager.NewTradeInput(typeCode: typeCode, date: date, instrumentId: instr, quantity: qty, priceTxn: pr, feesChf: Double(feesChf) ?? 0, commissionChf: Double(commissionChf) ?? 0, custodyAccountId: cust, cashAccountId: cash, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        if let tid = editTradeId {
            if dbManager.updateTrade(tradeId: tid, input) {
                onSaved(); presentation.wrappedValue.dismiss()
            } else {
                errorMessage = dbManager.lastTradeErrorMessage ?? "Failed to update trade."
            }
        } else {
            if let _ = dbManager.createTrade(input) {
                onSaved(); presentation.wrappedValue.dismiss()
            } else {
                errorMessage = dbManager.lastTradeErrorMessage ?? "Failed to save trade. Check currency of cash account, FX for fees, and inputs."
            }
        }
    }
}

struct TradeFormView_Previews: PreviewProvider {
    static var previews: some View {
        TradeFormView(onSaved: {}, onCancel: {}).environmentObject(DatabaseManager())
    }
}
