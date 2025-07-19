import Foundation

final class InstrumentReportService {
    private let pythonPath = "/usr/bin/python3"

    func generateReport(to url: URL) throws -> String {
        guard let scriptURL = Bundle.main.url(
            forResource: "generate_instrument_report",
            withExtension: "py",
            subdirectory: "python_scripts"
        ) else {
            throw NSError(
                domain: "InstrumentReportService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Script not found"]
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptURL.path, url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "InstrumentReportService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
