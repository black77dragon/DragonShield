import SwiftUI

struct AssetAllocationView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AssetAllocationViewModel()

    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                AllocationRow(item: item,
                              targetChanged: { newValue in
                                  viewModel.updateTarget(for: item, to: newValue)
                              },
                              currencyFormatter: viewModel.currencyFormatter,
                              deviationColor: viewModel.deviationColor(for: item),
                              portfolioValue: viewModel.portfolioValue)
            }

            Section {
                AllocationTable(items: viewModel.items,
                                currencyFormatter: viewModel.currencyFormatter,
                                totalValue: viewModel.portfolioValue)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Asset Allocation")
        .onAppear { viewModel.load(using: dbManager) }
    }
}

private struct AllocationRow: View {
    var item: AllocationDisplayItem
    var targetChanged: (Double) -> Void
    var currencyFormatter: NumberFormatter
    var deviationColor: Color
    var portfolioValue: Double

    @State private var target: Double = 0
    private let barWidth: CGFloat = 250

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(item.assetClassName)
            Text(variationText())
                .font(.caption)
            Spacer()
            SliderWithMarkers(current: item.currentPercent,
                              target: $target,
                              deviationColor: deviationColor)
                .frame(width: barWidth, height: 24, alignment: .trailing)
                .onChange(of: target) { _, newValue in
                    targetChanged(newValue)
                }
        }
        .font(.subheadline)
        .onAppear { target = item.targetPercent }
    }

    private func variationText() -> String {
        let pctDiff = item.currentPercent - item.targetPercent
        let valueDiff = item.currentValueCHF - (portfolioValue * item.targetPercent / 100)
        let pctString = String(format: "%+.1f%%", pctDiff)
        let valString = String(format: "%+.1f kCHF", valueDiff / 1000)
        return "\(pctString) / \(valString)"
    }
}

private struct SliderWithMarkers: View {
    var current: Double
    @Binding var target: Double
    var deviationColor: Color

    private let trackHeight: CGFloat = 8
    private let markerSize: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackTop = (geo.size.height - trackHeight) / 2
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: trackHeight)
                    .offset(y: trackTop)
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: width * CGFloat(current / 100), height: trackHeight)
                    .offset(y: trackTop)
                Capsule()
                    .fill(deviationColor)
                    .frame(width: width * CGFloat(abs(current - target) / 100), height: trackHeight)
                    .offset(x: width * CGFloat(min(current, target) / 100), y: trackTop)
                Triangle()
                    .fill(Color.blue)
                    .frame(width: markerSize, height: markerSize)
                    .offset(x: width * CGFloat(target / 100) - markerSize / 2, y: trackTop - markerSize)
                Triangle()
                    .rotation(Angle(degrees: 180))
                    .fill(Color.gray)
                    .frame(width: markerSize, height: markerSize)
                    .offset(x: width * CGFloat(current / 100) - markerSize / 2, y: trackTop + trackHeight)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let pct = min(max(0, value.location.x / width * 100), 100)
                target = pct
            })
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct AllocationTable: View {
    var items: [AllocationDisplayItem]
    var currencyFormatter: NumberFormatter
    var totalValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Asset Class")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("CHF")
                    .frame(width: 80, alignment: .trailing)
                Text("%")
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.caption)

            ForEach(items) { item in
                HStack {
                    Text(item.assetClassName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(currencyFormatter.string(from: NSNumber(value: item.currentValueCHF)) ?? "")
                        .frame(width: 80, alignment: .trailing)
                    Text(String(format: "%.0f%%", item.currentPercent))
                        .frame(width: 50, alignment: .trailing)
                }
                .font(.caption)
            }

            Divider()
            HStack {
                Text("Total")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(currencyFormatter.string(from: NSNumber(value: totalValue)) ?? "")
                    .frame(width: 80, alignment: .trailing)
                Text("100%")
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.caption)
        }
    }
}

struct AssetAllocationView_Previews: PreviewProvider {
    static var previews: some View {
        AssetAllocationView()
            .environmentObject(DatabaseManager())
    }
}

