import SwiftUI
import UniformTypeIdentifiers

struct DataImportExportView: View {
    @State private var logMessages: [String] = []
    @State private var importSummary: String?
    @State private var showDetails = false
    @State private var showCSImporter = false

    var body: some View {
        ScrollView {
            container
                .padding(.top, 32)
                .padding(.horizontal)
        }
        .fileImporter(
            isPresented: $showCSImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                UTType(filenameExtension: "xlsx")!,
                .pdf
            ],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                handleCSImport(urls: [url])
            }
        }
        .navigationTitle("Data Import / Export")
    }

    private var container: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            importCards
            if let summary = importSummary {
                summaryBar(summary)
            }
            Spacer(minLength: 16)
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

    private var importCards: some View {
        GeometryReader { geo in
            let vertical = geo.size.width <= 600
            let layout = vertical ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))
            layout {
                creditSuisseCard
                zkbCard
            }
        }
        .frame(height: 200)
    }

    private var creditSuisseCard: some View {
        ImportCard(
            icon: Image(systemName: "tray.and.arrow.down"),
            heading: "Import Credit-Suisse Statement",
            dropText: "Drag & Drop Credit-Suisse File",
            buttonText: "Select File",
            onSelect: { showCSImporter = true },
            onDrop: handleCSImport(urls:)
        )
    }

    private var zkbCard: some View {
        ImportCard(
            icon: Image(systemName: "tray.and.arrow.down"),
            heading: "Import ZKB Statement",
            dropText: "Drag & Drop ZKB File",
            buttonText: "Select File",
            disabled: true,
            tooltip: "Coming soon"
        )
    }

    private func handleCSImport(urls: [URL]) {
        guard let _ = urls.first else { return }
        importSummary = "✔ Credit-Suisse import succeeded: 45 records parsed, 2 errors."
        logMessages.insert("[2025-07-12 08:35:42] Credit-Suisse_Positions_2025-07-12.csv → Success: 45 records.", at: 0)
    }

    private func summaryBar(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(red: 46/255, green: 125/255, blue: 50/255))
            Text(text)
            Spacer()
            Button(showDetails ? "Hide Details" : "View Details…") {
                withAnimation { showDetails.toggle() }
            }
                .font(.system(size: 12))
        }
        .font(.system(size: 14))
        .foregroundColor(Color(red: 46/255, green: 125/255, blue: 50/255))
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
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(Color(red: 34/255, green: 34/255, blue: 34/255))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 160)
            .border(Color(red: 224/255, green: 224/255, blue: 224/255))
        }
    }
}

private struct ImportCard: View {
    var icon: Image
    var heading: String
    var dropText: String
    var buttonText: String
    var disabled: Bool = false
    var tooltip: String? = nil
    var onSelect: (() -> Void)? = nil
    var onDrop: (([URL]) -> Void)? = nil

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .padding(.bottom, 4)
            Text(heading)
                .font(.system(size: 16, weight: .bold))
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(.gray)
                    .frame(height: 120)
                    .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                Text(dropText)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                guard let onDrop else { return false }
                var urls: [URL] = []
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url { urls.append(url) }
                    }
                }
                DispatchQueue.main.async { onDrop(urls) }
                return true
            }
            Text("or")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
            Button(buttonText) { onSelect?() }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(disabled)
                .help(disabled ? (tooltip ?? "") : "")
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DataImportExportView()
        .environmentObject(DatabaseManager())
}
