import SwiftUI
import UniformTypeIdentifiers

struct DataImportExportView: View {
    enum StatementType { case creditSuisse, zkb }

    @State private var logMessages: [String] = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.statementImportLog) ?? []
    @State private var summaryMessage: String?
    @State private var showImporterFor: StatementType?

    var body: some View {
        ScrollView {
            container
                .padding(.top, 32)
                .padding(.horizontal)
        }
        .fileImporter(
            isPresented: Binding<Bool>(
                get: { showImporterFor != nil },
                set: { if !$0 { showImporterFor = nil } }
            ),
            allowedContentTypes: [
                .commaSeparatedText,
                UTType(filenameExtension: "xlsx")!,
                .pdf
            ],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result,
               let url = urls.first,
               let type = showImporterFor {
                importStatement(from: url, type: type)
            }
        }
        .navigationTitle("Data Import / Export")
    }

    private var container: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            cardsSection
            if let message = summaryMessage {
                summaryBar(message)
            }
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
        importCard(title: "Import ZKB Statement", type: .zkb, enabled: false)
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
            .frame(height: 120)
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
        summaryMessage = nil

        ImportManager.shared.importPositions(at: url, progress: { message in
            DispatchQueue.main.async { self.appendLog(message) }
        }) { result in
            DispatchQueue.main.async {
                let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                switch result {
                case .success(let summary):
                    let errors = summary.totalRows - summary.parsedRows
                    self.summaryMessage = "\u{2714} \(typeName(type)) import succeeded: \(summary.parsedRows) records parsed, \(errors) errors."
                    self.appendLog("[\(stamp)] \(url.lastPathComponent) → Success: \(summary.parsedRows) records, \(errors) errors")
                case .failure(let error):
                    self.summaryMessage = "\u{274C} \(typeName(type)) import failed: \(error.localizedDescription)"
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

    private func summaryBar(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(red: 46/255, green: 125/255, blue: 50/255))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 46/255, green: 125/255, blue: 50/255))
            Spacer()
            Button("View Details…") {}
                .font(.system(size: 12))
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
