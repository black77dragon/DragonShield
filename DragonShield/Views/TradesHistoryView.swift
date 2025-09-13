import SwiftUI

struct TradesHistoryView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var trades: [DatabaseManager.TradeWithLegs] = []
    @State private var selected: DatabaseManager.TradeWithLegs? = nil
    @State private var showForm = false
    @State private var showReverseConfirm = false
    @State private var showDeleteConfirm = false
    @State private var editTradeId: Int? = nil
    @State private var search = ""

    var filtered: [DatabaseManager.TradeWithLegs] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return trades }
        let q = search.lowercased()
        return trades.filter { row in
            row.instrumentName.lowercased().contains(q) ||
            row.custodyAccountName.lowercased().contains(q) ||
            row.cashAccountName.lowercased().contains(q) ||
            row.currency.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.98), Color(white: 0.95), Color(white: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                infoBanner
                controls
                table
                actionBar
            }
        }
        .onAppear { dbManager.ensureTradeSchema(); reload() }
        .sheet(isPresented: $showForm) {
            TradeFormView(onSaved: { reload(); showForm = false }, onCancel: { showForm = false }, editTradeId: editTradeId)
                .environmentObject(dbManager)
        }
        .alert("Reverse Trade", isPresented: $showReverseConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reverse", role: .destructive) {
                if let t = selected { _ = dbManager.rewindTrade(tradeId: t.tradeId); reload() }
            }
        } message: {
            Text("Create a reversing trade for #\(selected?.tradeId ?? 0)?")
        }
        .alert("Delete Trade", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let t = selected { _ = dbManager.deleteTrade(tradeId: t.tradeId); reload() }
            }
        } message: {
            Text("Permanently delete trade #\(selected?.tradeId ?? 0)?")
        }
    }

    // MARK: - Info Banner
    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text("Transactions are NOT updating the custody and cash accounts. They are maintained manually. Currently the purpose of the transaction journal is to calculate the P&L of transactions only.")
                .font(.callout)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("Transactions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
                Text("Buy/Sell trades with cash and instrument legs")
                    .foregroundColor(.gray)
            }
            Spacer()
            Button(action: { reload() }) { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var controls: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search instrument/account/currency", text: $search)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ID").foregroundColor(.gray).frame(width: 60, alignment: .leading)
                Text("Date").foregroundColor(.gray).frame(width: 100, alignment: .leading)
                Text("Type").foregroundColor(.gray).frame(width: 80, alignment: .leading)
                Text("Instrument").foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                Text("Qty").foregroundColor(.gray).frame(width: 80, alignment: .trailing)
                Text("Price").foregroundColor(.gray).frame(width: 100, alignment: .trailing)
                Text("Cash Δ").foregroundColor(.gray).frame(width: 120, alignment: .trailing)
                Text("Custody").foregroundColor(.gray).frame(width: 200, alignment: .leading)
                Text("Cash Acc").foregroundColor(.gray).frame(width: 200, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filtered) { t in
                        HStack {
                            Text("#\(t.tradeId)").frame(width: 60, alignment: .leading).foregroundColor(.secondary)
                            Text(t.date, formatter: DateFormatter.iso8601DateOnly).frame(width: 100, alignment: .leading)
                            Text(t.typeCode.capitalized).frame(width: 80, alignment: .leading)
                            Text(t.instrumentName).frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "%.4f", t.quantity)).frame(width: 80, alignment: .trailing).monospacedDigit()
                            Text(String(format: "%.4f", t.price)).frame(width: 100, alignment: .trailing).monospacedDigit()
                            Text(String(format: "%.4f %@", t.cashDelta, t.currency)).frame(width: 120, alignment: .trailing).monospacedDigit().foregroundColor(t.cashDelta >= 0 ? .green : .red)
                            Text(t.custodyAccountName).frame(width: 200, alignment: .leading).foregroundColor(.secondary)
                            Text(t.cashAccountName).frame(width: 200, alignment: .leading).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(selected?.tradeId == t.tradeId ? Color.green.opacity(0.06) : Color.clear))
                        .onTapGesture { selected = t }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
            HStack(spacing: 12) {
                Button { editTradeId = nil; showForm = true } label: { Label("New Trade", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { if let s = selected { editTradeId = s.tradeId; showForm = true } } label: { Label("Edit", systemImage: "pencil") }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(selected == nil)
                Button { showReverseConfirm = true } label: { Label("Reverse", systemImage: "arrow.uturn.left") }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(selected == nil)
                Button { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                    .buttonStyle(DestructiveButtonStyle())
                    .disabled(selected == nil)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    private func reload() { trades = dbManager.fetchTradesWithLegs() }
}

struct TradesHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        TradesHistoryView().environmentObject(DatabaseManager())
    }
}
