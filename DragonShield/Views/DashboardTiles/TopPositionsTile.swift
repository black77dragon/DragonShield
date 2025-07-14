import SwiftUI

struct TopPositionsTile: DashboardTile {
    init() {}
    static let tileID = "top_positions_chf"
    static let tileName = "Top 10 Positions by Asset Value (CHF)"
    static let iconName = "list.number"

    @StateObject private var vm = PositionsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.tileName)
                .font(.headline)
                .padding(.bottom, 8)
            header
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.top10PositionsCHF.indices, id: \.self) { idx in
                        let item = vm.top10PositionsCHF[idx]
                        row(item: item, highlight: idx == 0)
                    }
                }
            }
            .frame(maxHeight: vm.top10PositionsCHF.count > 6 ? 240 : .none)
        }
        .padding(16)
        .background(Color(red: 216/255, green: 236/255, blue: 248/255))
        .cornerRadius(12)
        .onAppear { vm.loadTopPositions() }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Instrument")
                    .font(.footnote.weight(.medium))
                Spacer()
                Text("Value (CHF)")
                    .font(.footnote.weight(.medium))
                Text("Curr")
                    .font(.footnote.weight(.medium))
                    .frame(width: 40, alignment: .trailing)
            }
            .foregroundColor(Color(red: 107/255, green: 114/255, blue: 128/255))
            .padding(.bottom, 4)
            Rectangle()
                .fill(Color(red: 229/255, green: 231/255, blue: 235/255))
                .frame(height: 1)
        }
    }

    private func row(item: PositionsViewModel.TopPositionCHF, highlight: Bool) -> some View {
        HStack {
            Text(item.instrumentName)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(String(format: "%.2f CHF", item.valueChf))
                .font(.body.weight(.medium))
                .foregroundColor(Color(red: 30/255, green: 58/255, blue: 138/255))
            Text(item.currency)
                .font(.caption)
                .frame(width: 40, alignment: .trailing)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(highlight ? Color(red: 191/255, green: 219/255, blue: 254/255) : Color.clear)
        .cornerRadius(6)
    }
}
