// DragonShield/Views/AssetAllocationView.swift
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.assetClassName)
                .font(.headline)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: geo.size.width * CGFloat(item.targetPercent/100), height: 8)
                    Capsule()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(item.currentPercent/100), height: 8)
                    if deviation > 0 {
                        let start = min(item.currentPercent, item.targetPercent)
                        let width = abs(item.currentPercent - item.targetPercent)
                        Capsule()
                            .fill(deviationColor.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(width/100), height: 8)
                            .offset(x: geo.size.width * CGFloat(start/100))
                    }
                    AllocationMarker()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .offset(x: geo.size.width * CGFloat(item.targetPercent/100) - 4, y: -4)
                    AllocationMarker()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .offset(x: geo.size.width * CGFloat(item.currentPercent/100) - 4, y: 4)
                }
            }
            .frame(height: 16)
            HStack {
                Text(String(format: "T: %.0f%% / %.1f kCHF", item.targetPercent, item.targetPercent/100 * portfolioValue / 1000))
                Spacer()
                Text(String(format: "A: %.0f%% / %.1f kCHF", item.currentPercent, item.currentValue / 1000))
            }
            .font(.caption)
            .foregroundColor(deviationColor)
        }
        .padding(.vertical, 8)
    }
}

struct AssetAllocationView: View {
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
struct AssetAllocationView_Previews: PreviewProvider {
    static var previews: some View {
        AssetAllocationView()
            .environmentObject(DatabaseManager())
    }
}
#endif

