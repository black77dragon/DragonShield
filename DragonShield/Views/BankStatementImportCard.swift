import SwiftUI
import UniformTypeIdentifiers

struct BankStatementImportCard: View {
    let bankName: String
    let expectedFilename: String
    let instructionsEnabled: Bool
    let instructionsAction: () -> Void
    let instructionsTooltip: String
    @Binding var selectedFile: URL?
    let onDrop: ([URL]) -> Void
    let selectFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(bankName) Statement")
                    .font(.system(size: 16, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let file = selectedFile {
                    Text(file.lastPathComponent)
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(file.path)
                }
            }

            Text("Expected filename:\n\"\(expectedFilename)\"")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button(action: instructionsAction) {
                Label("Instructions", systemImage: "info.circle")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!instructionsEnabled)
            .help(instructionsEnabled ? "" : instructionsTooltip)
            .accessibilityLabel("Open instructions for \(bankName)")

            DropZone(onDrop: onDrop)
                .frame(height: 100)
                .accessibilityLabel("Drop file here to import")

            Button("Select File", action: selectFile)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(20)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
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
                Text("Drag & Drop")
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
