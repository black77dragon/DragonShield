// DragonShield/Views/DeviationChip.swift
// Renders a deviation value with mini bar and color coding.

import SwiftUI

struct DeviationChip: View {
    let delta: Double?
    let actual: Double
    let target: Double
    let tolerance: Double
    let baseline: String

    private let clamp: Double = 25.0

    var body: some View {
        Group {
            if let delta {
                let state = Deviation.state(for: delta, tolerance: tolerance)
                let color = colorFor(state)
                ZStack {
                    GeometryReader { geo in
                        let width = geo.size.width
                        let fraction = min(abs(delta), clamp) / clamp
                        let barWidth = width * fraction
                        Capsule()
                            .fill(color.opacity(0.2))
                            .frame(width: barWidth)
                            .offset(x: delta >= 0 ? 0 : width - barWidth)
                    }
                    .clipShape(Capsule())
                    Text("\(symbolFor(state)) \(delta, format: .number.precision(.fractionLength(1)).sign(strategy: .always()))")
                        .foregroundColor(color)
                }
                .frame(width: 120, height: 20)
                .overlay(Capsule().stroke(color))
                .help("Actual \(actual, format: .number.precision(.fractionLength(1)))% vs Target \(target, format: .number.precision(.fractionLength(1)))% = Δ \(delta, format: .number.precision(.fractionLength(1)).sign(strategy: .always()))%")
                .accessibilityLabel(accessibilityLabel(for: state, delta: delta))
            } else {
                Text("—")
                    .frame(width: 120, height: 20)
                    .foregroundColor(.secondary)
                    .overlay(Capsule().stroke(Color.secondary))
                    .help("Excluded from valuation")
            }
        }
    }

    private func colorFor(_ state: DeviationState) -> Color {
        switch state {
        case .within: return .gray
        case .overweight: return .green
        case .underweight: return .red
        }
    }

    private func symbolFor(_ state: DeviationState) -> String {
        switch state {
        case .within: return "•"
        case .overweight: return "▲"
        case .underweight: return "▼"
        }
    }

    private func accessibilityLabel(for state: DeviationState, delta: Double) -> String {
        switch state {
        case .within:
            return "Within tolerance by \(abs(delta).formatted()) percent versus \(baseline)"
        case .overweight:
            return "Overweight by \(delta.formatted()) percent versus \(baseline)"
        case .underweight:
            return "Underweight by \((-delta).formatted()) percent versus \(baseline)"
        }
    }
}
