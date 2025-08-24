import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DataImportExportView: View {
    enum StatementType { case creditSuisse, zkb }


    @State private var logMessages: [String] = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.statementImportLog) ?? []
    @State private var statusMessage: String = "Status: \u{2B24} Idle \u{2022} No file loaded"
    @State private var showImporterFor: StatementType?
    @State private var creditSuisseFile: URL?
    @State private var zkbFile: URL?
    @State private var creditSuisseNote: String?
    @State private var zkbNote: String?
    @State private var showCSInstructions = false

    var body: some View {
        TabView {
            importTab
                .tabItem { Text("Import") }
            ImportSessionHistoryView()
                .tabItem { Text("History") }
        }
        .navigationTitle("Data Import / Export")
        .sheet(isPresented: $showCSInstructions) {
            CreditSuisseInstructionsView()
        }
    }

    private var importTab: some View {
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
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            guard let type = showImporterFor else { return }
            showImporterFor = nil
            if case let .success(urls) = result, let url = urls.first {
                handleImport([url], for: type)
            }
        }
    }

    private var allowedTypes: [UTType] {
        switch showImporterFor {
        case .creditSuisse:
            return [UTType(filenameExtension: "xlsx") ?? .data]
        case .zkb:
            return [.commaSeparatedText]
        case .none:
            return []
        }
    }

    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Text("This process is adding and not replacing positions. Delete positions in the Positions Menu if required")
                .font(.system(size: 14))
                .foregroundColor(.red)
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
        BankImportCard(
            bankName: "Credit-Suisse",
            expectedFilename: "Position List MM DD YYYY.xlsx",
            selectedFileURL: creditSuisseFile,
            note: creditSuisseNote,
            instructionsEnabled: true,
            instructionsTooltip: "",
            openInstructions: { showCSInstructions = true },
            dropAction: { urls in handleImport(urls, for: .creditSuisse) },
            selectFileAction: { showImporterFor = .creditSuisse }
        )
    }

    private var zkbCard: some View {
        BankImportCard(
            bankName: "ZKB",
            expectedFilename: "Depotauszug MMM DD YYYY.csv",
            selectedFileURL: zkbFile,
            note: zkbNote,
            instructionsEnabled: false,
            instructionsTooltip: "Instructions coming soon",
            openInstructions: {},
            dropAction: { urls in handleImport(urls, for: .zkb) },
            selectFileAction: { showImporterFor = .zkb }
        )
    }

    private func handleImport(_ urls: [URL], for type: StatementType) {
        let exts: [String]
        switch type {
        case .creditSuisse: exts = ["xlsx"]
        case .zkb: exts = ["csv"]
        }
        guard let url = urls.first(where: { exts.contains($0.pathExtension.lowercased()) }) else {
            statusMessage = "Status: \u{26A0}\u{FE0F} Unexpected file type"
            return
        }
        if urls.count > 1 {
            setNote("Imported first compatible file.", for: type)
        } else {
            setNote(nil, for: type)
        }
        setSelectedFile(url, for: type)
        importStatement(from: url, type: type)
    }

    private func setSelectedFile(_ url: URL, for type: StatementType) {
        switch type {
        case .creditSuisse: creditSuisseFile = url
        case .zkb: zkbFile = url
        }
    }

    private func setNote(_ note: String?, for type: StatementType) {
        switch type {
        case .creditSuisse: creditSuisseNote = note
        case .zkb: zkbNote = note
        }
    }

    private func importStatement(from url: URL, type: StatementType) {
        func startImport() {
            statusMessage = "Status: Importing \(url.lastPathComponent) …"
            let importType: ImportManager.StatementType = {
                switch type { case .creditSuisse: return .creditSuisse; case .zkb: return .zkb }
            }()
            ImportManager.shared.importPositions(at: url, type: importType, progress: { message in
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

        startImport()
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
