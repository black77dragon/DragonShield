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
    @State private var instrumentUpdatedAt = Date()
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
        .frame(width: 480)
        .onAppear { loadData(); populate() }
    }

    private var formFields: some View {
        Form {
            Section {
                TextField("Session", text: $sessionId)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Import Session")

            Picker("Account", selection: $accountId) {
                Text("Select Account").tag(Optional<Int>(nil))
                ForEach(accounts, id: \.id) {
                    Text($0.accountName).tag(Optional($0.id))
                }
            }
            .accessibilityLabel("Account")

            Picker("Institution", selection: $institutionId) {
                Text("Select Institution").tag(Optional<Int>(nil))
                ForEach(institutions) { inst in
                    Text(inst.name).tag(Optional(inst.id))
                }
            }
            .accessibilityLabel("Institution")

            Picker("Instrument", selection: $instrumentId) {
                Text("Select Instrument").tag(Optional<Int>(nil))
                ForEach(instruments, id: \.id) {
                    Text($0.name).tag(Optional($0.id))
                }
            }
            .accessibilityLabel("Instrument")

            Picker("Currency", selection: $currencyCode) {
                Text("Select Currency").tag("")
                ForEach(currencies, id: \.code) { curr in
                    Text(curr.code).tag(curr.code)
                }
            }
            .accessibilityLabel("Currency")
            }

            Section("Prices") {
                numericField(label: "Quantity", text: $quantity)
                numericField(label: "Purchase Price", text: $purchasePrice)
                numericField(label: "Current Price", text: $currentPrice)
            }

            Section("Dates") {
                datesGrid
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3))
                    )
                    .accessibilityLabel("Notes")
            }
        }
    }

    private func numericField(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .accessibilityLabel(label)
        }
    }

    private var datesGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                dateField(label: "Instrument Updated", date: $instrumentUpdatedAt)
                dateField(label: "Value Date", date: $valueDate)
            }
            GridRow {
                dateField(label: "Uploaded At", date: $uploadedAt)
                dateField(label: "Report Date", date: $reportDate)
            }
        }
    }

    private func dateField(label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var isValid: Bool {
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
        if let iu = p.instrumentUpdatedAt { instrumentUpdatedAt = iu }
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
            let qty = Double(quantity)
        else { return }

        let sess = Int(sessionId)

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
                instrumentUpdatedAt: instrumentUpdatedAt,
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
                instrumentUpdatedAt: instrumentUpdatedAt,
                notes: notes.isEmpty ? nil : notes,
                reportDate: reportDate
            )
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
