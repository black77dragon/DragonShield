import SwiftUI

struct DeviationChip: View {
    let actual: Double
    let target: Double
    let tolerance: Double
    let baselineName: String
    let isExcluded: Bool

    private var delta: Double { computeDelta(actual: actual, target: target) }
    private var state: DeviationState { deviationState(delta: delta, tolerance: tolerance) }

    private var formattedDelta: String { String(format: "%+.1f%%", delta) }
    private var formattedActual: String { String(format: "%.1f%%", actual) }
    private var formattedTarget: String { String(format: "%.1f%%", target) }

    private var barFraction: Double { min(abs(delta), 25) / 25 }

    private var color: Color {
        switch state {
        case .within:
            return .secondary
        case .over:
            return .green
        case .under:
            return .red
        }
    }

    private var tooltip: String {
        "Actual \(formattedActual) vs \(baselineName) \(formattedTarget) = Δ \(formattedDelta)"
    }

    private var accessibilityText: String {
        let absDelta = String(format: "%.1f", abs(delta))
        switch state {
        case .over:
            return "Overweight by \(absDelta) percent versus \(baselineName)"
        case .under:
            return "Underweight by \(absDelta) percent versus \(baselineName)"
        case .within:
            return "Within tolerance by \(absDelta) percent versus \(baselineName)"
        }
    }

    var body: some View {
        if isExcluded {
            Text("—")
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .trailing)
                .help("Excluded from valuation")
                .accessibilityLabel("Excluded from valuation")
        } else {
            ZStack {
                GeometryReader { geo in
                    let width = geo.size.width
                    let barWidth = width * barFraction
                    HStack(spacing: 0) {
                        if delta >= 0 {
                            Rectangle().fill(color.opacity(0.2)).frame(width: barWidth)
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 0)
                            Rectangle().fill(color.opacity(0.2)).frame(width: barWidth)
                        }
                    }
                }
                .clipShape(Capsule())
                Capsule().stroke(color.opacity(0.5))
                Text(formattedDelta)
                    .foregroundColor(color)
                    .monospacedDigit()
            }
            .frame(width: 110, height: 20)
            .help(tooltip)
            .accessibilityLabel(accessibilityText)
        }
    }
}

