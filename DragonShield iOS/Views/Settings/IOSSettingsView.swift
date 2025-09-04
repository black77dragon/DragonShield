// iOS Settings: Import snapshot (.sqlite) and open read-only
#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IOSSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var showImporter = false
    @State private var importError: String?
    @State private var lastImportedPath: String = ""

    var body: some View {
        Form {
            Section(header: Text("Data Import")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import SQLite snapshot exported from the Mac app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Import Snapshot…") { showImporter = true }
                    if !lastImportedPath.isEmpty {
                        Text("Using: \(lastImportedPath)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Section(header: Text("About")) {
                Text("DB Version: \(dbManager.dbVersion)")
                if let created = dbManager.dbCreated { Text("Created: \(created.description)") }
                if let modified = dbManager.dbModified { Text("Modified: \(modified.description)") }
            }
        }
        .navigationTitle("Settings")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "sqlite") ?? .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importSnapshot(from: url)
                }
            case .failure(let err):
                importError = err.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "")
        }
    }

    private func importSnapshot(from url: URL) {
        do {
            // Copy into app container (Documents)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dest = docs.appendingPathComponent("DragonShield_snapshot.sqlite", conformingTo: UTType(filenameExtension: "sqlite") ?? .data)
            if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
            try FileManager.default.copyItem(at: url, to: dest)
            if dbManager.openReadOnly(at: dest.path) {
                lastImportedPath = dest.lastPathComponent
            } else {
                importError = "Failed to open snapshot."
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
#endif

