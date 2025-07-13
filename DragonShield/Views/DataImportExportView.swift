import SwiftUI
import UniformTypeIdentifiers

struct DataImportExportView: View {
    enum StatementType { case creditSuisse }

    @State private var logMessages: [String] = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.statementImportLog) ?? []
    @State private var statusText: String = "Idle \u2022 No file loaded"
    @State private var showImporter = false

    var body: some View {
        ScrollView {
            container
                .padding(.top, 32)
                .padding(.horizontal)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                UTType(filenameExtension: "xlsx")!,
                .pdf
            ],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                handleImport(url: url)
            }
        }
        .navigationTitle("Data Import / Export")
    }

    private var container: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            uploadControls
            statusBar
            statementLog
        }
        .padding(24)
        .background(Color(red: 0.976, green: 0.98, blue: 0.984))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 224/255, green: 224/255, blue: 224/255))
        )
        .cornerRadius(8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Data Import / Export")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.primaryAccent)
            Text("Upload bank or custody statements (CSV, XLSX, PDF)")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 74/255, green: 74/255, blue: 74/255))
        }
    }

    private var uploadControls: some View {
        HStack(spacing: 16) {
            DropZone { urls in
                if let url = urls.first { handleImport(url: url) }
            }
            .frame(height: 120)

            Button("Select File") { showImporter = true }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 140, height: 32)
        }
    }

    private func handleImport(url: URL) {
        statusText = "Importing \(url.lastPathComponent)…"

        ImportManager.shared.importPositions(at: url, progress: { message in
            DispatchQueue.main.async {
                self.appendLog(message)
            }
        }) { result in
            DispatchQueue.main.async {
                let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                switch result {
                case .success(let summary):
                    let errors = summary.totalRows - summary.parsedRows
                    self.statusText = "✔ Import succeeded: \(summary.parsedRows) records parsed, \(errors) errors."
                    self.appendLog("[\(stamp)] \(url.lastPathComponent) → Success: \(summary.parsedRows) records")
                case .failure(let error):
                    self.statusText = "Error: \(error.localizedDescription)"
                    self.appendLog("[\(stamp)] \(url.lastPathComponent) → Failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func appendLog(_ entry: String) {
        logMessages.insert(entry, at: 0)
        if logMessages.count > 100 { logMessages.removeLast(logMessages.count - 100) }
        UserDefaults.standard.set(logMessages, forKey: UserDefaultsKeys.statementImportLog)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text("Status:")
                .font(.system(size: 14, weight: .semibold))
            Text(statusText)
                .font(.system(size: 14))
            Spacer()
        }
    }

    private var statementLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statement Loading Log")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 51/255, green: 51/255, blue: 51/255))
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(logMessages, id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(red: 34/255, green: 34/255, blue: 34/255))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 224/255, green: 224/255, blue: 224/255), lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

#Preview {
    DataImportExportView()
        .environmentObject(DatabaseManager())
}

private struct DropZone: View {
    var onDrop: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.gray)
                .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
            VStack {
                Image(systemName: "tray.and.arrow.down")
                Text("Drag & Drop File")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            var urls: [URL] = []
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { urls.append(url) }
                }
            }
            DispatchQueue.main.async { onDrop(urls) }
            return true
        }
    }
}
