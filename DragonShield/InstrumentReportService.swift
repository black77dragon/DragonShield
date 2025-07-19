// DragonShield/InstrumentReportService.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Execute Python script to generate a full Instruments XLSX report.

import Foundation

final class InstrumentReportService {
    func generateReport(outputPath: String) throws {
        guard let scriptURL = Bundle.main.url(forResource: "generate_instrument_report", withExtension: "py", subdirectory: "python_scripts") else {
            throw NSError(domain: "InstrumentReportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Script not found"])
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptURL.path, outputPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "InstrumentReportService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
