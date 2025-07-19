import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DataImportExportView: View {
    enum StatementType { case creditSuisse, zkb }

    private let dropZoneSize: CGFloat = 100

    @State private var logMessages: [String] = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.statementImportLog) ?? []
    @State private var statusMessage: String = "Status: \u{2B24} Idle \u{2022} No file loaded"
    @State private var showImporterFor: StatementType?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                importPanel
                statusPanel
                logPanel
            }
            .frame(minWidth: 800, minHeight: 800)
            .padding(.top, 32)
            .padding(.horizontal)
        }
        .fileImporter(
            isPresented: Binding(
                get: { showImporterFor != nil },
                set: { _ in }
            ),
            allowedContentTypes: [
                .commaSeparatedText,
                UTType(filenameExtension: "xlsx") ?? .data,
                .pdf
            ],
            allowsMultipleSelection: false
        ) { result in
            guard let type = showImporterFor else { return }
            showImporterFor = nil
            if case let .success(urls) = result, let url = urls.first {
                importStatement(from: url, type: type)
            }
        }
        .navigationTitle("Data Import / Export")
    }

    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            cardsSection
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
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

    private var cardsSection: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 600
            Group {
                if compact {
                    VStack(spacing: 16) {
                        creditSuisseCard
                        zkbCard
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        creditSuisseCard
                        zkbCard
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var creditSuisseCard: some View {
        importCard(title: "Import Credit-Suisse Statement", type: .creditSuisse, enabled: true)
    }

    private var zkbCard: some View {
        importCard(title: "Import ZKB Statement", type: .zkb, enabled: true)
    }

    private func importCard(title: String, type: StatementType, enabled: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundColor(enabled ? .primary : .gray)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(enabled ? .primary : .gray)
            DropZone { urls in
                guard enabled, let url = urls.first else { return }
                importStatement(from: url, type: type)
            }
            .frame(width: dropZoneSize, height: dropZoneSize)
            .frame(maxWidth: .infinity)
            .opacity(enabled ? 1 : 0.5)

            Text("or")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 170/255, green: 170/255, blue: 170/255))

            Button("Select File") {
                guard enabled else { return }
                showImporterFor = type
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(height: 32)
            .disabled(!enabled)
            .help(enabled ? "" : "coming soon")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3))
        )
    }

    private func importStatement(from url: URL, type: StatementType) {
        func startImport(deleteExisting: Bool) {
            statusMessage = "Status: Importing \(url.lastPathComponent) …"
            let importType: ImportManager.StatementType = {
                switch type { case .creditSuisse: return .creditSuisse; case .zkb: return .zkb }
            }()
            ImportManager.shared.importPositions(at: url, type: importType, deleteExisting: deleteExisting, progress: { message in
                DispatchQueue.main.async { self.appendLog(message) }
            }) { result in
                DispatchQueue.main.async {
                    let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                    switch result {
                    case .success(let summary):
                        let errors = summary.totalRows - summary.parsedRows
                        self.statusMessage = "Status: \u{2705} \(typeName(type)) import succeeded: \(summary.parsedRows) records parsed, \(errors) errors"
                        self.appendLog("[\(stamp)] \(url.lastPathComponent) → Success: \(summary.parsedRows) records, \(errors) errors")
                    case .failure(let error):
                        self.statusMessage = "Status: \u{274C} \(typeName(type)) import failed: \(error.localizedDescription)"
                        self.appendLog("[\(stamp)] \(url.lastPathComponent) → Failed: \(error.localizedDescription)")
                    }
                }
            }
        }

        if type == .zkb {
            guard let inst = promptInstitutionSelection(defaultName: "Zürcher Kantonalbank ZKB") else {
                statusMessage = "Status: Upload cancelled"
                return
            }
            let removed = ImportManager.shared.deletePositions(institutionId: inst.id)
            appendLog("Existing \(inst.name) positions removed: \(removed)")
            startImport(deleteExisting: false)
        } else {
            startImport(deleteExisting: false)
        }
    }

    private func promptInstitutionSelection(defaultName: String) -> DatabaseManager.InstitutionData? {
        let institutions = ImportManager.shared.fetchInstitutions()
        guard !institutions.isEmpty else { return nil }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        popup.addItems(withTitles: institutions.map { $0.name })
        if let idx = institutions.firstIndex(where: { $0.name == defaultName }) {
            popup.selectItem(at: idx)
        }

        let alert = NSAlert()
        alert.messageText = "Delete existing positions?"
        alert.informativeText = "Select the institution whose positions should be removed before import."
        alert.accessoryView = popup
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let selected = popup.indexOfSelectedItem
        return institutions[selected]
    }

    private func appendLog(_ entry: String) {
        logMessages.insert(entry, at: 0)
        if logMessages.count > 100 { logMessages.removeLast(logMessages.count - 100) }
        UserDefaults.standard.set(logMessages, forKey: UserDefaultsKeys.statementImportLog)
    }

    private var statusPanel: some View {
        Text(statusMessage)
            .font(.system(size: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statement Loading Log")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 51/255, green: 51/255, blue: 51/255))
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logMessages.enumerated()), id: \.offset) { _, entry in
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
        )
        .overlay(
            Rectangle()
                .fill(Theme.primaryAccent)
                .frame(height: 2), alignment: .top
        )
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    private func typeName(_ type: StatementType) -> String {
        switch type {
        case .creditSuisse: return "Credit-Suisse"
        case .zkb: return "ZKB"
        }
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
