import SwiftUI

struct TradeFormView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) var presentation
    var onSaved: () -> Void
    var onCancel: () -> Void

    @State private var typeCode: String = "BUY"
    @State private var date: Date = Date()
    @State private var instruments: [DatabaseManager.InstrumentRow] = []
    @State private var accounts: [DatabaseManager.AccountData] = []
    @State private var instrumentId: Int? = nil
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Trade").font(.title2).bold()
            ScrollView {
            Form {
                Section("Basics") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Type", selection: $typeCode) { Text("Buy").tag("BUY"); Text("Sell").tag("SELL") }
                    Picker("Instrument", selection: $instrumentId) {
                        Text("Select Instrument").tag(Optional<Int>(nil))
                        ForEach(instruments, id: \.id) { ins in Text("\(ins.name) [\(ins.currency)]").tag(Optional(ins.id)) }
                    }
                }
                Section("Accounts") {
                    Picker("Custody Account", selection: $custodyAccountId) {
                        Text("Select Account").tag(Optional<Int>(nil))
                        ForEach(accounts, id: \.id) { a in Text("\(a.accountName) [\(a.currencyCode)]").tag(Optional(a.id)) }
                    }
                    if let code = currency {
                        Picker("Cash Account (\(code))", selection: $cashAccountId) {
                            Text("Select Account").tag(Optional<Int>(nil))
                            ForEach(cashAccounts, id: \.id) { a in Text(a.accountName).tag(Optional(a.id)) }
                        }
                    }
                }
                Section("Amounts") {
                    Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow { Text("Quantity").frame(width: 120, alignment: .trailing); TextField("", text: $quantity).multilineTextAlignment(.trailing).frame(width: 160) }
                        GridRow { Text("Price").frame(width: 120, alignment: .trailing); TextField("", text: $price).multilineTextAlignment(.trailing).frame(width: 160) }
                        GridRow { Text("Fees (CHF)").frame(width: 120, alignment: .trailing); TextField("", text: $feesChf).multilineTextAlignment(.trailing).frame(width: 160) }
                        GridRow { Text("Commission (CHF)").frame(width: 120, alignment: .trailing); TextField("", text: $commissionChf).multilineTextAlignment(.trailing).frame(width: 160) }
                    }
                }
                Section("Preview") {
                    if let pv = preview, let code = (cashCurrency ?? currency) {
                        HStack { Text("Cash Leg").frame(width: 120, alignment: .trailing); Text(String(format: "%.4f %@", pv.cashDelta, code)).foregroundColor(pv.cashDelta >= 0 ? .green : .red) }
                        HStack { Text("Instrument Leg").frame(width: 120, alignment: .trailing); Text(String(format: "%.4f", pv.instrDelta)) }
                    } else {
                        Text("Enter instrument, qty and price to preview.").foregroundColor(.secondary)
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
        .onAppear { load() }
    }

    private func load() {
        instruments = dbManager.fetchAssets(includeDeleted: false, includeInactive: true)
        accounts = dbManager.fetchAccounts()
    }

    private func save() {
        guard let instr = instrumentId, let cust = custodyAccountId, let cash = cashAccountId, let qty = Double(quantity), let pr = Double(price) else { return }
        let input = DatabaseManager.NewTradeInput(typeCode: typeCode, date: date, instrumentId: instr, quantity: qty, priceTxn: pr, feesChf: Double(feesChf) ?? 0, commissionChf: Double(commissionChf) ?? 0, custodyAccountId: cust, cashAccountId: cash, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        if let _ = dbManager.createTrade(input) {
            onSaved(); presentation.wrappedValue.dismiss()
        } else {
            errorMessage = "Failed to save trade. Check currency of cash account, FX for fees, and inputs."
        }
    }
}

struct TradeFormView_Previews: PreviewProvider {
    static var previews: some View {
        TradeFormView(onSaved: {}, onCancel: {}).environmentObject(DatabaseManager())
    }
}
