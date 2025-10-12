import SwiftUI
import UniformTypeIdentifiers

struct BankStatementCard: View {
    let bankName: String
    let expectedFilename: String
    let fileName: String?
    let filePath: String?
    let instructionsAvailable: Bool
    let onOpenInstructions: () -> Void
    let onSelectFile: () -> Void
    let onDropFiles: ([URL]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(bankName) Statement")
                .font(.system(size: 16, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            if let fileName {
                Text(fileName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(filePath ?? fileName)
            }

            Text("Expected filename: “\(expectedFilename)”")
                .font(.system(size: 13))

            Button {
                onOpenInstructions()
            } label: {
                Label("Instructions", systemImage: "info.circle")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!instructionsAvailable)
            .opacity(instructionsAvailable ? 1 : 0.5)
            .help(instructionsAvailable ? "" : "Instructions coming soon")
            .accessibilityLabel("Open instructions for \(bankName)")

            FileDropZone { urls in
                onDropFiles(urls)
            }
            .frame(height: 120)

            Button("Select File") {
                onSelectFile()
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(height: 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct FileDropZone: View {
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
        .accessibilityLabel("Drop file here to import")
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
