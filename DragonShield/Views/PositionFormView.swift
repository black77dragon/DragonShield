import SwiftUI

struct PositionFormView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    var position: PositionReportData?
    var onSave: () -> Void

    @State private var accounts: [DatabaseManager.AccountData] = []
    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var instruments: [(id: Int, name: String, subClassId: Int, currency: String, tickerSymbol: String?, isin: String?)] = []
    @State private var currencies: [(code: String, name: String, symbol: String)] = []

    @State private var sessionId = ""
    @State private var accountId: Int? = nil
    @State private var institutionId: Int? = nil
    @State private var instrumentId: Int? = nil
    @State private var currencyCode = ""
    @State private var quantity = ""
    @State private var purchasePrice = ""
    @State private var currentPrice = ""
    @State private var valueDate = Date()
    @State private var uploadedAt = Date()
    @State private var reportDate = Date()
    @State private var notes = ""

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }()

    private static let dateFormatter = DateFormatter.swissDate

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
            TextField("Session", text: $sessionId)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Import Session")

            Picker("Account", selection: $accountId) {
                ForEach(accounts, id: \.id) {
                    Text($0.accountName).tag(Optional($0.id))
                }
            }
            .accessibilityLabel("Account")

            Picker("Institution", selection: $institutionId) {
                ForEach(institutions) { inst in
                    Text(inst.name).tag(Optional(inst.id))
                }
            }
            .accessibilityLabel("Institution")

            Picker("Instrument", selection: $instrumentId) {
                ForEach(instruments, id: \.id) {
                    Text($0.name).tag(Optional($0.id))
                }
            }
            .accessibilityLabel("Instrument")

            Picker("Currency", selection: $currencyCode) {
                ForEach(currencies, id: \.code) { curr in
                    Text(curr.code).tag(curr.code)
                }
            }
            .accessibilityLabel("Currency")

            TextField("Quantity", text: $quantity)
                .textFieldStyle(.roundedBorder)

            TextField("Purchase Price", text: $purchasePrice)
                .textFieldStyle(.roundedBorder)

            TextField("Current Price", text: $currentPrice)
                .textFieldStyle(.roundedBorder)

            DatePicker("Value Date", selection: $valueDate, displayedComponents: .date)
                .datePickerStyle(.field)

            DatePicker("Uploaded At", selection: $uploadedAt, displayedComponents: .date)
                .datePickerStyle(.field)

            DatePicker("Report Date", selection: $reportDate, displayedComponents: .date)
                .datePickerStyle(.field)

            TextEditor(text: $notes)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3))
                )
                .accessibilityLabel("Notes")
        }
    }

    private var isValid: Bool {
        Int(sessionId) != nil &&
        accountId != nil &&
        institutionId != nil &&
        instrumentId != nil &&
        !currencyCode.isEmpty &&
        Double(quantity) != nil
    }

    private func loadData() {
        accounts = dbManager.fetchAccounts()
        institutions = dbManager.fetchInstitutions()
        instruments = dbManager.fetchAssets()
        currencies = dbManager.fetchActiveCurrencies()
    }

    private func populate() {
        guard let p = position else { return }
        sessionId = p.importSessionId.map { String($0) } ?? ""
        accountId = accounts.first(where: { $0.accountName == p.accountName })?.id
        institutionId = institutions.first(where: { $0.name == p.institutionName })?.id
        instrumentId = instruments.first(where: { $0.name == p.instrumentName })?.id
        currencyCode = p.instrumentCurrency
        quantity = String(p.quantity)
        if let pp = p.purchasePrice { purchasePrice = String(pp) }
        if let cp = p.currentPrice { currentPrice = String(cp) }
        valueDate = p.reportDate
        uploadedAt = p.uploadedAt
        reportDate = p.reportDate
        notes = p.notes ?? ""
    }

    private func save() {
        guard
            let accId = accountId,
            let instId = institutionId,
            let instrId = instrumentId,
            let qty = Double(quantity),
            let sess = Int(sessionId)
        else { return }

        let price = Double(purchasePrice)
        let currPrice = Double(currentPrice)

        if let edit = position {
            _ = dbManager.updatePositionReport(
                id: edit.id,
                importSessionId: sess,
                accountId: accId,
                institutionId: instId,
                instrumentId: instrId,
                quantity: qty,
                purchasePrice: price,
                currentPrice: currPrice,
                notes: notes.isEmpty ? nil : notes,
                reportDate: reportDate
            )
        } else {
            _ = dbManager.addPositionReport(
                importSessionId: sess,
                accountId: accId,
                institutionId: instId,
                instrumentId: instrId,
                quantity: qty,
                purchasePrice: price,
                currentPrice: currPrice,
                notes: notes.isEmpty ? nil : notes,
                reportDate: reportDate
            )
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
