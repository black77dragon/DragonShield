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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.assetClassName)
                Spacer()
            }
            .font(.subheadline)
            SliderWithMarkers(current: item.currentPercent,
                              target: $target,
                              deviationColor: deviationColor)
                .frame(height: 24)
                .onChange(of: target) { newValue in
                    targetChanged(newValue)
                }
            HStack {
                Text(labelText(prefix: "T", pct: target, value: portfolioValue * target / 100))
                    .font(.caption)
                Spacer()
                Text(labelText(prefix: "A", pct: item.currentPercent, value: item.currentValueCHF))
                    .font(.caption)
            }
        }
        .onAppear { target = item.targetPercent }
    }

    private func labelText(prefix: String, pct: Double, value: Double) -> String {
        let valueString = currencyFormatter.string(from: NSNumber(value: value)) ?? ""
        return String(format: "%@: %.0f%% / %@", prefix, pct, valueString)
    }
}

private struct SliderWithMarkers: View {
    var current: Double
    @Binding var target: Double
    var deviationColor: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2)).frame(height: 6)
                Capsule()
                    .fill(deviationColor.opacity(0.4))
                    .frame(width: width * CGFloat(abs(current - target) / 100), height: 6)
                    .offset(x: width * CGFloat(min(current, target) / 100))
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: width * CGFloat(current / 100), height: 6)
                Triangle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 6)
                    .offset(x: width * CGFloat(target / 100) - 5, y: -4)
                Triangle()
                    .rotation(Angle(degrees: 180))
                    .fill(Color.gray)
                    .frame(width: 10, height: 6)
                    .offset(x: width * CGFloat(current / 100) - 5, y: 6)
            }
            .frame(height: 6)
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

struct AssetAllocationView_Previews: PreviewProvider {
    static var previews: some View {
        AssetAllocationView()
            .environmentObject(DatabaseManager())
    }
}

