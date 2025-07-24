import SwiftUI

struct MapLegend: View {
    let viewModel: CurrencyMapViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { idx in
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(viewModel.color(for: viewModel.quantileBreaks[min(idx+1, viewModel.quantileBreaks.count-1)]))
                        .frame(width: 20, height: 12)
                    Text(viewModel.rangeText(for: idx))
                        .font(.caption2)
                }
            }
        }
    }
}
