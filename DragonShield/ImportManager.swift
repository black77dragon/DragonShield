// DragonShield/ImportManager.swift
// MARK: - Version 1.4
// MARK: - History
// - 1.0 -> 1.1: Added fallback search for parser and error alert handling.
// - 1.1 -> 1.2: Search bundle resource path before falling back to CWD.
// - 1.2 -> 1.3: Improved parser lookup with debug logging and exit code checks.
// - 1.3 -> 1.4: Return checked paths so UI can show detailed error messages.

import Foundation
import AppKit

/// Manages document imports by invoking the bundled Python parser.
class ImportManager {
    static let shared = ImportManager()

    /// Attempts to locate the Python parser script in the app bundle or working
    /// directory. Returns the path and list of checked paths so errors can
    /// present these details.
    private func findParserScript() -> (path: String?, checked: [String]) {
        var checkedPaths: [String] = []
        let fm = FileManager.default

        let bundleCandidates: [String?] = [
            Bundle.main.url(forResource: "zkb_parser", withExtension: "py", subdirectory: "python_scripts")?.path,
            Bundle.main.resourceURL?.appendingPathComponent("python_scripts/zkb_parser.py").path,
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("python_scripts/zkb_parser.py").path
        ]

        for path in bundleCandidates {
            if let p = path {
                checkedPaths.append(p)
                if fm.fileExists(atPath: p) { return (p, checkedPaths) }
            }
        }

        let cwd = fm.currentDirectoryPath
        let devCandidates = ["python_scripts/zkb_parser.py", "DragonShield/python_scripts/zkb_parser.py"]
            .map { cwd + "/" + $0 }
        for path in devCandidates {
            checkedPaths.append(path)
            if fm.fileExists(atPath: path) { return (path, checkedPaths) }
        }

        print("❌ Parser script not found. Paths checked:\n - " + checkedPaths.joined(separator: "\n - "))
        return (nil, checkedPaths)
    }

    /// Parses a document using the Python parser script.
    /// - Parameters:
    ///   - url: URL of the document to parse.
    ///   - completion: Called with the raw JSON string output or an error.
    func parseDocument(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let result = findParserScript()
        guard let scriptPath = result.path else {
            let pathsString = result.checked.map { "- " + $0 }.joined(separator: "\n")
            let message = "Parser script not found. Paths checked:\n" + pathsString
            completion(.failure(NSError(domain: "ImportManager", code: 1, userInfo: [NSLocalizedDescriptionKey: message])))
            return
        }

        print("Using parser at: \(scriptPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath, url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            completion(.failure(error))
            return
        }

        process.terminationHandler = { proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let exitCode = proc.terminationStatus
            DispatchQueue.main.async {
                if exitCode == 0 {
                    completion(.success(output))
                } else {
                    let err = NSError(
                        domain: "ImportManager",
                        code: Int(exitCode),
                        userInfo: [NSLocalizedDescriptionKey: "Parser exited with code \(exitCode). Output:\n\(output)"]
                    )
                    completion(.failure(err))
                }
            }
        }
    }

    /// Presents an open panel and invokes the parser on the selected file.
    func openAndParseDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["xlsx", "csv", "pdf"]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.parseDocument(at: url) { result in
                    switch result {
                    case .success(let output):
                        print("\n📥 Import result:\n\(output)")
                    case .failure(let error):
                        print("❌ Import failed: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Import Error"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }
}
