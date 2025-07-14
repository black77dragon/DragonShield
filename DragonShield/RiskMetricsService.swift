// DragonShield/RiskMetricsService.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Execute Python script to compute risk metrics for given CSV file.

import Foundation

struct RiskMetrics: Decodable {
    let sharpe: Double
    let sortino: Double
    let max_drawdown: Double
    let varValue: Double
    let concentration: Double

    private enum CodingKeys: String, CodingKey {
        case sharpe
        case sortino
        case max_drawdown
        case varValue = "var"
        case concentration
    }
}

final class RiskMetricsService {
    func fetchMetrics(csvPath: String, period: String = "1Y") throws -> RiskMetrics {
        let scriptURL = Bundle.main.url(forResource: "risk_metrics", withExtension: "py", subdirectory: "python_scripts")
        let python = "/usr/bin/python3"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [scriptURL?.path ?? "", "--csv", csvPath, "--period", period]

        let outPipe = Pipe()
        process.standardOutput = outPipe
        try process.run()
        process.waitUntilExit()

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let decoder = JSONDecoder()
        return try decoder.decode(RiskMetrics.self, from: data)
    }
}
