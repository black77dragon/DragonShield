// DragonShield/Views/ImportStatementView.swift
// MARK: - Version 1.4.0.0
// MARK: - History
// - 1.0 -> 1.1: Corrected use of .foregroundColor to .foregroundStyle for hierarchical styles.
// - 1.1 -> 1.2: Added ZKB upload section and integrated ImportManager parsing.
// - 1.2 -> 1.3: Present alert pop-ups when import errors occur.
// - 1.3 -> 1.4.0.0: Display progress log messages during import.

import SwiftUI
import UniformTypeIdentifiers

struct ImportStatementView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    
    @State private var isTargeted = false // For drag-and-drop highlight
    @State private var selectedFileURL: URL?
    @State private var showingFileImporter = false
    @State private var errorMessage: String?
    @State private var logMessages: [String] = []

    enum ImportMode { case generic, zkb }
    @State private var importMode: ImportMode = .generic
    
    // Supported file types for the importer
    private let allowedFileTypesGeneric: [UTType] = [.commaSeparatedText, .spreadsheet, .pdf]
    private let allowedFileTypesZkb: [UTType] = [.spreadsheet, .commaSeparatedText]

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                modernHeader.padding(.bottom, 30)

                // Main Content
                VStack {
                    if let url = selectedFileURL {
                        fileSelectedView(url: url)
                    } else {
                        VStack(spacing: 40) {
                            VStack {
                                Text("General Upload")
                                    .font(.headline)
                                dropZoneView
                            }
                            Divider()
                            VStack {
                                Text("Upload ZKB Statement")
                                    .font(.headline)
                                zkbDropZoneView
                            }
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: importMode == .zkb ? allowedFileTypesZkb : allowedFileTypesGeneric
        ) { result in
            handleFileImport(result: result)
        }
        .alert("Import Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown Error")
        }
    }
    
    // MARK: - Subviews

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down.on.square.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.cyan)
                    Text("Import Statement")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
                }
                Text("Upload bank or custody account statements (CSV, XLSX, PDF)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding([.horizontal, .top], 24)
    }

    private var dropZoneView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(isTargeted ? Color.accentColor : .gray.opacity(0.4))

            Text("Drag & Drop Your File Here")
                .font(.title2).bold()
                .foregroundStyle(.secondary)

            Text("or")
                .font(.headline)
                .foregroundStyle(.tertiary) // CORRECTED: Use .foregroundStyle

            Button {
                importMode = .generic
                showingFileImporter = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Select File")
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .frame(maxWidth: 500, maxHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                .background(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                    style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            importMode = .generic
            handleDrop(providers: providers)
            return true
        }
    }

    private var zkbDropZoneView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 80))
                .foregroundStyle(isTargeted ? Color.accentColor : .gray.opacity(0.4))

            Text("Drag & Drop ZKB File")
                .font(.title2).bold()
                .foregroundStyle(.secondary)

            Text("or")
                .font(.headline)
                .foregroundStyle(.tertiary)

            Button {
                importMode = .zkb
                showingFileImporter = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Select ZKB File")
                }
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .frame(maxWidth: 500, maxHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                .background(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                    style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            importMode = .zkb
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func fileSelectedView(url: URL) -> some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("File Selected")
                    .font(.title).bold()
                Text(url.lastPathComponent)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    selectedFileURL = nil
                    errorMessage = nil
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                
                Button {
                    // This will trigger the next step in the logic
                    processSelectedFile(url: url)
                } label: {
                    Label("Next: Identify Account", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            if !logMessages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logMessages, id: \.self) { msg in
                        Text(msg)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Logic Handlers
    
    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if url.startAccessingSecurityScopedResource() {
                self.selectedFileURL = url
                self.errorMessage = nil
            } else {
                self.errorMessage = "Could not access the selected file."
            }
        case .failure(let error):
            self.errorMessage = "Error selecting file: \(error.localizedDescription)"
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                DispatchQueue.main.async {
                    if let url = url {
                        // For dropped files, we also need to manage security-scoped access
                        if url.startAccessingSecurityScopedResource() {
                            self.selectedFileURL = url
                            self.errorMessage = nil
                        } else {
                            self.errorMessage = "Could not access the dropped file."
                        }
                    } else if let error = error {
                        self.errorMessage = "Error processing drop: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func processSelectedFile(url: URL) {
        logMessages.removeAll()
        if importMode == .zkb {
            let confirm = NSAlert()
            confirm.messageText = "Delete ZKB Positions?"
            confirm.informativeText = "Do you want to delete all Positions in the ZKB Custody Account and all ZKB Cash Accounts"
            confirm.addButton(withTitle: "OK")
            confirm.addButton(withTitle: "Cancel")
            let response = confirm.runModal()
            if response == .alertFirstButtonReturn {
                let deleted = ImportManager.shared.deleteZKBPositions()
                let info = NSAlert()
                info.messageText = "Positions Deleted"
                info.informativeText = "Number of deleted positions: \(deleted)"
                info.addButton(withTitle: "OK")
                info.runModal()
            }
            ImportManager.shared.importPositions(at: url, progress: { message in
                DispatchQueue.main.async { logMessages.append(message) }
            }) { result in
                url.stopAccessingSecurityScopedResource()
                switch result {
                case .success(let summary):
                    selectedFileURL = nil
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Import Completed"
                        alert.informativeText = "Parsed \(summary.parsedRows) of \(summary.totalRows) rows\nCash Accounts: \(summary.cashAccounts)\nSecurities: \(summary.securityRecords)"
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                case .failure(let error):
                    if let impErr = error as? ImportManager.ImportError, impErr == .aborted {
                        errorMessage = "Import aborted by user"
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            ImportManager.shared.parseDocument(at: url, progress: { message in
                DispatchQueue.main.async { logMessages.append(message) }
            }) { result in
                url.stopAccessingSecurityScopedResource()
                switch result {
                case .success(let output):
                    print("Parser Output:\n\(output)")
                    selectedFileURL = nil
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}


struct ImportStatementView_Previews: PreviewProvider {
    static var previews: some View {
        ImportStatementView()
            .environmentObject(DatabaseManager())
    }
}
