import SwiftUI

struct AllocationHeatMapTile: View {
    let items: [AssetAllocationVarianceItem]
    let portfolioValue: Double

    @State private var hovered: AssetAllocationVarianceItem?
    @State private var showDetail: AssetAllocationVarianceItem?

    struct LayoutItem: Identifiable {
        let id = UUID()
        let item: AssetAllocationVarianceItem
        let rect: CGRect
    }

    struct HeatMapCell: View {
        let layout: LayoutItem
        @Binding var hovered: AssetAllocationVarianceItem?
        @Binding var showDetail: AssetAllocationVarianceItem?
        let portfolioValue: Double
        let color: Color

        private var isHovered: Binding<AssetAllocationVarianceItem?> {
            Binding {
                hovered?.id == layout.item.id ? hovered : nil
            } set: { newValue in
                hovered = newValue
            }
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(color)
                if layout.item.currentPercent >= 1 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(layout.item.assetClassName)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(String(format: "%.1f%% / %.1f%%",
                                    layout.item.currentPercent,
                                    layout.item.targetPercent))
                            .font(.caption2)
                        Text(String(format: "%+.1f%%",
                                    layout.item.currentPercent - layout.item.targetPercent))
                            .font(.caption2)
                    }
                    .padding(4)
                    .foregroundColor(.white)
                    .clipped()
                }
            }
            .mask(Rectangle())
            .frame(width: layout.rect.width, height: layout.rect.height)
            .position(x: layout.rect.midX, y: layout.rect.midY)
            .contentShape(Rectangle())
            .onHover { inside in
                hovered = inside ? layout.item : (hovered?.id == layout.item.id ? nil : hovered)
            }
            .onTapGesture(count: 2) {
                showDetail = layout.item
            }
            .popover(item: isHovered) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.assetClassName).font(.headline)
                    Text(String(format: "Current: %.1f%%", item.currentPercent))
                    Text(String(format: "Target: %.1f%%", item.targetPercent))
                    Text(String(format: "Deviation: %+.1f%%",
                                item.currentPercent - item.targetPercent))
                    if let date = item.lastRebalance {
                        Text("Last Rebalance: \(date, style: .date)")
                    }
                    let amount = (item.targetPercent - item.currentPercent) / 100 * portfolioValue
                    Text(String(format: "Rebalance: %.2f CHF", amount))
                }
                .padding()
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let layouts = computeLayout(in: geo.size)
            ZStack {
                ForEach(layouts) { layout in
                    HeatMapCell(layout: layout,
                                hovered: $hovered,
                                showDetail: $showDetail,
                                portfolioValue: portfolioValue,
                                color: color(for: layout.item))
                }
            }
        }
        .frame(minWidth: 300, minHeight: 200)
        .sheet(item: $showDetail) { item in
            Text("Detailed view for \(item.assetClassName)")
                .padding()
        }
    }

    private func color(for item: AssetAllocationVarianceItem) -> Color {
        let delta = abs(item.currentPercent - item.targetPercent)
        switch delta {
        case ..<2:
            return .success
        case 2 ..< 5:
            return .warning
        case 5 ..< 10:
            return .orange
        default:
            return .error
        }
    }

    private func computeLayout(in size: CGSize) -> [LayoutItem] {
        var layouts: [LayoutItem] = []
        let total = items.map { $0.currentPercent }.reduce(0, +)
        var remainingRect = CGRect(origin: .zero, size: size)
        var horizontal = size.width > size.height
        for item in items.sorted(by: { $0.currentPercent > $1.currentPercent }) {
            let ratio = item.currentPercent / total
            if horizontal {
                let width = remainingRect.width * CGFloat(ratio)
                let rect = CGRect(x: remainingRect.minX, y: remainingRect.minY, width: width, height: remainingRect.height)
                remainingRect.origin.x += width
                remainingRect.size.width -= width
                layouts.append(LayoutItem(item: item, rect: rect))
            } else {
                let height = remainingRect.height * CGFloat(ratio)
                let rect = CGRect(x: remainingRect.minX, y: remainingRect.minY, width: remainingRect.width, height: height)
                remainingRect.origin.y += height
                remainingRect.size.height -= height
                layouts.append(LayoutItem(item: item, rect: rect))
            }
            horizontal.toggle()
        }
        return layouts
    }
}

struct AllocationHeatMapTile_Previews: PreviewProvider {
    static var previews: some View {
        AllocationHeatMapTile(items: [
            AssetAllocationVarianceItem(id: "Equity", assetClassName: "Equities", currentPercent: 55, targetPercent: 60, currentValue: 35500, lastRebalance: Date()),
            AssetAllocationVarianceItem(id: "ETF", assetClassName: "ETFs", currentPercent: 20, targetPercent: 25, currentValue: 11000, lastRebalance: Date()),
            AssetAllocationVarianceItem(id: "Crypto", assetClassName: "Crypto", currentPercent: 15, targetPercent: 10, currentValue: 9500, lastRebalance: Date()),
        ], portfolioValue: 56000)
    }
}
