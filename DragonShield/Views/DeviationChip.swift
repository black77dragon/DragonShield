import SwiftUI

struct DeviationChip: View {
    let actualPct: Double
    let targetPct: Double
    let tolerance: Double
    let excluded: Bool
    let baselineName: String

    private var metrics: DeviationMetrics? {
        excluded ? nil : DeviationAnalytics.deviation(actual: actualPct, target: targetPct, tolerance: tolerance)
    }

    var body: some View {
        if let metrics = metrics {
            GeometryReader { geo in
                ZStack(alignment: metrics.delta >= 0 ? .leading : .trailing) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(color(for: metrics).opacity(0.3))
                        .frame(width: barWidth(for: metrics, total: geo.size.width))
                    Text("\(symbol(for: metrics.state)) \(metrics.displayString())")
                        .foregroundColor(color(for: metrics))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 110, height: 20)
            .help("Actual \(actualPct, format: .number.precision(.fractionLength(1)))% vs Target \(targetPct, format: .number.precision(.fractionLength(1)))% = Δ \(metrics.displayString())")
            .accessibilityLabel(accessibility(for: metrics))
        } else {
            Text("—")
                .frame(width: 110, height: 20)
                .foregroundColor(.gray)
                .help("Excluded from valuation")
        }
    }

    private func color(for metrics: DeviationMetrics) -> Color {
        switch metrics.state {
        case .within: return .gray
        case .overweight: return .green
        case .underweight: return .red
        }
    }

    private func barWidth(for metrics: DeviationMetrics, total: CGFloat) -> CGFloat {
        let pct = min(abs(metrics.delta), 25.0) / 25.0
        return total * pct
    }

    private func symbol(for state: DeviationState) -> String {
        switch state {
        case .within: return "•"
        case .overweight: return "▲"
        case .underweight: return "▼"
        }
    }

    private func accessibility(for metrics: DeviationMetrics) -> String {
        let action: String
        switch metrics.state {
        case .within: action = "within tolerance by"
        case .overweight: action = "overweight by"
        case .underweight: action = "underweight by"
        }
        return "\(action) \(abs(metrics.delta).formatted(.number.precision(.fractionLength(1)))) percent versus \(baselineName)"
    }
}
