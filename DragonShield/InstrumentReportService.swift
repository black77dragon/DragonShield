// DragonShield/InstrumentReportService.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Execute Python script to generate a full Instruments XLSX report.

import Foundation

final class InstrumentReportService {
    func generateReport(outputPath: String) throws {
        let scriptPath = try locateScript()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath, outputPath]
        process.environment = PythonEnvironment.enrichedEnvironment(anchorFile: #file)
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

    private func locateScript() throws -> String {
        var checked: [String] = []
        let fm = FileManager.default

        if let url = Bundle.main.url(forResource: "generate_instrument_report", withExtension: "py", subdirectory: "python_scripts"), fm.fileExists(atPath: url.path) {
            return url.path
        }

        let moduleDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let candidates = [
            moduleDir.appendingPathComponent("python_scripts/generate_instrument_report.py").path,
            moduleDir.appendingPathComponent("../python_scripts/generate_instrument_report.py").path,
            moduleDir.appendingPathComponent("../../python_scripts/generate_instrument_report.py").path,
        ]

        for path in candidates {
            checked.append(path)
            if fm.fileExists(atPath: path) { return path }
        }

        throw NSError(
            domain: "InstrumentReportService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Script not found. Checked: \(checked)"]
        )
    }
}
