import Foundation
import AppKit

/// Manages document imports by invoking the bundled Python parser.
class ImportManager {
    static let shared = ImportManager()

    /// Parses a document using the Python parser script.
    /// - Parameters:
    ///   - url: URL of the document to parse.
    ///   - completion: Called with the raw JSON string output or an error.
    func parseDocument(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let scriptPath = Bundle.main.path(forResource: "zkb_parser", ofType: "py", inDirectory: "python_scripts") else {
            completion(.failure(NSError(domain: "ImportManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Parser script not found in bundle"])))
            return
        }

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

        process.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                completion(.success(output))
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
                    }
                }
            }
        }
    }
}
