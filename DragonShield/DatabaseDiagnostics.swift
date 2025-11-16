import Foundation
import SQLite

class DatabaseDiagnostics {
    // Reference to your existing database connection
    private let db: Connection

    init(connection: Connection) {
        db = connection
    }

    // Get a list of all tables in the database
    func listAllTables() -> [String] {
        do {
            let query = "SELECT name FROM sqlite_master WHERE type='table'"
            let rows = try db.prepare(query)

            var tables: [String] = []
            for row in rows {
                if let tableName = row[0] as? String {
                    tables.append(tableName)
                }
            }

            print("📊 Found \(tables.count) tables: \(tables.joined(separator: ", "))")
            return tables
        } catch {
            print("❌ Error listing tables: \(error)")
            return []
        }
    }

    // Get the schema for a specific table
    func describeTable(_ tableName: String) {
        do {
            let query = "PRAGMA table_info(\(tableName))"
            let rows = try db.prepare(query)

            print("📋 Schema for table '\(tableName)':")
            for row in rows {
                let columnId = row[0] as? Int64 ?? 0
                let columnName = row[1] as? String ?? "unknown"
                let columnType = row[2] as? String ?? "unknown"
                let notNull = row[3] as? Int64 ?? 0
                let defaultValue = row[4]
                let isPK = row[5] as? Int64 ?? 0

                print("  - Column \(columnId): \(columnName) (\(columnType)) | NotNull: \(notNull != 0) | PK: \(isPK != 0) | Default: \(defaultValue ?? "nil")")
            }
        } catch {
            print("❌ Error describing table '\(tableName)': \(error)")
        }
    }

    // Examine data in the reasons table if it exists
    func examineReasonsTable() {
        do {
            let query = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%reason%'"
            let rows = try db.prepare(query)

            var reasonTables: [String] = []
            for row in rows {
                if let tableName = row[0] as? String {
                    reasonTables.append(tableName)
                }
            }

            print("🔍 Found \(reasonTables.count) tables related to 'reasons': \(reasonTables.joined(separator: ", "))")

            for tableName in reasonTables {
                describeTable(tableName)

                // Get a sample of data
                do {
                    let dataQuery = "SELECT * FROM \(tableName) LIMIT 5"
                    let dataRows = try db.prepare(dataQuery)

                    print("📝 Sample data from '\(tableName)':")
                    var rowCount = 0
                    for dataRow in dataRows {
                        print("  Row \(rowCount): \(dataRow)")
                        rowCount += 1
                    }

                    if rowCount == 0 {
                        print("  (No data found)")
                    }
                } catch {
                    print("❌ Error fetching sample data from '\(tableName)': \(error)")
                }
            }
        } catch {
            print("❌ Error searching for reasons tables: \(error)")
        }
    }

    // Find all Swift files that might be related to "reasons"
    func findRelatedSwiftFiles() {
        print("🔎 Looking for Swift files related to 'reasons'...")
        let fileManager = FileManager.default
        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        func searchDirectory(_ directoryURL: URL) {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)

                for fileURL in fileURLs {
                    if fileURL.hasDirectoryPath {
                        // Skip certain directories
                        let folderName = fileURL.lastPathComponent
                        if !["build", ".git", "Pods", ".build", "DerivedData"].contains(folderName) {
                            searchDirectory(fileURL)
                        }
                    } else if fileURL.pathExtension == "swift" {
                        // Check if the file contains "reason" text
                        do {
                            let contents = try String(contentsOf: fileURL, encoding: .utf8)
                            if contents.range(of: "reason", options: .caseInsensitive) != nil {
                                print("  📄 Found file: \(fileURL.path)")

                                // Extract relevant code snippets
                                let lines = contents.components(separatedBy: .newlines)
                                for (index, line) in lines.enumerated() {
                                    if line.range(of: "reason", options: .caseInsensitive) != nil {
                                        let startLine = max(0, index - 2)
                                        let endLine = min(lines.count - 1, index + 2)

                                        print("    Context (lines \(startLine + 1)-\(endLine + 1)):")
                                        for i in startLine ... endLine {
                                            print("      \(i + 1): \(lines[i])")
                                        }
                                        print("")
                                    }
                                }
                            }
                        } catch {
                            print("❌ Error reading file \(fileURL.path): \(error)")
                        }
                    }
                }
            } catch {
                print("❌ Error accessing directory \(directoryURL.path): \(error)")
            }
        }

        searchDirectory(currentDirectoryURL)
    }

    // Run all diagnostics
    func runAllDiagnostics() {
        print("\n=== 🔍 STARTING DATABASE DIAGNOSTICS ===\n")

        let tables = listAllTables()

        print("\n--- Table Schemas ---")
        for table in tables {
            describeTable(table)
            print("")
        }

        print("\n--- Reasons Tables Analysis ---")
        examineReasonsTable()

        print("\n--- Swift Files Analysis ---")
        findRelatedSwiftFiles()

        print("\n=== 🏁 DIAGNOSTICS COMPLETE ===\n")
    }
}
