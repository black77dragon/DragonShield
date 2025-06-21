// DragonShield/ImportManager.swift
// MARK: - Version 1.9
// MARK: - History
// - 1.0 -> 1.1: Added fallback search for parser and error alert handling.
// - 1.1 -> 1.2: Search bundle resource path before falling back to CWD.
// - 1.2 -> 1.3: Improved parser lookup with debug logging and exit code checks.
// - 1.3 -> 1.4: Return checked paths so UI can show detailed error messages.
// - 1.4 -> 1.5: Added environment variable and Application Support search paths.
// - 1.5 -> 1.6: Search PATH directories and parent folders for parser.
// - 1.6 -> 1.7: Simplify lookup to module directory and run parser via -m.
// - 1.7 -> 1.8: Add fallback search using the project source path.
// - 1.8 -> 1.9: Invoke parser via /usr/bin/env to avoid sandbox python issues.

import Foundation
import AppKit

/// Manages document imports by invoking the bundled Python parser.
class ImportManager {
    static let shared = ImportManager()

    /// Attempts to locate the directory containing the Python parser module.
    /// Returns that directory path and the list of checked locations.
    private func findParserModuleDir() -> (path: String?, checked: [String]) {
        var checked: [String] = []
        let fm = FileManager.default

        var candidates: [String] = []
        func add(_ p: String?) { if let p = p, !candidates.contains(p) { candidates.append(p) } }

        add(ProcessInfo.processInfo.environment["ZKB_PARSER_DIR"])
        add(Bundle.main.url(forResource: "zkb_parser", withExtension: "py", subdirectory: "python_scripts")?.deletingLastPathComponent().path)
        add(Bundle.main.resourceURL?.appendingPathComponent("python_scripts").path)
        add(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/python_scripts").path)
        add(Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("python_scripts").path)

        // Search relative to the project source directory where this file resides
        let sourceFileURL = URL(fileURLWithPath: #file)
        var srcParent = sourceFileURL.deletingLastPathComponent()
        add(srcParent.appendingPathComponent("python_scripts").path)
        for _ in 0..<4 {
            srcParent.deleteLastPathComponent()
            add(srcParent.appendingPathComponent("python_scripts").path)
            add(srcParent.appendingPathComponent("DragonShield/python_scripts").path)
        }

        var parentURL = Bundle.main.bundleURL
        for _ in 0..<3 {
            parentURL.deleteLastPathComponent()
            add(parentURL.appendingPathComponent("python_scripts").path)
            add(parentURL.appendingPathComponent("DragonShield/python_scripts").path)
        }

        let cwd = fm.currentDirectoryPath
        add(cwd + "/python_scripts")
        add(cwd + "/DragonShield/python_scripts")

        for dir in candidates {
            checked.append(dir)
            if fm.fileExists(atPath: dir + "/zkb_parser.py") { return (dir, checked) }
        }

        print("❌ Parser module not found. Directories checked:\n - " + checked.joined(separator: "\n - "))
        return (nil, checked)
    }

    /// Parses a document using the Python parser script.
    /// - Parameters:
    ///   - url: URL of the document to parse.
    ///   - completion: Called with the raw JSON string output or an error.
    func parseDocument(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let result = findParserModuleDir()
        guard let moduleDir = result.path else {
            let pathsString = result.checked.map { "- " + $0 }.joined(separator: "\n")
            let message = "Parser module not found. Directories checked:\n" + pathsString
            completion(.failure(NSError(domain: "ImportManager", code: 1, userInfo: [NSLocalizedDescriptionKey: message])))
            return
        }

        print("Using parser directory: \(moduleDir)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-m", "zkb_parser", url.path]
        process.environment = ["PYTHONPATH": moduleDir]

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
