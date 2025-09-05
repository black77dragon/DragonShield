#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct SnapshotGateView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let onContinue: () -> Void
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Database Snapshot")
                    .font(.title2.bold())
                if hasSnapshot {
                    Group {
                        HStack { Text("DB Version"); Spacer(); Text(dbManager.dbVersion).foregroundColor(.secondary) }
                        if let created = dbManager.dbCreated { HStack { Text("Created"); Spacer(); Text(created, formatter: DateFormatter.iso8601DateTime).foregroundColor(.secondary) } }
                        if let modified = dbManager.dbModified { HStack { Text("Modified"); Spacer(); Text(modified, formatter: DateFormatter.iso8601DateTime).foregroundColor(.secondary) } }
                        if !dbManager.dbFilePath.isEmpty { HStack { Text("File"); Spacer(); Text(URL(fileURLWithPath: dbManager.dbFilePath).lastPathComponent).foregroundColor(.secondary) } }
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    HStack {
                        Button("Change Snapshot…") { showImporter = true }
                        Spacer()
                        Button("Continue") { onContinue(); dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text("No snapshot loaded. Import a SQLite snapshot exported from the Mac app to get started.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Import Snapshot…") { showImporter = true }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Welcome")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: allowTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { importSnapshot(from: url) }
            case .failure(let err):
                importError = err.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
    }

    private var hasSnapshot: Bool {
        !dbManager.dbFilePath.isEmpty
    }

    private var allowTypes: [UTType] {
        var arr: [UTType] = []
        if let t = UTType(filenameExtension: "sqlite") { arr.append(t) }
        if let t = UTType(filenameExtension: "sqlite3") { arr.append(t) }
        if let t = UTType(filenameExtension: "db") { arr.append(t) }
        if let t = UTType("public.database") { arr.append(t) }
        arr.append(.data)
        return arr
    }

    private func importSnapshot(from url: URL) {
        do {
            var needsStop = false
            if url.startAccessingSecurityScopedResource() { needsStop = true }
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dest = docs.appendingPathComponent("DragonShield_snapshot.sqlite", conformingTo: UTType(filenameExtension: "sqlite") ?? .data)
            if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
            try FileManager.default.copyItem(at: url, to: dest)
            _ = DatabaseManager.normalizeSnapshot(at: dest.path)
            if dbManager.openReadOnly(at: dest.path) {
                // Auto-continue when successfully imported on first boot
                if !hasSnapshot { onContinue(); dismiss() }
            } else {
                importError = "Failed to open snapshot."
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
#endif

