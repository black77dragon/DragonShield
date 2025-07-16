// DragonShield/Views/AssetClassAllocationView.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Display actual vs target allocation on single slider.

import SwiftUI

struct AllocationMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct AllocationRow: View {
    let item: AssetAllocationVarianceItem
    let portfolioValue: Double

    private var deviation: Double { abs(item.currentPercent - item.targetPercent) }

    private var deviationColor: Color {
        switch deviation {
        case ..<5: return .success
        case 5..<15: return .warning
        default: return .error
        }
    }

    private var targetValue: Double { (item.targetPercent / 100) * portfolioValue }
    private var targetLabel: String {
        String(format: "T: %.0f%% / %.1f kCHF", item.targetPercent, targetValue / 1000)
    }
    private var actualLabel: String {
        String(format: "A: %.0f%% / %.1f kCHF", item.currentPercent, item.currentValue / 1000)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.assetClassName)
                .font(.headline)
            GeometryReader { geo in
                let width = geo.size.width
                let targetX = width * CGFloat(item.targetPercent / 100)
                let actualX = width * CGFloat(item.currentPercent / 100)
                let startX = min(targetX, actualX)
                let overlayWidth = abs(targetX - actualX)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    Capsule()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: targetX, height: 8)

                    Capsule()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: actualX, height: 8)

                    if overlayWidth > 0 {
                        Capsule()
                            .fill(deviationColor.opacity(0.5))
                            .frame(width: overlayWidth, height: 8)
                            .offset(x: startX)
                            .zIndex(1)
                    }

                    AllocationMarker()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .offset(x: targetX - 5, y: -6)
                        .zIndex(2)

                    AllocationMarker()
                        .fill(Color.gray)
                        .frame(width: 10, height: 10)
                        .offset(x: actualX - 5, y: 6)
                        .zIndex(2)

                    Text(targetLabel)
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .offset(x: targetX + 6, y: -14)
                        .zIndex(2)

                    Text(actualLabel)
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .offset(x: actualX + 6, y: 10)
                        .zIndex(2)
                }
            }
            .frame(height: 24)
        }
        .padding(.vertical, 8)
    }
}

struct AssetClassAllocationView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var items: [AssetAllocationVarianceItem] = []
    @State private var portfolioValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                AllocationRow(item: item, portfolioValue: portfolioValue)
            }
        }
        .padding()
        .onAppear(perform: loadData)
    }

    private func loadData() {
        let result = dbManager.fetchAssetAllocationVariance()
        items = result.items
        portfolioValue = result.portfolioValue
    }
}

#if DEBUG
struct AssetClassAllocationView_Previews: PreviewProvider {
    static var previews: some View {
        AssetClassAllocationView()
            .environmentObject(DatabaseManager())
    }
}
#endif

