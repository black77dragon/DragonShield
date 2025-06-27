// DragonShield/ImportManager.swift

// MARK: - Version 2.0.2.1
// MARK: - History
// - 1.11 -> 2.0.0.0: Rewritten to use native Swift XLSX processing instead of Python parser.
// - 2.0.0.0 -> 2.0.0.1: Replace deprecated allowedFileTypes API.
// - 2.0.0.1 -> 2.0.0.2: Begin security-scoped access when reading selected file.

// - 2.0.0.2 -> 2.0.0.3: Surface detailed file format errors from XLSXProcessor.
// - 2.0.0.3 -> 2.0.1.0: Expect XLSX files and use XLSXProcessor.
// - 2.0.1.0 -> 2.0.2.0: Integrate ZKBXLSXProcessor for ZKB statements.
// - 2.0.2.0 -> 2.0.2.1: Provide progress logging via callback.

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Manages document imports using the native XLSX processing pipeline.
class ImportManager {
    static let shared = ImportManager()
    private let xlsxProcessor = ZKBXLSXProcessor()

    private var repository: BankRecordRepository? {
        guard let db = DatabaseManager().db else { return nil }
        return BankRecordRepository(db: db)
    }

    /// Parses a XLSX document and saves the records to the database.
    func parseDocument(at url: URL, progress: ((String) -> Void)? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            do {
                let records = try self.xlsxProcessor.process(url: url, progress: progress)

                if let repo = self.repository {
                    try repo.saveRecords(records)
                }
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(records)
                let json = String(data: data, encoding: .utf8) ?? "[]"
                DispatchQueue.main.async {
                    completion(.success(json))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }


    /// Presents an open panel and processes the selected XLSX file.
    func openAndParseDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!]
        } else {
            panel.allowedFileTypes = ["xlsx"]
        }

        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.parseDocument(at: url, progress: { message in
                    print("\u{1F4C4} \(message)")
                }) { result in
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
