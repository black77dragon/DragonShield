// DragonShield/Views/RiskScorecardView.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Risk-adjusted performance dashboard with interactive tiles.

import SwiftUI
import Charts

struct RiskScorecardView: View {
    @State private var metrics: RiskMetrics? = nil
    @State private var period: String = "1Y"
    private let service = RiskMetricsService()

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Period", selection: $period) {
                Text("3M").tag("3M")
                Text("6M").tag("6M")
                Text("1Y").tag("1Y")
                Text("3Y").tag("3Y")
                Text("5Y").tag("5Y")
            }
            .pickerStyle(.segmented)
            .onChange(of: period) { _ in loadMetrics() }
            .padding()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                MetricTile(title: "Sharpe Ratio", value: metrics?.sharpe ?? 0)
                MetricTile(title: "Sortino Ratio", value: metrics?.sortino ?? 0)
                MetricTile(title: "Max Drawdown", value: metrics?.max_drawdown ?? 0)
                MetricTile(title: "VaR 95%", value: metrics?.varValue ?? 0)
            }
        }
        .onAppear(perform: loadMetrics)
        .padding()
    }

    private func loadMetrics() {
        if let csv = Bundle.main.path(forResource: "sample_returns", ofType: "csv", inDirectory: "test_data") {
            metrics = try? service.fetchMetrics(csvPath: csv, period: period)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: Double
    @State private var hovering = false
    @State private var showDetail = false

    var body: some View {
        VStack {
            Gauge(value: value, in: -1...2) {
                Text(title)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .frame(height: 100)
            Chart {
                LineMark(x: .value("Day", 0), y: .value("Value", value))
            }
            .frame(height: 40)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { showDetail = true }
        .popover(isPresented: $hovering) {
            Text(String(format: "%.4f", value)).padding()
        }
        .sheet(isPresented: $showDetail) {
            Text("Detailed risk analysis coming soon")
                .padding()
        }
    }
}

#Preview {
    RiskScorecardView()
}
