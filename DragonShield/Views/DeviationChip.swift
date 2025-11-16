import SwiftUI

struct DeviationChip: View {
    let delta: Double?
    let target: Double
    let actual: Double
    let tolerance: Double
    let baseline: String

    private enum State {
        case excluded, within, over, under
    }

    private var state: State {
        guard let d = delta else { return .excluded }
        if d > tolerance { return .over }
        if d < -tolerance { return .under }
        return .within
    }

    private var symbol: String {
        switch state {
        case .excluded: return "—"
        case .within: return "•"
        case .over: return "▲"
        case .under: return "▼"
        }
    }

    private var color: Color {
        switch state {
        case .within: return .gray
        case .over: return .green
        case .under: return .red
        case .excluded: return .secondary
        }
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private var formattedDelta: String {
        guard let d = delta else { return "—" }
        return String(format: "%+.1f%%", d)
    }

    private var accessibilityText: String {
        switch state {
        case .excluded:
            return "Excluded from valuation"
        case .within:
            return "Within tolerance by \(fmt(abs(delta ?? 0))) percent versus \(baseline)"
        case .over:
            return "Overweight by \(fmt(abs(delta ?? 0))) percent versus \(baseline)"
        case .under:
            return "Underweight by \(fmt(abs(delta ?? 0))) percent versus \(baseline)"
        }
    }

    private static let maxDeviationForBar: Double = 25.0

    var body: some View {
        if let d = delta {
            GeometryReader { geo in
                ZStack(alignment: d >= 0 ? .leading : .trailing) {
                    Capsule().stroke(Color.secondary.opacity(0.3))
                    Capsule()
                        .fill(color.opacity(0.2))
                        .frame(width: geo.size.width * min(abs(d), Self.maxDeviationForBar) / Self.maxDeviationForBar)
                    Text("\(symbol) \(formattedDelta)")
                        .font(.caption)
                        .foregroundColor(color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 110, height: 20)
            .help("Actual \(fmt(actual))% vs Target \(fmt(target))% = Δ \(formattedDelta)")
            .accessibilityLabel(accessibilityText)
        } else {
            Text("—")
                .frame(width: 110, height: 20)
                .foregroundColor(.secondary)
                .accessibilityLabel(accessibilityText)
                .help("Excluded from valuation")
        }
    }
}
