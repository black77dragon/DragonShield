import SwiftUI

struct HistoricPerformanceDataView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [PortfolioValueHistoryRow] = []
    @State private var isLoading = false
    @State private var editingRow: PortfolioValueHistoryRow? = nil
    @State private var showingEditor = false
    @State private var deleteTarget: PortfolioValueHistoryRow? = nil

    private static let valueFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy"
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = .current
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Historic Performance Data")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    editingRow = nil
                    showingEditor = true
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if rows.isEmpty {
                Text("No historic values stored yet.")
                    .foregroundColor(.secondary)
            } else {
                header
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(rows) { row in
                            rowView(row)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 480)
        .onAppear(perform: reload)
        .sheet(isPresented: $showingEditor, onDismiss: reload) {
            HistoricPerformanceValueEditor(existing: editingRow) {
                reload()
            }
            .environmentObject(dbManager)
        }
        .alert("Delete entry?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let target = deleteTarget {
                Text("Delete the value for \(Self.dateFormatter.string(from: displayDate(for: target.valueDate)))? This cannot be undone.")
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Date").frame(width: 120, alignment: .leading)
            Text("Total Asset Value (CHF)").frame(width: 200, alignment: .trailing)
            Spacer()
            Text("").frame(width: 120, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func rowView(_ row: PortfolioValueHistoryRow) -> some View {
        HStack {
            Text(Self.dateFormatter.string(from: displayDate(for: row.valueDate)))
                .frame(width: 120, alignment: .leading)
            Text(formatValue(row.totalValueChf))
                .frame(width: 200, alignment: .trailing)
                .monospacedDigit()
            Spacer()
            HStack(spacing: 8) {
                Button {
                    editingRow = row
                    showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    deleteTarget = row
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .font(.system(size: 12))
    }

    private func reload() {
        isLoading = true
        DispatchQueue.global().async {
            let data = dbManager.listPortfolioValueHistory()
            let sorted = data.sorted { $0.valueDate > $1.valueDate }
            DispatchQueue.main.async {
                rows = sorted
                isLoading = false
            }
        }
    }

    private func delete() {
        guard let target = deleteTarget else { return }
        _ = dbManager.deletePortfolioValueHistory(on: target.valueDate)
        deleteTarget = nil
        reload()
    }

    private func formatValue(_ value: Double) -> String {
        let formatted = Self.valueFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "CHF \(formatted)"
    }

    private func displayDate(for storedDate: Date) -> Date {
        let utc = TimeZone(secondsFromGMT: 0) ?? .current
        let calendar = Calendar(identifier: .gregorian)
        var comps = calendar.dateComponents(in: utc, from: storedDate)
        comps.timeZone = TimeZone.current
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? storedDate
    }
}

private struct HistoricPerformanceValueEditor: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    let existing: PortfolioValueHistoryRow?
    let onSave: () -> Void

    @State private var selectedDate: Date
    @State private var valueText: String
    @State private var errorMessage: String? = nil

    private static let inputFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    init(existing: PortfolioValueHistoryRow?, onSave: @escaping () -> Void) {
        self.existing = existing
        self.onSave = onSave
        let initialDate = existing?.valueDate ?? Date()
        _selectedDate = State(initialValue: initialDate)
        if let value = existing?.totalValueChf {
            let text = Self.inputFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
            _valueText = State(initialValue: text)
        } else {
            _valueText = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "Add Historic Value" : "Edit Historic Value")
                .font(.title2)
                .bold()

            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                #if os(macOS)
                    .datePickerStyle(.field)
                #else
                    .datePickerStyle(.compact)
                #endif
            TextField("CHF value", text: $valueText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)

            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }

    private func save() {
        let cleaned = valueText.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned) else {
            errorMessage = "Enter a valid CHF value."
            return
        }

        let normalized = storageDate(for: selectedDate)
        let oldKey = existing.map { dateKey($0.valueDate) }
        let newKey = dateKey(normalized)

        if dbManager.recordDailyPortfolioValue(valueChf: value, date: normalized) {
            if let oldKey, oldKey != newKey, let existing {
                _ = dbManager.deletePortfolioValueHistory(on: existing.valueDate)
            }
            onSave()
            dismiss()
        } else {
            errorMessage = "Failed to save entry."
        }
    }

    private func storageDate(for date: Date) -> Date {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone.current
        let comps = localCalendar.dateComponents([.year, .month, .day], from: date)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var utcComps = DateComponents()
        utcComps.year = comps.year
        utcComps.month = comps.month
        utcComps.day = comps.day
        utcComps.hour = 0
        utcComps.minute = 0
        utcComps.second = 0
        utcComps.timeZone = utcCalendar.timeZone
        return utcCalendar.date(from: utcComps) ?? date
    }

    private func dateKey(_ date: Date) -> String {
        DateFormatter.iso8601DateOnly.string(from: date)
    }
}

#if DEBUG
    struct HistoricPerformanceDataView_Previews: PreviewProvider {
        static var previews: some View {
            let manager = DatabaseManager()
            HistoricPerformanceDataView()
                .environmentObject(manager)
        }
    }
#endif
