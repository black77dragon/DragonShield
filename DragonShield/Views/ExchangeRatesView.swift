import SwiftUI

struct ExchangeRatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var vm: ExchangeRatesViewModel

    init() {
        _vm = StateObject(wrappedValue: ExchangeRatesViewModel(db: DatabaseManager()))
    }

    var body: some View {
        VStack(spacing: 16) {
            filterBar
            ratesTable
            logPanel
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .onAppear { vm.loadRates() }
    }

    private var filterBar: some View {
        HStack {
            Picker("Currency", selection: $vm.selectedCurrency) {
                Text("All").tag(String?.none)
                ForEach(vm.currencies, id: \.code) { cur in
                    Text(cur.code).tag(String?.some(cur.code))
                }
            }
            DatePicker("As of", selection: $vm.asOfDate, displayedComponents: .date)
                .onChange(of: vm.asOfDate) { _, _ in vm.loadRates() }
            Spacer()
            Button(action: { showAddSheet = true }) {
                Label("New Rate", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command])
            .buttonStyle(PrimaryButtonStyle())
            .sheet(isPresented: $showAddSheet) { addSheet }
            Button(action: { Task { await updateFxNow() } }) {
                if updating { ProgressView().scaleEffect(0.8) } else { Label("Update FX Now", systemImage: "arrow.triangle.2.circlepath") }
            }
            .disabled(updating)
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    @State private var showAddSheet = false
    @State private var editRate: DatabaseManager.ExchangeRate? = nil
    @State private var showDeleteAlert = false
    @State private var rateToDelete: DatabaseManager.ExchangeRate? = nil
    @State private var updating: Bool = false

    private var ratesTable: some View {
        Table(vm.rates, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Currency") { rate in
                Text(rate.currencyCode)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            TableColumn("Rate Date", sortUsing: KeyPathComparator(\DatabaseManager.ExchangeRate.rateDate)) { rate in
                Text(rate.rateDate, formatter: DateFormatter.iso8601DateOnly)
            }
            TableColumn("Rate", sortUsing: KeyPathComparator(\DatabaseManager.ExchangeRate.rateToChf)) { rate in
                Text(String(format: "%.4f", rate.rateToChf))
            }
            TableColumn("Source") { rate in
                Text(rate.rateSource)
            }
            TableColumn("API Provider") { rate in
                Text(rate.apiProvider ?? "-")
            }
            TableColumn("Latest") { rate in
                Image(systemName: rate.isLatest ? "checkmark.square" : "square")
            }
            TableColumn("Created At") { rate in
                Text(rate.createdAt, formatter: DateFormatter.iso8601DateTime)
            }
            TableColumn("Actions") { rate in
                HStack {
                    Button { editRate = rate } label: { Image(systemName: "pencil") }
                        .buttonStyle(PlainButtonStyle())
                    Button { rateToDelete = rate; showDeleteAlert = true } label: { Image(systemName: "trash") }
                        .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .alert("Delete Rate", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let r = rateToDelete { vm.deleteRate(id: r.id) }
            }
        } message: {
            if let r = rateToDelete {
                Text("Delete rate for \(r.currencyCode) on \(DateFormatter.iso8601DateOnly.string(from: r.rateDate))?")
            }
        }
        .sheet(item: $editRate) { item in
            editSheet(rate: item)
        }
    }

    @State private var selection = Set<Int>()
    @State private var sortOrder = [KeyPathComparator(\DatabaseManager.ExchangeRate.rateDate, order: .reverse)]

    private var logPanel: some View {
        VStack(alignment: .leading) {
            Text("Exchange Rates Log").font(.headline)
            ScrollView {
                ForEach(vm.log.indices, id: \.self) { idx in
                    Text(vm.log[idx]).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var addSheet: some View {
        RateFormView(currencyOptions: vm.currencies.map { $0.code }) { currency, date, rate, source, provider, latest in
            vm.addRate(currency: currency, date: date, rate: rate, source: source, apiProvider: provider, latest: latest)
        }
    }

    private func editSheet(rate: DatabaseManager.ExchangeRate) -> some View {
        RateFormView(rate: rate, currencyOptions: vm.currencies.map { $0.code }) { currency, date, rateValue, source, provider, latest in
            vm.updateRate(id: rate.id, date: date, rate: rateValue, source: source, apiProvider: provider, latest: latest)
        }
    }
}

private struct RateFormView: View {
    var rate: DatabaseManager.ExchangeRate? = nil
    var currencyOptions: [String]
    var onSave: (String, Date, Double, String, String?, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currency: String
    @State private var date: Date
    @State private var rateValue: Double
    @State private var source: String
    @State private var provider: String
    @State private var latest: Bool

    init(rate: DatabaseManager.ExchangeRate? = nil, currencyOptions: [String], onSave: @escaping (String, Date, Double, String, String?, Bool) -> Void) {
        self.rate = rate
        self.currencyOptions = currencyOptions
        self.onSave = onSave
        _currency = State(initialValue: rate?.currencyCode ?? currencyOptions.first ?? "CHF")
        _date = State(initialValue: rate?.rateDate ?? Date())
        _rateValue = State(initialValue: rate?.rateToChf ?? 1)
        _source = State(initialValue: rate?.rateSource ?? "manual")
        _provider = State(initialValue: rate?.apiProvider ?? "")
        _latest = State(initialValue: rate?.isLatest ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Currency", selection: $currency) {
                ForEach(currencyOptions, id: \.self) { Text($0) }
            }
            DatePicker("Rate Date", selection: $date, displayedComponents: .date)
            TextField("Rate", value: $rateValue, formatter: NumberFormatter())
            Picker("Source", selection: $source) {
                Text("manual").tag("manual")
                Text("api").tag("api")
                Text("import").tag("import")
            }
            TextField("API Provider", text: $provider)
            Toggle("Latest", isOn: $latest)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Save") {
                    onSave(currency, date, rateValue, source, provider.isEmpty ? nil : provider, latest)
                    dismiss()
                }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .frame(width: 320)
    }
}

struct ExchangeRatesView_Previews: PreviewProvider {
    static var previews: some View {
        ExchangeRatesView()
            .environmentObject(DatabaseManager())
    }
}

// MARK: - FX Update helpers (View private extension)
extension ExchangeRatesView {

    private func updateFxNow() async {
        if updating { return }
        await MainActor.run { self.updating = true }
        let svc = FXUpdateService(dbManager: dbManager)
        let targets = svc.targetCurrencies(base: dbManager.baseCurrency)
        if targets.isEmpty {
            await MainActor.run {
                vm.log.append("No API-supported active currencies to update (base=\(dbManager.baseCurrency)).")
                self.updating = false
            }
            return
        }
        if let summary = await svc.updateLatestForAll(base: dbManager.baseCurrency) {
            await MainActor.run {
                vm.log.append("Updated FX: \(summary.insertedCount) currencies on \(DateFormatter.iso8601DateOnly.string(from: summary.asOf)) via \(summary.provider)")
                vm.loadRates()
                self.updating = false
            }
        } else {
            await MainActor.run {
                let err = (svc.lastError.map { String(describing: $0) } ?? "unknown error")
                vm.log.append("FX update failed at \(DateFormatter.iso8601DateTime.string(from: Date())) — \(err). Provider=exchangerate.host; base=\(dbManager.baseCurrency); targets=\(targets.joined(separator: ","))")
                self.updating = false
            }
        }
    }
}
