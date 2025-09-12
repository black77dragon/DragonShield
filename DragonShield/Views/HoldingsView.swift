import SwiftUI

struct HoldingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [DatabaseManager.HoldingRow] = []
    @State private var search: String = ""
    @State private var sortByAccount = true

    var filtered: [DatabaseManager.HoldingRow] {
        var r = rows
        if !search.isEmpty {
            let q = search.lowercased()
            r = r.filter { $0.accountName.lowercased().contains(q) || $0.instrumentName.lowercased().contains(q) || $0.currency.lowercased().contains(q) }
        }
        return r
    }

    static let chf: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0; f.groupingSeparator = "'"; f.usesGroupingSeparator = true; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
            table
        }
        .onAppear { load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "tray.full.fill").font(.system(size: 28)).foregroundColor(.blue)
                    Text("Holdings (Live)").font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Text("Derived from transactions as of as-of date").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var controls: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search account or instrument", text: $search).textFieldStyle(PlainTextFieldStyle())
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
            Spacer()
            Button { load() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Account").frame(width: 200, alignment: .leading).foregroundColor(.gray)
                Text("Instrument").frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.gray)
                Text("Curr").frame(width: 50, alignment: .leading).foregroundColor(.gray)
                Text("Qty").frame(width: 80, alignment: .trailing).foregroundColor(.gray)
                Text("Avg Cost CHF").frame(width: 120, alignment: .trailing).foregroundColor(.gray)
                Text("Invested CHF").frame(width: 140, alignment: .trailing).foregroundColor(.gray)
                Text("Dividends CHF").frame(width: 140, alignment: .trailing).foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filtered) { h in
                        HStack {
                            Text(h.accountName).frame(width: 200, alignment: .leading)
                            Text(h.instrumentName).frame(maxWidth: .infinity, alignment: .leading)
                            Text(h.currency).frame(width: 50, alignment: .leading)
                            Text(String(format: "%.4f", h.totalQuantity)).monospacedDigit().frame(width: 80, alignment: .trailing)
                            Text(Self.chf.string(from: NSNumber(value: h.avgCostChfPerUnit)) ?? "0").monospacedDigit().frame(width: 120, alignment: .trailing)
                            Text(Self.chf.string(from: NSNumber(value: h.totalInvestedChf)) ?? "0").monospacedDigit().frame(width: 140, alignment: .trailing)
                            Text(Self.chf.string(from: NSNumber(value: h.totalDividendsChf)) ?? "0").monospacedDigit().frame(width: 140, alignment: .trailing)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                    }
                }
            }
        }
    }

    private func load() { rows = dbManager.fetchHoldingsFromTransactions() }
}

struct HoldingsView_Previews: PreviewProvider {
    static var previews: some View {
        HoldingsView().environmentObject(DatabaseManager())
    }
}

