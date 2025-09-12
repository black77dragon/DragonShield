import SwiftUI

struct TransactionFormView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) private var presentation

    var onSaved: () -> Void
    var onCancel: () -> Void
    var editTransactionId: Int? = nil

    @State private var date: Date = Date()
    @State private var type: String = "BUY" // BUY or SELL for Phase 1
    @State private var instruments: [DatabaseManager.InstrumentRow] = []
    @State private var accounts: [DatabaseManager.AccountData] = []

    @State private var selectedInstrumentId: Int? = nil
    @State private var selectedSecuritiesAccountId: Int? = nil
    @State private var selectedCashAccountId: Int? = nil

    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var fee: String = ""
    @State private var tax: String = ""
    @State private var descriptionText: String = ""

    @State private var errorMessage: String? = nil

    private var currency: String? {
        if let iid = selectedInstrumentId, let row = instruments.first(where: { $0.id == iid }) { return row.currency }
        return nil
    }

    private var filteredAccounts: [DatabaseManager.AccountData] {
        guard let code = currency?.uppercased() else { return [] }
        return accounts.filter { $0.currencyCode.uppercased() == code }
    }

    private var canSave: Bool {
        guard let iid = selectedInstrumentId, let sa = selectedSecuritiesAccountId, let ca = selectedCashAccountId else { return false }
        guard Double(quantity) != nil, Double(price) != nil else { return false }
        // Currency match via filteredAccounts already
        return iid > 0 && sa > 0 && ca > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Transaction").font(.title2).bold()
            Form {
                Section("Basics") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Type", selection: $type) {
                        Text("BUY").tag("BUY")
                        Text("SELL").tag("SELL")
                    }
                }
                Section("Instrument & Accounts") {
                    Picker("Instrument", selection: $selectedInstrumentId) {
                        Text("Select Instrument").tag(Optional<Int>(nil))
                        ForEach(instruments, id: \.id) { ins in
                            Text("\(ins.name) [\(ins.currency)]").tag(Optional(ins.id))
                        }
                    }
                    if let code = currency {
                        Picker("Securities Account (\(code))", selection: $selectedSecuritiesAccountId) {
                            Text("Select Account").tag(Optional<Int>(nil))
                            ForEach(filteredAccounts, id: \.id) { a in
                                Text(a.accountName).tag(Optional(a.id))
                            }
                        }
                        Picker("Cash Account (\(code))", selection: $selectedCashAccountId) {
                            Text("Select Account").tag(Optional<Int>(nil))
                            ForEach(filteredAccounts, id: \.id) { a in
                                Text(a.accountName).tag(Optional(a.id))
                            }
                        }
                    }
                }
                Section("Amounts") {
                    HStack {
                        Text("Quantity"); Spacer(); TextField("", text: $quantity).multilineTextAlignment(.trailing).frame(width: 140)
                    }
                    HStack {
                        Text("Price"); Spacer(); TextField("", text: $price).multilineTextAlignment(.trailing).frame(width: 140)
                    }
                    HStack {
                        Text("Fee"); Spacer(); TextField("", text: $fee).multilineTextAlignment(.trailing).frame(width: 140)
                    }
                    HStack {
                        Text("Tax"); Spacer(); TextField("", text: $tax).multilineTextAlignment(.trailing).frame(width: 140)
                    }
                    TextField("Description (optional)", text: $descriptionText)
                }
            }
            if let msg = errorMessage {
                Text(msg).foregroundColor(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { onCancel(); presentation.wrappedValue.dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 520)
        .onAppear { loadData(); populateIfEditing() }
    }

    private func loadData() {
        instruments = dbManager.fetchAssets()
        accounts = dbManager.fetchAccounts()
    }

    private func populateIfEditing() {
        guard let tid = editTransactionId, let details = dbManager.fetchPairedTradeDetails(transactionId: tid) else { return }
        // Populate fields
        type = details.typeCode
        selectedInstrumentId = details.instrumentId
        // After instrument set, currency filter will constrain accounts; delay selection to next runloop
        DispatchQueue.main.async {
            selectedSecuritiesAccountId = details.securitiesAccountId
            selectedCashAccountId = details.cashAccountId
        }
        date = details.date
        quantity = String(details.quantity)
        price = String(details.price)
        if let f = details.fee { fee = String(f) }
        if let t = details.tax { tax = String(t) }
        descriptionText = details.description ?? ""
    }

    private func save() {
        guard let iid = selectedInstrumentId, let sa = selectedSecuritiesAccountId, let ca = selectedCashAccountId else { return }
        guard let qty = Double(quantity), let pr = Double(price) else { return }
        let f = Double(fee) ?? 0
        let t = Double(tax) ?? 0
        var ok = false
        if let tid = editTransactionId, let existing = dbManager.fetchPairedTradeDetails(transactionId: tid) {
            // Replace pair: delete by order reference then create anew
            _ = dbManager.deleteTransactions(orderReference: existing.orderReference)
            ok = dbManager.createPairedTrade(
                typeCode: type,
                instrumentId: iid,
                securitiesAccountId: sa,
                cashAccountId: ca,
                date: date,
                quantity: qty,
                price: pr,
                fee: f == 0 ? nil : f,
                tax: t == 0 ? nil : t,
                description: descriptionText.isEmpty ? nil : descriptionText
            )
        } else {
            ok = dbManager.createPairedTrade(
                typeCode: type,
                instrumentId: iid,
                securitiesAccountId: sa,
                cashAccountId: ca,
                date: date,
                quantity: qty,
                price: pr,
                fee: f == 0 ? nil : f,
                tax: t == 0 ? nil : t,
                description: descriptionText.isEmpty ? nil : descriptionText
            )
        }
        if ok {
            onSaved()
            presentation.wrappedValue.dismiss()
        } else {
            errorMessage = "Failed to save. Check currencies, FX, or holdings (no negative sells)."
        }
    }
}
