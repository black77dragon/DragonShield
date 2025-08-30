import SwiftUI

typealias InstrumentInfo = (
    id: Int,
    name: String,
    subClassId: Int,
    currency: String,
    valorNr: String?,
    tickerSymbol: String?,
    isin: String?
)

typealias AccountInfo = (
    id: Int,
    name: String,
    institutionId: Int,
    institutionName: String
)

func instrumentCurrency(for instrumentId: Int?, instruments: [InstrumentInfo]) -> String? {
    guard let id = instrumentId else { return nil }
    return instruments.first { $0.id == id }?.currency
}

func accountInstitution(for accountId: Int?, accounts: [AccountInfo]) -> (id: Int, name: String)? {
    guard let id = accountId else { return nil }
    guard let account = accounts.first(where: { $0.id == id }) else { return nil }
    return (account.institutionId, account.institutionName)
}

struct PositionFormView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    var position: PositionReportData?
    var onSave: () -> Void

    @State private var accounts: [AccountInfo] = []
    @State private var instruments: [InstrumentInfo] = []

    @State private var sessionId = ""
    @State private var accountId: Int? = nil
    @State private var institutionId: Int? = nil
    @State private var institutionName = ""
    @State private var instrumentId: Int? = nil
    @State private var instrumentQuery: String = ""
    @State private var currencyCode = ""
    @State private var latestInstrumentPrice: Double? = nil
    @State private var quantity = ""
    @State private var purchasePrice = ""
    // currentPrice maintained centrally via InstrumentPrice; stop editing here
    @State private var currentPrice = ""
    @State private var instrumentUpdatedAt = Date()
    @State private var uploadedAt = Date()
    @State private var reportDate = Date()
    @State private var notes = ""

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }()

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
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
        .frame(minWidth: 520, minHeight: 620)
        .onAppear { loadData(); populate() }
        .onChange(of: accountId) { _, id in
            let institution = accountInstitution(for: id, accounts: accounts)
            institutionId = institution?.id
            institutionName = institution?.name ?? ""
        }
        .onChange(of: instrumentId) { _, id in
            currencyCode = instrumentCurrency(for: id, instruments: instruments) ?? ""
            if let iid = id, let lp = dbManager.getLatestPrice(instrumentId: iid) {
                latestInstrumentPrice = lp.price
            } else {
                latestInstrumentPrice = nil
            }
        }
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
                    Text($0.name).tag(Optional($0.id))
                }
            }
            .accessibilityLabel("Account")

            HStack {
                Text("Institution")
                    .font(.headline)
                Spacer()
                Text(institutionName)
                    .frame(width: 200, alignment: .trailing)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Institution")

            VStack(alignment: .leading, spacing: 6) {
                Text("Instrument").font(.headline)
                MacComboBox(
                    items: instrumentDisplayItems(),
                    text: $instrumentQuery,
                    onSelectIndex: { originalIndex in
                        let ins = instruments[originalIndex]
                        instrumentId = ins.id
                        currencyCode = ins.currency
                    }
                )
                .frame(minWidth: 360)
                .accessibilityLabel("Instrument")
            }

            HStack {
                Text("Currency")
                    .font(.headline)
                Spacer()
                Text(currencyCode)
                    .frame(width: 120, alignment: .trailing)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Currency")
            }

            Section("Prices") {
                numericField(label: "Quantity", text: $quantity)
                numericField(label: "Purchase Price", text: $purchasePrice)
                HStack {
                    Text("Latest Price")
                        .font(.headline)
                    Spacer()
                    if let p = latestInstrumentPrice, !currencyCode.isEmpty {
                        let formatted = Self.priceFormatter.string(from: NSNumber(value: p)) ?? String(format: "%.2f", p)
                        Text("\(formatted) \(currencyCode)")
                            .foregroundColor(.secondary)
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }
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
        .formStyle(.grouped)
    }

    private func numericField(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.headline)
            Spacer()
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .accessibilityLabel(label)
                .font(.body)
        }
    }

    private var datesGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                dateField(label: "Last Update", date: $instrumentUpdatedAt)
                dateField(label: "Uploaded At", date: $uploadedAt)
            }
            GridRow {
                dateField(label: "Report Date", date: $reportDate)
            }
        }
    }

    private func dateField(label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .font(.body)
        }
    }

    private var isValid: Bool {
        accountId != nil &&
        institutionId != nil &&
        instrumentId != nil &&
        Double(quantity) != nil
    }

    private func loadData() {
        accounts = dbManager.fetchAccounts().map {
            (id: $0.id, name: $0.accountName, institutionId: $0.institutionId, institutionName: $0.institutionName)
        }
        instruments = dbManager.fetchAssets()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func populate() {
        guard let p = position else { return }
        sessionId = p.importSessionId.map { String($0) } ?? ""
        if let account = accounts.first(where: { $0.name == p.accountName }) {
            accountId = account.id
            institutionId = account.institutionId
            institutionName = account.institutionName
        }
        if let match = instruments.first(where: { $0.name == p.instrumentName }) {
            instrumentId = match.id
            instrumentQuery = displayString(for: match)
            if let lp = dbManager.getLatestPrice(instrumentId: match.id) { latestInstrumentPrice = lp.price }
        }
        currencyCode = p.instrumentCurrency
        quantity = String(p.quantity)
        if let pp = p.purchasePrice { purchasePrice = String(pp) }
        // currentPrice deprecated in positions; show nothing
        if let iu = p.instrumentUpdatedAt { instrumentUpdatedAt = iu }
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
        let currPrice: Double? = nil

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

private extension PositionFormView {
    func displayString(for ins: InstrumentInfo) -> String {
        var parts: [String] = [ins.name]
        if let t = ins.tickerSymbol, !t.isEmpty { parts.append(t.uppercased()) }
        if let i = ins.isin, !i.isEmpty { parts.append(i.uppercased()) }
        return parts.joined(separator: " • ")
    }

    func instrumentDisplayItems() -> [String] {
        instruments.map(displayString(for:))
    }
}
