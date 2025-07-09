import SwiftUI

struct PositionFormView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    var position: PositionReportData?
    var onSave: () -> Void

    @State private var accounts: [DatabaseManager.AccountData] = []
    @State private var instruments: [(id: Int, name: String, subClassId: Int, currency: String, tickerSymbol: String?, isin: String?)] = []

    @State private var accountId: Int? = nil
    @State private var instrumentId: Int? = nil
    @State private var quantity = ""
    @State private var purchasePrice = ""
    @State private var reportDate = Date()
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(position == nil ? "Add Position" : "Edit Position")
                .font(.title2).bold()
            formFields
            HStack {
                Spacer()
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Save") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear { loadData(); populate() }
    }

    private var formFields: some View {
        Group {
            Picker("Account", selection: $accountId) {
                ForEach(accounts, id: \.id) { Text($0.accountName).tag(Optional($0.id)) }
            }
            Picker("Instrument", selection: $instrumentId) {
                ForEach(instruments, id: \.id) { Text($0.name).tag(Optional($0.id)) }
            }
            TextField("Quantity", text: $quantity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField("Purchase Price", text: $purchasePrice)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            DatePicker("Value Date", selection: $reportDate, displayedComponents: .date)
            TextEditor(text: $notes)
                .frame(height: 60)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
        }
    }

    private var isValid: Bool {
        accountId != nil && instrumentId != nil && Double(quantity) != nil
    }

    private func loadData() {
        accounts = dbManager.fetchAccounts()
        instruments = dbManager.fetchAssets()
    }

    private func populate() {
        guard let p = position else { return }
        accountId = accounts.first(where: { $0.accountName == p.accountName })?.id
        instrumentId = instruments.first(where: { $0.name == p.instrumentName })?.id
        quantity = String(p.quantity)
        if let pp = p.purchasePrice { purchasePrice = String(pp) }
        reportDate = p.reportDate
        notes = p.notes ?? ""
    }

    private func save() {
        guard let accId = accountId, let instId = instrumentId, let qty = Double(quantity) else { return }
        let price = Double(purchasePrice)
        let institutionId = accounts.first(where: { $0.id == accId })?.institutionId ?? 0
        if let edit = position {
            _ = dbManager.updatePositionReport(id: edit.id, accountId: accId, institutionId: institutionId, instrumentId: instId, quantity: qty, purchasePrice: price, currentPrice: nil, notes: notes.isEmpty ? nil : notes, reportDate: reportDate)
        } else {
            _ = dbManager.addPositionReport(accountId: accId, institutionId: institutionId, instrumentId: instId, quantity: qty, purchasePrice: price, currentPrice: nil, notes: notes.isEmpty ? nil : notes, reportDate: reportDate)
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
