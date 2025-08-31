import SwiftUI

struct PriceHistoryView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let instrumentId: Int
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [DatabaseManager.InstrumentPriceHistoryRow] = []
    @State private var isLoading = false

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 6
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Price History").font(.title3).bold()
                Spacer()
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
            }
            .padding(.bottom, 4)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                header
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(rows) { r in
                            rowView(r)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 680, minHeight: 420)
        .onAppear(perform: reload)
    }

    private var header: some View {
        HStack {
            Text("As Of").frame(width: 190, alignment: .leading)
            Text("Price").frame(width: 160, alignment: .trailing)
            Text("Currency").frame(width: 80, alignment: .leading)
            Text("Source").frame(width: 140, alignment: .leading)
            Spacer()
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func rowView(_ r: DatabaseManager.InstrumentPriceHistoryRow) -> some View {
        HStack {
            Text(formatAsOf(r.asOf)).frame(width: 190, alignment: .leading)
            Text(Self.priceFormatter.string(from: NSNumber(value: r.price)) ?? String(r.price))
                .frame(width: 160, alignment: .trailing)
                .monospacedDigit()
            Text(r.currency).frame(width: 80, alignment: .leading)
            Text(r.source ?? "").frame(width: 140, alignment: .leading)
            Spacer()
        }
        .font(.system(size: 12))
        .padding(.vertical, 2)
    }

    private func reload() {
        isLoading = true
        DispatchQueue.global().async {
            let data = dbManager.listPriceHistory(instrumentId: instrumentId, limit: 50)
            DispatchQueue.main.async {
                self.rows = data
                self.isLoading = false
            }
        }
    }

    // MARK: - Date formatting matching Prices view
    private func iso8601Formatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private func formatAsOf(_ s: String) -> String {
        let tz = TimeZone(identifier: dbManager.defaultTimeZone) ?? .current
        // Try ISO with fractional seconds
        if let d = iso8601Formatter().date(from: s) ?? {
            // Try ISO without fractional seconds
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }() ?? {
            // Try date-only format yyyy-MM-dd
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(secondsFromGMT: 0)
            return df.date(from: s)
        }() {
            let cal = Calendar.current
            let comps = cal.dateComponents(in: tz, from: d)
            let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0 || (comps.second ?? 0) != 0
            let out = DateFormatter()
            out.timeZone = tz
            out.dateFormat = hasTime ? "dd.MM.yy HH:mm" : "dd.MM.yy"
            return out.string(from: d)
        }
        // Fallback: best-effort transform if matches yyyy-MM-dd
        if s.count == 10, s[ s.index(s.startIndex, offsetBy: 4) ] == "-" {
            let parts = s.split(separator: "-")
            if parts.count == 3 {
                let yyyy = parts[0]; let mm = parts[1]; let dd = parts[2]
                let shortYY = yyyy.suffix(2)
                return "\(dd).\(mm).\(shortYY)"
            }
        }
        return s
    }
}

#if DEBUG
struct PriceHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        PriceHistoryView(instrumentId: 1)
            .environmentObject(DatabaseManager())
    }
}
#endif
