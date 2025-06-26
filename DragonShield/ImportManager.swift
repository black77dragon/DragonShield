// DragonShield/ImportManager.swift
// MARK: - Version 2.0.0.3
// MARK: - History
// - 1.11 -> 2.0.0.0: Rewritten to use native Swift CSV processing instead of Python parser.
// - 2.0.0.0 -> 2.0.0.1: Replace deprecated allowedFileTypes API.
// - 2.0.0.1 -> 2.0.0.2: Begin security-scoped access when reading selected file.

// - 2.0.0.2 -> 2.0.0.3: Surface detailed file format errors from CSVProcessor.
import Foundation
import AppKit
import UniformTypeIdentifiers

/// Manages document imports using the native CSV processing pipeline.
class ImportManager {
    static let shared = ImportManager()
    private let csvProcessor = CSVProcessor()
    private var repository: BankRecordRepository? {
        guard let db = DatabaseManager().db else { return nil }
        return BankRecordRepository(db: db)
    }

    /// Parses a CSV document and saves the records to the database.
    func parseDocument(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            do {
                let records = try self.csvProcessor.processCSVFile(url: url)
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

    /// Presents an open panel and processes the selected CSV file.
    func openAndParseDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [UTType.commaSeparatedText]
        } else {
            panel.allowedFileTypes = ["csv"]
        }
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
